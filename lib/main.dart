import 'dart:io';
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

  
  RegExp _getPattern() {
    switch (_selectedFormat) {
      case LogFormat.pclCE:
        return RegExp(r'^\[(.*?)\]\s*\[(.*?)\]\s*\[(.*?)\]\s*\[(.*?)\]\s*(.*)$');
      case LogFormat.pcl:
        return RegExp(r'^\[(.*?)\]\s*<(.*?)>\s*(?:\[(.*?)\]\s*)?(.*)$');
    }
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

    final file = _currentFile!;
    final pattern = _getPattern();
    
    
    final lines = await file.readAsLines();
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
            currentTimestamp, currentP1, currentP2, currentP3, messageBuffer.toString().trimRight()
          ));
        }

        
        currentTimestamp = match.group(1);
        messageBuffer.clear();

        if (_selectedFormat == LogFormat.pclCE) {
          
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
        currentTimestamp, currentP1, currentP2, currentP3, messageBuffer.toString().trimRight()
      ));
    }

    if (mounted) {
      setState(() {
        _logs = parsedLogs;
        _isLoading = false;
      });
    }
  }

  
  LogEntry _createEntry(String ts, String? p1, String? p2, String? p3, String msg) {
    if (_selectedFormat == LogFormat.pclCE) {
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

  
  Color _getLevelColor(String? level) {
    if (level == null) return Colors.white;
    switch (level.toUpperCase()) {
      case 'ERR': case 'ERROR': case 'FATAL': return const Color(0xFFFFEBEE);
      case 'WRN': case 'WARN': return const Color(0xFFFFF3E0);
      case 'DBG': case 'DEBUG': return const Color(0xFFE8F5E9);
      default: return Colors.white;
    }
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
                    controller: _verticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      scrollDirection: Axis.vertical,
                      child: Scrollbar(
                        controller: _horizontalController,
                        thumbVisibility: true,
                        notificationPredicate: (n) => n.depth == 1,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                            dataRowMinHeight: 30,
                            dataRowMaxHeight: double.infinity,
                            columnSpacing: 20,
                            
                            
                            columns: _selectedFormat == LogFormat.pclCE 
                              ? const [ 
                                  DataColumn(label: Text('Time')),
                                  DataColumn(label: Text('Level')),
                                  DataColumn(label: Text('Component')),
                                  DataColumn(label: Text('Module')),
                                  DataColumn(label: Text('Message')),
                                ]
                              : const [ 
                                  DataColumn(label: Text('Time')),
                                  DataColumn(label: Text('Thread')), 
                                  DataColumn(label: Text('Module')),
                                  DataColumn(label: Text('Message')),
                                ],
                            
                            
                            rows: _logs.map((log) {
                              
                              List<DataCell> cells;
                              
                              if (_selectedFormat == LogFormat.pclCE) {
                                
                                cells = [
                                  DataCell(Text(log.timestamp, style: commonStyle)),
                                  DataCell(Text(log.level ?? "", style: commonStyle.copyWith(fontWeight: FontWeight.bold))),
                                  DataCell(Text(log.component ?? "", style: commonStyle)),
                                  DataCell(Text(log.module, style: commonStyle)),
                                ];
                              } else {
                                
                                cells = [
                                  DataCell(Text(log.timestamp, style: commonStyle)),
                                  DataCell(Text(log.thread ?? "", style: commonStyle.copyWith(color: Colors.blue.shade800))), 
                                  DataCell(Text(log.module, style: commonStyle)),
                                ];
                              }

                              
                              cells.add(DataCell(
                                Container(
                                  width: 600,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: ExpandableLogMessage(
                                        message: log.message,
                                        style: commonStyle,
                                  ),
                                ),
                              ));

                              return DataRow(
                                
                                color: _selectedFormat == LogFormat.pclCE 
                                    ? WidgetStateProperty.resolveWith((states) => _getLevelColor(log.level))
                                    : null, 
                                cells: cells,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}