import 'package:flutter/material.dart';

class ExpandableLogMessage extends StatefulWidget {
  final String message;
  final TextStyle style;

  const ExpandableLogMessage({
    super.key,
    required this.message,
    required this.style,
  });

  @override
  State<ExpandableLogMessage> createState() => _ExpandableLogMessageState();
}

class _ExpandableLogMessageState extends State<ExpandableLogMessage> {
  bool _isExpanded = false;
  
  // 阈值配置
  static const int _maxLinesThreshold = 4; // 超过多少行折叠
  static const int _maxCharsThreshold = 600; // 超过多少字符折叠 (针对单行长指令)

  @override
  Widget build(BuildContext context) {
    final lines = widget.message.split('\n');
    final charCount = widget.message.length;

    // 判定条件：行数过多 OR 字符数过多
    final bool isTooLong = lines.length > _maxLinesThreshold || charCount > _maxCharsThreshold;

    // 如果不需要折叠，直接返回
    if (!isTooLong) {
      return SelectableText(widget.message, style: widget.style);
    }

    // 计算折叠后要显示的预览文本
    String previewText;
    String buttonText;

    if (lines.length > _maxLinesThreshold) {
      // 情况 A：行数太多 -> 取前3行
      previewText = "${lines.take(3).join('\n')}...";
      buttonText = "展开剩余 ${lines.length - 3} 行";
    } else {
      // 情况 B：单行但字符太长 -> 取前300个字符
      // 这里的 300 可以比 _maxCharsThreshold 小，制造明显的“截断感”
      previewText = "${widget.message.substring(0, 300)}..."; 
      buttonText = "展开完整内容 (${(charCount / 1024).toStringAsFixed(1)} KB)";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 文本区域
        SelectableText(
          _isExpanded ? widget.message : previewText,
          style: widget.style,
        ),
        
        // 按钮区域
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  _isExpanded ? "收起" : buttonText,
                  style: widget.style.copyWith(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'LXGW-WenKai', // 按钮文字可以用中文特化字体
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}