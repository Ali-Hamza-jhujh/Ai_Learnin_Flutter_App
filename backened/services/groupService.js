import prisma from '../prisma.js';
import crypto from 'crypto';
import { calculateLevel } from './xpService.js';

export class GroupService {
    /**
     * Create a new study group
     */
    static async createGroup(userId, data) {
        const inviteCode = crypto.randomBytes(3).toString('hex').toUpperCase();

        const group = await prisma.group.create({
            data: {
                name: data.name,
                description: data.description || '',
                subject: data.subject || '',
                inviteCode,
                createdBy: userId,
                members: [{ user: userId, role: 'admin' }],
                sharedNotes: [],
                sharedMcqs: [],
                messages: [],
            },
        });

        return { ...group, _id: group.id };
    }

    /**
     * Join an existing group using an invite code
     */
    static async joinGroup(userId, inviteCode) {
        const group = await prisma.group.findUnique({
            where: { inviteCode: inviteCode.toUpperCase() },
        });
        if (!group) throw new Error('Invalid invite code');

        const members = Array.isArray(group.members) ? [...group.members] : [];
        const isMember = members.some(m => (m.user?.toString() || m.user?.id || m.userId || m) === userId);
        if (isMember) {
            return { alreadyMember: true, group: { ...group, _id: group.id } };
        }

        members.push({ user: userId, role: 'member' });
        const updated = await prisma.group.update({
            where: { id: group.id },
            data: { members },
        });

        return { alreadyMember: false, group: { ...updated, _id: updated.id } };
    }

    /**
     * Get list of groups the user belongs to
     */
    static async getMyGroups(userId) {
        const allGroups = await prisma.group.findMany({
            orderBy: { createdAt: 'desc' },
        });

        const myGroups = allGroups.filter(g => {
            const members = Array.isArray(g.members) ? g.members : [];
            return members.some(m => (m.user?.toString() || m.user?.id || m.userId || m) === userId);
        });

        const userIds = [
            ...new Set(
                myGroups.flatMap(g =>
                    (Array.isArray(g.members) ? g.members : []).map(m => m.user?.toString() || m.user?.id || m.userId || m)
                ).filter(Boolean)
            )
        ];

        const users = await prisma.user.findMany({
            where: { id: { in: userIds } },
            select: { id: true, name: true, avatar: true, xp: true },
        });
        const userMap = new Map(users.map(u => [u.id, { ...u, _id: u.id, level: calculateLevel(u.xp || 0).level }]));

        return myGroups.map(g => {
            const members = (Array.isArray(g.members) ? g.members : []).map(m => {
                const uid = m.user?.toString() || m.user?.id || m.userId || m;
                return {
                    role: m.role || 'member',
                    user: userMap.get(uid) || { _id: uid, id: uid, name: 'User', avatar: '', xp: 0, level: 1 },
                };
            });
            return {
                ...g,
                _id: g.id,
                members,
            };
        });
    }

    /**
     * Get full details of a specific group
     */
    static async getGroupDetails(userId, groupId) {
        const group = await prisma.group.findUnique({
            where: { id: groupId },
        });

        if (!group) throw new Error('Group not found');

        const members = Array.isArray(group.members) ? group.members : [];
        const isMember = members.some(m => (m.user?.toString() || m.user?.id || m.userId || m) === userId);
        if (!isMember) throw new Error('Access denied: You are not a member of this group');

        const memberUserIds = members.map(m => m.user?.toString() || m.user?.id || m.userId || m).filter(Boolean);
        const messages = Array.isArray(group.messages) ? group.messages : [];
        const messageSenderIds = messages.map(msg => msg.sender?.toString() || msg.sender?.id || msg.sender).filter(Boolean);
        const allUserIds = [...new Set([...memberUserIds, ...messageSenderIds])];

        const sharedNoteIds = Array.isArray(group.sharedNotes) ? group.sharedNotes.map(n => n?.toString() || n?.id || n) : [];
        const sharedMcqIds = Array.isArray(group.sharedMcqs) ? group.sharedMcqs.map(m => m?.toString() || m?.id || m) : [];

        const [users, notes, mcqs] = await Promise.all([
            prisma.user.findMany({
                where: { id: { in: allUserIds } },
                select: { id: true, name: true, avatar: true, xp: true },
            }),
            prisma.note.findMany({
                where: { id: { in: sharedNoteIds } },
                select: { id: true, title: true, mode: true, createdAt: true, userId: true },
            }),
            prisma.mCQ.findMany({
                where: { id: { in: sharedMcqIds } },
                select: { id: true, title: true, mode: true, difficulty: true, createdAt: true, userId: true },
            }),
        ]);

        const userMap = new Map(users.map(u => [u.id, { ...u, _id: u.id, level: calculateLevel(u.xp || 0).level }]));

        const populatedMembers = members.map(m => {
            const uid = m.user?.toString() || m.user?.id || m.userId || m;
            return {
                role: m.role || 'member',
                user: userMap.get(uid) || { _id: uid, id: uid, name: 'User', avatar: '', xp: 0, level: 1 },
            };
        });

        const populatedMessages = messages.map(msg => {
            const sid = msg.sender?.toString() || msg.sender?.id || msg.sender;
            return {
                ...msg,
                _id: msg.id || msg._id,
                sender: userMap.get(sid) || { _id: sid, id: sid, name: 'User', avatar: '' },
            };
        });

        return {
            ...group,
            _id: group.id,
            members: populatedMembers,
            messages: populatedMessages,
            sharedNotes: notes.map(n => ({ ...n, _id: n.id })),
            sharedMcqs: mcqs.map(m => ({ ...m, _id: m.id })),
        };
    }

    /**
     * Post a chat message to the group
     */
    static async postMessage(userId, groupId, text) {
        const group = await prisma.group.findUnique({
            where: { id: groupId },
        });
        if (!group) throw new Error('Group not found');

        const members = Array.isArray(group.members) ? group.members : [];
        const isMember = members.some(m => (m.user?.toString() || m.user?.id || m.userId || m) === userId);
        if (!isMember) throw new Error('Access denied');

        const user = await prisma.user.findUnique({
            where: { id: userId },
            select: { id: true, name: true, avatar: true },
        });

        const messageId = crypto.randomUUID();
        const newMessage = {
            id: messageId,
            _id: messageId,
            sender: userId,
            text,
            createdAt: new Date(),
        };

        const messages = Array.isArray(group.messages) ? [...group.messages] : [];
        messages.push(newMessage);

        await prisma.group.update({
            where: { id: groupId },
            data: { messages },
        });

        return {
            ...newMessage,
            sender: user ? { ...user, _id: user.id } : { _id: userId, id: userId },
        };
    }

    /**
     * Share a note with the group
     */
    static async shareNote(userId, groupId, noteId) {
        const group = await prisma.group.findUnique({ where: { id: groupId } });
        if (!group) throw new Error('Group not found');

        const members = Array.isArray(group.members) ? group.members : [];
        const isMember = members.some(m => (m.user?.toString() || m.user?.id || m.userId || m) === userId);
        if (!isMember) throw new Error('Access denied');

        const sharedNotes = Array.isArray(group.sharedNotes) ? [...group.sharedNotes] : [];
        if (!sharedNotes.includes(noteId)) {
            sharedNotes.push(noteId);
            await prisma.group.update({
                where: { id: groupId },
                data: { sharedNotes },
            });
        }

        return { ...group, _id: group.id, sharedNotes };
    }

    /**
     * Share an MCQ with the group
     */
    static async shareMcq(userId, groupId, mcqId) {
        const group = await prisma.group.findUnique({ where: { id: groupId } });
        if (!group) throw new Error('Group not found');

        const members = Array.isArray(group.members) ? group.members : [];
        const isMember = members.some(m => (m.user?.toString() || m.user?.id || m.userId || m) === userId);
        if (!isMember) throw new Error('Access denied');

        const sharedMcqs = Array.isArray(group.sharedMcqs) ? [...group.sharedMcqs] : [];
        if (!sharedMcqs.includes(mcqId)) {
            sharedMcqs.push(mcqId);
            await prisma.group.update({
                where: { id: groupId },
                data: { sharedMcqs },
            });
        }

        return { ...group, _id: group.id, sharedMcqs };
    }

    /**
     * Remove a note from the group (admin only)
     */
    static async removeNote(userId, groupId, noteId) {
        const group = await prisma.group.findUnique({ where: { id: groupId } });
        if (!group) throw new Error('Group not found');

        const members = Array.isArray(group.members) ? group.members : [];
        const member = members.find(m => (m.user?.toString() || m.user?.id || m.userId || m) === userId);
        if (!member || member.role !== 'admin') {
            throw new Error('Access denied: Only admins can remove content');
        }

        const sharedNotes = (Array.isArray(group.sharedNotes) ? group.sharedNotes : []).filter(id => id?.toString() !== noteId);
        const updated = await prisma.group.update({
            where: { id: groupId },
            data: { sharedNotes },
        });

        return { ...updated, _id: updated.id };
    }

    /**
     * Remove an MCQ from the group (admin only)
     */
    static async removeMcq(userId, groupId, mcqId) {
        const group = await prisma.group.findUnique({ where: { id: groupId } });
        if (!group) throw new Error('Group not found');

        const members = Array.isArray(group.members) ? group.members : [];
        const member = members.find(m => (m.user?.toString() || m.user?.id || m.userId || m) === userId);
        if (!member || member.role !== 'admin') {
            throw new Error('Access denied: Only admins can remove content');
        }

        const sharedMcqs = (Array.isArray(group.sharedMcqs) ? group.sharedMcqs : []).filter(id => id?.toString() !== mcqId);
        const updated = await prisma.group.update({
            where: { id: groupId },
            data: { sharedMcqs },
        });

        return { ...updated, _id: updated.id };
    }

    /**
     * Delete a message from the group
     */
    static async deleteMessage(userId, groupId, messageId) {
        const group = await prisma.group.findUnique({ where: { id: groupId } });
        if (!group) throw new Error('Group not found');

        const members = Array.isArray(group.members) ? group.members : [];
        const member = members.find(m => (m.user?.toString() || m.user?.id || m.userId || m) === userId);
        const isAdmin = member && member.role === 'admin';

        const messages = Array.isArray(group.messages) ? group.messages : [];
        const message = messages.find(m => (m.id === messageId || m._id === messageId));
        if (!message) throw new Error('Message not found');

        const senderId = message.sender?.toString() || message.sender?.id || message.sender;
        if (!isAdmin && senderId !== userId) {
            throw new Error('Access denied: You can only delete your own messages');
        }

        const filteredMessages = messages.filter(m => (m.id !== messageId && m._id !== messageId));
        const updated = await prisma.group.update({
            where: { id: groupId },
            data: { messages: filteredMessages },
        });

        return { ...updated, _id: updated.id };
    }

    /**
     * Remove a user from the group
     */
    static async removeUser(adminUserId, groupId, userIdToRemove) {
        const group = await prisma.group.findUnique({ where: { id: groupId } });
        if (!group) throw new Error('Group not found');

        const members = Array.isArray(group.members) ? [...group.members] : [];
        const adminMember = members.find(m => (m.user?.toString() || m.user?.id || m.userId || m) === adminUserId);
        if (!adminMember || adminMember.role !== 'admin') {
            throw new Error('Access denied: Only admins can remove users');
        }

        const memberIndex = members.findIndex(m => (m.user?.toString() || m.user?.id || m.userId || m) === userIdToRemove);
        if (memberIndex === -1) {
            throw new Error('User not found in group');
        }

        if (members[memberIndex].role === 'admin' && group.createdBy === userIdToRemove) {
            throw new Error('Cannot remove the group creator');
        }

        members.splice(memberIndex, 1);
        const updated = await prisma.group.update({
            where: { id: groupId },
            data: { members },
        });

        return { ...updated, _id: updated.id };
    }

    /**
     * Delete the entire group (creator only)
     */
    static async deleteGroup(userId, groupId) {
        const group = await prisma.group.findUnique({ where: { id: groupId } });
        if (!group) throw new Error('Group not found');

        if (group.createdBy !== userId) {
            throw new Error('Access denied: Only the group creator can delete the group');
        }

        await prisma.group.delete({ where: { id: groupId } });
        return { message: 'Group deleted successfully' };
    }
}
