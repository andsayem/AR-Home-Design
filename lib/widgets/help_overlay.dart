import 'package:flutter/material.dart';

class HelpOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const HelpOverlay({super.key, required this.onDismiss});

  @override
  State<HelpOverlay> createState() => _HelpOverlayState();
}

class _HelpOverlayState extends State<HelpOverlay> {
  int _currentPage = 0;

  final List<Map<String, String>> _steps = [
    {
      'title': 'Capture Room',
      'desc': 'Tap "Capture" to lock the photo of your room. This becomes your canvas for design.',
      'icon': '📸',
    },
    {
      'title': 'Draw Walls',
      'desc': 'Use the Line or Shape tools to draw walls. Real-time dimensions will show up automatically!',
      'icon': '📐',
    },
    {
      'title': 'Place Furniture',
      'desc': 'Open the "Furniture" menu to add sofas, plants, and more. Long-press to move or delete.',
      'icon': '🛋️',
    },
    {
      'title': 'Magic AI Eraser',
      'desc': 'Want to remove an old desk? Use the "Eraser+" tool to paint over it and let AI clean the space.',
      'icon': '✨',
    },
    {
      'title': 'Master Controls',
      'desc': 'Select any object to rotate, resize, or change its transparency for a realistic look.',
      'icon': '🎮',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentPage];

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: const Color(0xFF4F8EF7).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F8EF7).withValues(alpha: 0.1),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                step['icon']!,
                style: const TextStyle(fontSize: 52),
              ),
              const SizedBox(height: 20),
              Text(
                step['title']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                step['desc']!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => setState(() => _currentPage--),
                      child: const Text('Back', style: TextStyle(color: Colors.white38)),
                    )
                  else
                    const SizedBox(width: 60),
                  
                  // Dots
                  Row(
                    children: List.generate(_steps.length, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentPage == index ? 12 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? const Color(0xFF4F8EF7) : Colors.white12,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),

                  TextButton(
                    onPressed: () {
                      if (_currentPage < _steps.length - 1) {
                        setState(() => _currentPage++);
                      } else {
                        widget.onDismiss();
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF4F8EF7).withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _currentPage < _steps.length - 1 ? 'Next' : 'Got it!',
                      style: const TextStyle(color: Color(0xFF4F8EF7), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
