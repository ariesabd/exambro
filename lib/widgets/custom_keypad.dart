import 'package:flutter/material.dart';

class CustomKeypad extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onSubmitPressed;
  final bool showSubmit;

  const CustomKeypad({
    Key? key,
    required this.onKeyPressed,
    required this.onDeletePressed,
    required this.onSubmitPressed,
    this.showSubmit = true,
  }) : super(key: key);

  Widget _buildKey(BuildContext context, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          color: Colors.white.withOpacity(0.08),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onKeyPressed(value),
            highlightColor: Colors.white.withOpacity(0.1),
            splashColor: Colors.white.withOpacity(0.2),
            child: SizedBox(
              height: 70,
              child: Center(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey(BuildContext context, Widget child, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            highlightColor: Colors.white.withOpacity(0.05),
            splashColor: Colors.white.withOpacity(0.1),
            child: SizedBox(
              height: 70,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildKey(context, '1'),
              _buildKey(context, '2'),
              _buildKey(context, '3'),
            ],
          ),
          Row(
            children: [
              _buildKey(context, '4'),
              _buildKey(context, '5'),
              _buildKey(context, '6'),
            ],
          ),
          Row(
            children: [
              _buildKey(context, '7'),
              _buildKey(context, '8'),
              _buildKey(context, '9'),
            ],
          ),
          Row(
            children: [
              // Tombol Delete (Backspace)
              _buildSpecialKey(
                context,
                const Icon(
                  Icons.backspace_outlined,
                  color: Colors.white70,
                  size: 26,
                ),
                onDeletePressed,
              ),
              _buildKey(context, '0'),
              // Tombol OK/Submit
              _buildSpecialKey(
                context,
                showSubmit
                    ? const Icon(
                        Icons.check_circle,
                        color: Colors.emerald,
                        size: 38,
                      )
                    : const SizedBox.shrink(),
                onSubmitPressed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
