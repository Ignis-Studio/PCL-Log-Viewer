import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MaterialApp(home: LogViewerPage()));
}

final commonStyle = const TextStyle(
  fontFamily: 'CaskaydiaCoveNerdFont', // 优先使用英文字体
  fontFamilyFallback: ['LXGW-WenKai'], // 英文字体缺字（如汉字）时，使用霞鹜文楷
  fontSize: 16,
);

class LogEntry {
  final String timestamp;
  final String level;
  final String component;
  final String module;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.component,
    required this.module,
    required this.message,
  });
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

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final RegExp _logPattern = RegExp(r'^\[(.*?)\]\s*\[(.*?)\]\s*\[(.*?)\]\s*\[(.*?)\]\s*(.*)$');

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }
  
  Future<void> _pickAndParseFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['log', 'txt'],
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
        _fileName = result.files.single.name;
        _logs = []; 
      });

      
      final file = File(result.files.single.path!);
      final logs = await _parseLogs(file);

      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    }
  }

  
  Future<List<LogEntry>> _parseLogs(File file) async {
    final lines = await file.readAsLines();
    final List<LogEntry> parsedLogs = [];

    
    String? currentTimestamp;
    String? currentLevel;
    String? currentComponent;
    String? currentModule;
    StringBuffer messageBuffer = StringBuffer(); 

    for (var line in lines) {
      
      final match = _logPattern.firstMatch(line);

      if (match != null) {
        
        if (currentTimestamp != null) {
          parsedLogs.add(LogEntry(
            timestamp: currentTimestamp,
            level: currentLevel!,
            component: currentComponent!,
            module: currentModule!,
            message: messageBuffer.toString().trimRight(), 
          ));
        }

        
        currentTimestamp = match.group(1);
        currentLevel = match.group(2);
        currentComponent = match.group(3);
        currentModule = match.group(4);
        
        messageBuffer.clear(); 
        messageBuffer.write(match.group(5)); 
      
      } else {
        
        
        if (currentTimestamp != null) {
          
          messageBuffer.writeln(); 
          messageBuffer.write(line); 
        } else {
          
          
        }
      }
    }

    
    if (currentTimestamp != null) {
      parsedLogs.add(LogEntry(
        timestamp: currentTimestamp,
        level: currentLevel!,
        component: currentComponent!,
        module: currentModule!,
        message: messageBuffer.toString().trimRight(),
      ));
    }

    return parsedLogs;
  }

  Color _getLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'ERR':
      case 'ERROR':
      case 'FTL!':
        return const Color(0xFFFFEBEE); 
      case 'WARN':
        return const Color(0xFFFFF3E0); 
      case 'DBG':
        return const Color(0xFFE8F5E9); 
      case 'INFO':
        return Colors.white;
      default:
        return Colors.grey.shade50;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PCL CE 日志查看器', style: commonStyle.copyWith(fontWeight: FontWeight.normal)),
        elevation: 1,
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
                  onPressed: _isLoading ? null : _pickAndParseFile,
                  icon: const Icon(Icons.folder_open),
                  label: Text("打开日志", style: commonStyle.copyWith(fontWeight: FontWeight.normal)),
                ),
                const SizedBox(width: 16),
                if (_isLoading) const SizedBox(
                  width: 20, height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2)
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _logs.isEmpty
                ? Center(child: Text("暂无日志数据", style: commonStyle.copyWith(fontWeight: FontWeight.normal)))
                : Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                          dataRowMinHeight: 30, 
                          dataRowMaxHeight: double.infinity, 
                          columnSpacing: 20,
                          columns: const [
                            DataColumn(label: Text('Time')),
                            DataColumn(label: Text('Level')),
                            DataColumn(label: Text('Component')),
                            DataColumn(label: Text('Module')),
                            DataColumn(label: Text('Message')), 
                          ],
                          rows: _logs.map((log) {
                            return DataRow(
                              color: WidgetStateProperty.resolveWith(
                                  (states) => _getLevelColor(log.level)),
                              cells: [
                                DataCell(Text(log.timestamp, style: commonStyle.copyWith(fontWeight: FontWeight.normal))),
                                DataCell(Text(log.level, style: commonStyle.copyWith(fontWeight: FontWeight.bold))),
                                DataCell(Text(log.component, style: commonStyle.copyWith(fontWeight: FontWeight.normal))),
                                DataCell(Text(log.module, style: commonStyle.copyWith(fontWeight: FontWeight.normal))),
                                DataCell(
                                  
                                  Container(
                                    width: 600, 
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: SelectableText( 
                                      log.message,
                                      style: commonStyle.copyWith(fontWeight: FontWeight.normal)
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
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