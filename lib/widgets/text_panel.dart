import 'package:flutter/material.dart';

class TextPanel extends StatefulWidget {
  final String text;
  final ValueChanged<String> onChanged;

  const TextPanel({super.key, required this.text, required this.onChanged});

  @override
  State<TextPanel> createState() => _TextPanelState();
}

class _TextPanelState extends State<TextPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  void didUpdateWidget(covariant TextPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text && widget.text != _controller.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      expands: true,
      maxLines: null,
      minLines: null,
      textAlignVertical: TextAlignVertical.top,
      onChanged: widget.onChanged,
      style: const TextStyle(fontSize: 16, height: 1.5),
      decoration: InputDecoration(
        hintText: '在此输入文字，将实时同步到所有已连接设备…\n\n长按（手机）或右键（电脑）可复制 / 粘贴',
        hintStyle: const TextStyle(color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
