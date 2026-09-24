import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/app_theme.dart';
import 'category_items_screen.dart';

class HumanAnatomyExplorerScreen extends StatefulWidget {
  const HumanAnatomyExplorerScreen({super.key});

  @override
  State<HumanAnatomyExplorerScreen> createState() =>
      _HumanAnatomyExplorerScreenState();
}

class _HumanAnatomyExplorerScreenState
    extends State<HumanAnatomyExplorerScreen> {
  bool _isMale = true;
  bool _showLabels = true;
  String? _highlightedPart;

  // Simple definition of body regions (percentages of width/height to make it responsive)
  final List<Map<String, dynamic>> _bodyParts = [
    {
      "id": "Head",
      "label": "Head & Neck",
      "top": 0.05,
      "left": 0.4,
      "width": 0.2,
      "height": 0.15,
      "query": "Head"
    },
    {
      "id": "Chest",
      "label": "Thorax (Chest)",
      "top": 0.2,
      "left": 0.35,
      "width": 0.3,
      "height": 0.2,
      "query": "Chest"
    },
    {
      "id": "Abdomen",
      "label": "Abdomen",
      "top": 0.4,
      "left": 0.35,
      "width": 0.3,
      "height": 0.15,
      "query": "Abdomen"
    },
    {
      "id": "LeftArm",
      "label": "Left Arm",
      "top": 0.2,
      "left": 0.65,
      "width": 0.15,
      "height": 0.35,
      "query": "Arm"
    },
    {
      "id": "RightArm",
      "label": "Right Arm",
      "top": 0.2,
      "left": 0.2,
      "width": 0.15,
      "height": 0.35,
      "query": "Arm"
    },
    {
      "id": "Legs",
      "label": "Legs",
      "top": 0.55,
      "left": 0.3,
      "width": 0.4,
      "height": 0.4,
      "query": "Leg"
    },
  ];

  void _onPartTapped(Map<String, dynamic> part) {
    setState(() {
      _highlightedPart = part['id'] as String;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.heart_fill,
                      color: AppColors.cyan),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    part['label'] as String,
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Explore detailed medical definitions, diseases, and anatomy related to the ${part['label']}.",
              style: const TextStyle(color: AppColors.textSub, fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryItemsScreen(
                        category: "Anatomy",
                      ),
                    ),
                  );
                },
                child: const Text(
                  "Explore Anatomy",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).whenComplete(() {
      setState(() {
        _highlightedPart = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 3.0,
                      child: AspectRatio(
                        aspectRatio: 0.5,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            final h = constraints.maxHeight;

                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    _isMale
                                        ? "assets/images/male_anatomy_base.png"
                                        : "assets/images/female_anatomy_base.png",
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                ..._bodyParts.map((part) {
                                  final isHighlighted =
                                      _highlightedPart == part['id'];
                                  final top = part['top'] * h;
                                  final left = part['left'] * w;
                                  final width = part['width'] * w;
                                  final height = part['height'] * h;

                                  return Positioned(
                                    top: top,
                                    left: left,
                                    width: width,
                                    height: height,
                                    child: GestureDetector(
                                      onTap: () => _onPartTapped(part),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isHighlighted
                                              ? AppColors.cyan
                                                  .withValues(alpha: 0.3)
                                              : Colors.transparent,
                                          border: isHighlighted
                                              ? Border.all(
                                                  color: AppColors.cyan,
                                                  width: 2)
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: _showLabels
                                            ? Center(
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.bgSurface
                                                        .withValues(alpha: 0.8),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                    border: Border.all(
                                                        color: AppColors.cyan
                                                            .withValues(
                                                                alpha: 0.5)),
                                                  ),
                                                  child: Text(
                                                    part['label'] as String,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.textWhite,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon:
                    const Icon(CupertinoIcons.back, color: AppColors.textWhite),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  "Interactive Anatomy",
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _buildToggleButton(
                      label: "Male",
                      isActive: _isMale,
                      onTap: () => setState(() => _isMale = true),
                    ),
                    _buildToggleButton(
                      label: "Female",
                      isActive: !_isMale,
                      onTap: () => setState(() => _isMale = false),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showLabels = !_showLabels),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _showLabels
                        ? AppColors.cyan.withValues(alpha: 0.2)
                        : AppColors.bgSurface,
                    border: Border.all(
                      color: _showLabels ? AppColors.cyan : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _showLabels
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        color:
                            _showLabels ? AppColors.cyan : AppColors.textLight,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Labels",
                        style: TextStyle(
                          color: _showLabels
                              ? AppColors.cyan
                              : AppColors.textLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.cyan : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textLight,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
