import express from 'express';
import authMiddleware from '../Authentication/auth.js';
import { GroupService } from '../services/groupService.js';

const router = express.Router();

// Get user's groups
router.get('/', authMiddleware, async (req, res) => {
    try {
        const groups = await GroupService.getMyGroups(req.user.id);
        res.json({ status: 'success', data: groups });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

// Create a new group
router.post('/create', authMiddleware, async (req, res) => {
    try {
        const { name, description, subject } = req.body;
        if (!name) return res.status(400).json({ status: 'error', message: 'Name is required' });

        const group = await GroupService.createGroup(req.user.id, { name, description, subject });
        res.status(201).json({ status: 'success', data: group });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

// Join group via invite code
router.post('/join', authMiddleware, async (req, res) => {
    try {
        const { inviteCode } = req.body;
        if (!inviteCode) return res.status(400).json({ status: 'error', message: 'Invite code required' });

        const result = await GroupService.joinGroup(req.user.id, inviteCode);
        res.json({ status: 'success', data: result });
    } catch (error) {
        res.status(400).json({ status: 'error', message: error.message });
    }
});

// Get group details
router.get('/:groupId', authMiddleware, async (req, res) => {
    try {
        const group = await GroupService.getGroupDetails(req.user.id, req.params.groupId);
        res.json({ status: 'success', data: group });
    } catch (error) {
        res.status(400).json({ status: 'error', message: error.message });
    }
});

// Post message to group
router.post('/:groupId/message', authMiddleware, async (req, res) => {
    try {
        const { text } = req.body;
        if (!text) return res.status(400).json({ status: 'error', message: 'Message text is required' });

        const message = await GroupService.postMessage(req.user.id, req.params.groupId, text);
        res.json({ status: 'success', data: message });
    } catch (error) {
        res.status(400).json({ status: 'error', message: error.message });
    }
});

// Share a note with the group
router.post('/:groupId/share/note', authMiddleware, async (req, res) => {
    try {
        const { noteId } = req.body;
        if (!noteId) return res.status(400).json({ status: 'error', message: 'Note ID is required' });

        const group = await GroupService.shareNote(req.user.id, req.params.groupId, noteId);
        res.json({ status: 'success', data: group });
    } catch (error) {
        res.status(400).json({ status: 'error', message: error.message });
    }
});

// Share an MCQ with the group
router.post('/:groupId/share/mcq', authMiddleware, async (req, res) => {
    try {
        const { mcqId } = req.body;
        if (!mcqId) return res.status(400).json({ status: 'error', message: 'MCQ ID is required' });

        const group = await GroupService.shareMcq(req.user.id, req.params.groupId, mcqId);
        res.json({ status: 'success', data: group });
    } catch (error) {
        res.status(400).json({ status: 'error', message: error.message });
    }
});

// Remove a note from the group (admin only)
router.delete('/:groupId/remove/note/:noteId', authMiddleware, async (req, res) => {
    try {
        const group = await GroupService.removeNote(req.user.id, req.params.groupId, req.params.noteId);
        res.json({ status: 'success', data: group });
    } catch (error) {
        res.status(400).json({ status: 'error', message: error.message });
    }
});

// Remove an MCQ from the group (admin only)
router.delete('/:groupId/remove/mcq/:mcqId', authMiddleware, async (req, res) => {
    try {
        const group = await GroupService.removeMcq(req.user.id, req.params.groupId, req.params.mcqId);
        res.json({ status: 'success', data: group });
    } catch (error) {
        res.status(400).json({ status: 'error', message: error.message });
    }
});

// Delete a message from the group (admin or sender)
router.delete('/:groupId/message/:messageId', authMiddleware, async (req, res) => {
    try {
        const group = await GroupService.deleteMessage(req.user.id, req.params.groupId, req.params.messageId);
        res.json({ status: 'success', data: group });
    } catch (error) {
        res.status(400).json({ status: 'error', message: error.message });
    }
});

// Remove a user from the group (admin only)
router.delete('/:groupId/user/:userId', authMiddleware, async (req, res) => {
    try {
        const group = await GroupService.removeUser(req.user.id, req.params.groupId, req.params.userId);
        res.json({ status: 'success', data: group });
    } catch (error) {
        res.status(400).json({ status: 'error', message: error.message });
    }
});

// Delete the entire group (creator only)
router.delete('/:groupId', authMiddleware, async (req, res) => {
    try {
        const result = await GroupService.deleteGroup(req.user.id, req.params.groupId);
        res.json({ status: 'success', data: result });
    } catch (error) {
        res.status(400).json({ status: 'error', message: error.message });
    }
});

export default router;
