import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'extendable_log_widget.dart';

void main() {
  runApp(const MaterialApp(home: LogViewerPage()));
}


class LogEntry {
  final String timestamp;
  final String message;
  final String module;
  final String? level;
  final String? component;
  final String? thread;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.module,
    this.level,
    this.component,
    this.thread,
  });
}


enum LogFormat {
  pclCE,    
  pcl,  
}


LogEntry _createEntry(LogFormat format, String ts, String? p1, String? p2, String? p3, String msg) {
  if (format == LogFormat.pclCE) {
    return LogEntry(
      timestamp: ts,
      level: p1 ?? "",
      component: p2 ?? "",
      module: p3 ?? "",
      message: msg,
    );
  } else {
    return LogEntry(
      timestamp: ts,
      thread: p1 ?? "",   
      module: p2 ?? "",   
      message: msg,
    );
  }
}


RegExp _getPatternForFormat(LogFormat format) {
  switch (format) {
    case LogFormat.pclCE:
      return RegExp(r'^\[(.*?)\]\s*\[(.*?)\]\s*\[(.*?)\]\s*\[(.*?)\]\s*(.*)$');
    case LogFormat.pcl:
      return RegExp(r'^\[(.*?)\]\s*<(.*?)>\s*(?:\[(.*?)\]\s*)?(.*)$');
  }
}


List<LogEntry> parseLogFile(Map<String, dynamic> params) {
  final String filePath = params['filePath'];
  final LogFormat format = params['format'];
  final File file = File(filePath);

  final pattern = _getPatternForFormat(format);
  
  final lines = file.readAsLinesSync(); 
  final List<LogEntry> parsedLogs = [];

  String? currentTimestamp;
  String? currentP1; 
  String? currentP2; 
  String? currentP3; 
  StringBuffer messageBuffer = StringBuffer();

  for (var line in lines) {
    final match = pattern.firstMatch(line);

    if (match != null) {
      if (currentTimestamp != null) {
        parsedLogs.add(_createEntry(
          format, currentTimestamp, currentP1, currentP2, currentP3, messageBuffer.toString().trimRight()
        ));
      }

      currentTimestamp = match.group(1);
      messageBuffer.clear();

      if (format == LogFormat.pclCE) {
        currentP1 = match.group(2); 
        currentP2 = match.group(3); 
        currentP3 = match.group(4); 
        messageBuffer.write(match.group(5)); 
      } else {
        currentP1 = match.group(2); 
        currentP2 = match.group(3) ?? "/"; 
        currentP3 = null;           
        messageBuffer.write(match.group(4)); 
      }

    } else {
      if (currentTimestamp != null) {
        messageBuffer.writeln();
        messageBuffer.write(line);
      }
    }
  }

  if (currentTimestamp != null) {
    parsedLogs.add(_createEntry(
      format, currentTimestamp, currentP1, currentP2, currentP3, messageBuffer.toString().trimRight()
    ));
  }

  return parsedLogs;
}


class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  List<LogEntry> _logs = [];
  bool _isLoading = false;
  String? _fileName;
  File? _currentFile; 

  
  LogFormat _selectedFormat = LogFormat.pclCE;

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  
  final commonStyle = const TextStyle(
    fontFamily: 'CaskaydiaCoveNerdFont',
    fontFamilyFallback: ['LXGW-WenKai'],
    fontSize: 16,
  );

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['log', 'txt'],
    );

    if (result != null) {
      setState(() {
        _currentFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
        _logs = []; 
      });
      _parseLogs(); 
    }
  }

  
  void _onFormatChanged(LogFormat? newFormat) {
    if (newFormat != null && newFormat != _selectedFormat) {
      setState(() {
        _selectedFormat = newFormat;
      });
      
      if (_currentFile != null) {
        _parseLogs();
      }
    }
  }

  Future<void> _parseLogs() async {
    if (_currentFile == null) return;

    setState(() => _isLoading = true);

    final params = {
      'filePath': _currentFile!.path,
      'format': _selectedFormat,
    };
    
    final parsedLogs = await compute(parseLogFile, params);

    if (mounted) {
      setState(() {
        _logs = parsedLogs;
        _isLoading = false;
      });
    }
  }

  
  Color _getLevelColor(String? level) {
    if (level == null) return Colors.white;
    switch (level.toUpperCase()) {
      case 'ERR': case 'ERROR': case 'FTL!': return const Color(0xFFFFEBEE);
      case 'WRN': case 'WARN': return const Color(0xFFFFF3E0);
      case 'DBG': case 'DEBUG': return const Color(0xFFE8F5E9);
      default: return Colors.white;
    }
  }

  double _calculateTotalWidth() {
    double total = _LogHeader.timeWidth + _LogHeader.messageWidth + 32; 
    if (_selectedFormat == LogFormat.pclCE) {
      total += _LogHeader.levelWidth + _LogHeader.componentWidth + _LogHeader.moduleWidth;
    } else {
      total += _LogHeader.threadWidth + _LogHeader.moduleWidth;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LogViewer'),
        actions: [
          if (_fileName != null)
            Center(child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text("$_fileName (${_logs.length} 条)"),
            ))
        ],
      ),
      body: Column(
        children: [
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text("打开日志"),
                ),
                const SizedBox(width: 20),
                
                
                const Text("日志格式: "),
                const SizedBox(width: 8),
                DropdownButton<LogFormat>(
                  value: _selectedFormat,
                  onChanged: _isLoading ? null : _onFormatChanged,
                  items: const [
                    DropdownMenuItem(
                      value: LogFormat.pclCE,
                      child: Text("PCL CE ([Level] [Comp] [Mod])"),
                    ),
                    DropdownMenuItem(
                      value: LogFormat.pcl,
                      child: Text("PCL2 (<Thread> [Mod])"),
                    ),
                  ],
                ),

                const SizedBox(width: 16),
                if (_isLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          const Divider(height: 1),
          
          
          Expanded(
            child: _logs.isEmpty
                ? Center(child: Text("请选择文件并指定正确的日志格式。如果日志长时间不加载，请检查日志格式。", style: commonStyle.copyWith(fontWeight: FontWeight.bold)))
                : Scrollbar(
                    controller: _horizontalController,
                    thumbVisibility: true,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tableWidth = _calculateTotalWidth();
                        final screenWidth = constraints.maxWidth;
                        
                        return SingleChildScrollView(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: max(tableWidth, screenWidth),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: SizedBox(
                                width: tableWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _LogHeader(format: _selectedFormat, style: commonStyle),
                                    const Divider(height: 1),
                                    Expanded(
                                      child: Scrollbar(
                                        controller: _verticalController,
                                        thumbVisibility: true,
                                        child: ListView.builder(
                                          controller: _verticalController,
                                          itemCount: _logs.length,
                                          itemBuilder: (context, index) {
                                            final log = _logs[index];
                                            return _LogDataRow(
                                              log: log,
                                              format: _selectedFormat,
                                              style: commonStyle,
                                              rowColor: _selectedFormat == LogFormat.pclCE
                                                  ? _getLevelColor(log.level)
                                                  : Colors.white,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}


class _LogHeader extends StatelessWidget {
  final LogFormat format;
  final TextStyle style;

  const _LogHeader({required this.format, required this.style});


  static const double timeWidth = 140;
  static const double levelWidth = 100;
  static const double componentWidth = 120;
  static const double moduleWidth = 140;
  static const double threadWidth = 320;
  static const double messageWidth = 800;

  @override
  Widget build(BuildContext context) {
    final columns = format == LogFormat.pclCE
        ? [
            _buildHeaderCell('Time', timeWidth),
            _buildHeaderCell('Level', levelWidth),
            _buildHeaderCell('Component', componentWidth),
            _buildHeaderCell('Module', moduleWidth),
            _buildHeaderCell('Message', messageWidth),
          ]
        : [
            _buildHeaderCell('Time', timeWidth),
            _buildHeaderCell('Thread', threadWidth),
            _buildHeaderCell('Module', moduleWidth),
            _buildHeaderCell('Message', messageWidth),
          ];
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(children: columns),
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text, style: style.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}


class _LogDataRow extends StatelessWidget {
  final LogEntry log;
  final LogFormat format;
  final TextStyle style;
  final Color rowColor;

  const _LogDataRow({
    required this.log,
    required this.format,
    required this.style,
    required this.rowColor,
  });

  @override
  Widget build(BuildContext context) {
    final cells = format == LogFormat.pclCE
        ? [
            _buildCell(log.timestamp, _LogHeader.timeWidth, style),
            _buildCell(log.level ?? "", _LogHeader.levelWidth, style.copyWith(fontWeight: FontWeight.bold)),
            _buildCell(log.component ?? "", _LogHeader.componentWidth, style),
            _buildCell(log.module, _LogHeader.moduleWidth, style),
            _buildMessageCell(log.message, _LogHeader.messageWidth, style),
          ]
        : [
            _buildCell(log.timestamp, _LogHeader.timeWidth, style),
            _buildCell(log.thread ?? "", _LogHeader.threadWidth, style.copyWith(color: Colors.blue.shade800)),
            _buildCell(log.module, _LogHeader.moduleWidth, style),
            _buildMessageCell(log.message, _LogHeader.messageWidth, style),
          ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: rowColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1))
      ),
      child: Row(children: cells),
    );
  }

  Widget _buildCell(String text, double width, TextStyle textStyle) {
    return SizedBox(
      width: width,
      child: Text(text, style: textStyle, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildMessageCell(String message, double width, TextStyle textStyle) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ExpandableLogMessage(
        message: message,
        style: textStyle,
      ),
    );
  }
}