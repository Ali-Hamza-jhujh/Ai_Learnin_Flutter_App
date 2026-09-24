import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/group_service.dart';
import '../utils/app_theme.dart';

class ShareToGroupDialog extends StatefulWidget {
  final String contentId;
  final bool isNote; // true if note, false if MCQ

  const ShareToGroupDialog({
    super.key,
    required this.contentId,
    required this.isNote,
  });

  @override
  State<ShareToGroupDialog> createState() => _ShareToGroupDialogState();
}

class _ShareToGroupDialogState extends State<ShareToGroupDialog> {
  List<dynamic> _groups = [];
  bool _loading = true;
  String? _error;
  String? _selectedGroupId;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final res = await GroupService.getMyGroups();
      if (mounted) {
        setState(() {
          _groups = res['data'] as List<dynamic>? ?? [];
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

  Future<void> _shareContent() async {
    if (_selectedGroupId == null) return;
    setState(() => _sharing = true);

    try {
      if (widget.isNote) {
        await GroupService.shareNote(_selectedGroupId!, widget.contentId);
      } else {
        await GroupService.shareMcq(_selectedGroupId!, widget.contentId);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to share content';
          _sharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        widget.isNote ? 'Share Note to Group' : 'Share Quiz to Group',
        style: const TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 250,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
                : _groups.isEmpty
                    ? const Center(
                        child: Text(
                          'You are not in any study groups.\nJoin or create one first!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _groups.length,
                        itemBuilder: (context, index) {
                          final group = _groups[index];
                          final isSelected = _selectedGroupId == group['_id'];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedGroupId = group['_id'];
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.violet.withValues(alpha: 0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.violet : AppColors.inputBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGrad,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        group['name'][0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      group['name'],
                                      style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: AppColors.violet),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        if (!_loading && _groups.isNotEmpty)
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: AppColors.violet,
            borderRadius: BorderRadius.circular(12),
            onPressed: _selectedGroupId == null || _sharing ? null : _shareContent,
            child: _sharing
                ? const SizedBox(width: 20, height: 20, child: CupertinoActivityIndicator(color: Colors.white))
                : const Text('Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
