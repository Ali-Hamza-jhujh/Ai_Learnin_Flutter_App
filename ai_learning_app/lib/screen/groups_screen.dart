import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/group_service.dart';
import '../utils/app_theme.dart';
import 'group_detail_screen.dart';
import 'qr_scanner_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<dynamic> _groups = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await GroupService.getMyGroups();
      if (mounted) {
        setState(() {
          _groups = res['data'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load groups';
          _loading = false;
        });
      }
    }
  }

  void _showCreateGroupDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Create Study Group', style: TextStyle(color: AppColors.textWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(
              controller: nameCtrl,
              placeholder: 'Group Name',
              style: const TextStyle(color: AppColors.textWhite),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.inputBorder),
              ),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: descCtrl,
              placeholder: 'Description',
              style: const TextStyle(color: AppColors.textWhite),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.inputBorder),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              await GroupService.createGroup(name: nameCtrl.text.trim(), description: descCtrl.text.trim());
              _loadGroups();
            },
            child: const Text('Create', style: TextStyle(color: AppColors.cyan)),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog() {
    final codeCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Join Study Group', style: TextStyle(color: AppColors.textWhite)),
        content: CupertinoTextField(
          controller: codeCtrl,
          placeholder: 'Enter 6-character Invite Code',
          style: const TextStyle(color: AppColors.textWhite),
          textCapitalization: TextCapitalization.characters,
          decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.inputBorder),
          ),
          suffix: CupertinoButton(
            padding: const EdgeInsets.only(right: 12),
            child: const Icon(CupertinoIcons.camera_viewfinder, color: AppColors.cyan, size: 24),
            onPressed: () async {
              final code = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const QRScannerScreen()),
              );
              if (code != null) {
                codeCtrl.text = code;
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final code = codeCtrl.text.trim().toUpperCase();
              if (code.length < 4 || code.length > 6) {
                showCupertinoDialog(
                  context: context,
                  builder: (_) => CupertinoAlertDialog(
                    title: const Text('Invalid Code'),
                    content: const Text('Invite code must be 4-6 characters.'),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text('OK'),
                        onPressed: () => Navigator.pop(_),
                      ),
                    ],
                  ),
                );
                return;
              }
              Navigator.pop(context);
              try {
                await GroupService.joinGroup(code);
                _loadGroups();
                if (mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (_) => CupertinoAlertDialog(
                      title: const Text('Success'),
                      content: const Text('You have joined the group successfully!'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('OK'),
                          onPressed: () => Navigator.pop(_),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (_) => CupertinoAlertDialog(
                      title: const Text('Error'),
                      content: Text('Failed to join group: ${e.toString()}'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('OK'),
                          onPressed: () => Navigator.pop(_),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('Join', style: TextStyle(color: AppColors.cyan)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.bg,
        middle: const Text('Study Groups', style: TextStyle(color: AppColors.textWhite)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _showJoinGroupDialog,
              child: const Icon(CupertinoIcons.person_add, color: AppColors.violetLight, size: 24),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _showCreateGroupDialog,
              child: const Icon(CupertinoIcons.add, color: AppColors.cyan, size: 24),
            ),
          ],
        ),
      ),
      child: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
                    : _groups.isEmpty
                        ? const Center(
                            child: Text('You are not in any study groups yet.\nCreate or join one!', 
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey)))
                        : _buildGroupList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupDetailScreen(groupId: group['_id']),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGrad,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      group['name'][0].toUpperCase(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group['name'], style: const TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${group['members'].length} members', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }
}
