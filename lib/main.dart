import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'extendable_log_widget.dart';

void main() {
  runApp(const MaterialApp(title: 'PCL Log Viewer', home: LogViewerPage()));
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


class LogParseResult {
  final List<LogEntry> logs;
  final String? version;
  final String? identity;
  final String? version_type;
  final String? exc_path;
  final String? sys_encoding;
  final bool? isAdmin;
  final String? exit_flag;
  final String? sys_ver;

  LogParseResult({
    required this.logs,
    this.version,
    this.identity,
    this.version_type,
    this.exc_path,
    this.sys_encoding,
    this.isAdmin,
    this.exit_flag,
    this.sys_ver,
  });
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


LogParseResult parseLogFile(Map<String, dynamic> params) {
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

  String? version;
  String? identity;
  String? version_type;
  String? exc_path;
  String? sys_encoding;
  bool? isAdmin;
  String? exit_flag;
  String? sys_ver;

  // Helper to parse metadata from a given string. Returns true if metadata was found.
  bool parseMetadata(String text) {
    if (text.contains('程序版本：')) {
      version = text.substring(text.indexOf('程序版本：') + 5).trim();
      return true;
    } else if (text.contains('识别码：')) {
      final info = text.substring(text.indexOf('识别码：') + 4).trim();
      if (format == LogFormat.pclCE) {
        identity = info;
      } else {
        final parts = info.split('，');
        identity = parts.isNotEmpty ? parts[0] : null;
        version_type = parts.length > 1 ? parts[1] : null;
      }
      return true;
    } else if (text.contains('程序路径：')) {
      exc_path = text.substring(text.indexOf('程序路径：') + 5).trim();
      return true;
    } else if (text.contains('系统编码：')) {
      sys_encoding = text.substring(text.indexOf('系统编码：') + 5).trim();
      return true;
    } else if (text.contains('管理员权限：')) {
      final value = text.substring(text.indexOf('管理员权限：') + 6).trim();
      isAdmin = value.toLowerCase() == 'true';
      return true;
    } else if (text.contains('程序已退出，返回值：')) {
      exit_flag = text.substring(text.indexOf('程序已退出，返回值：') + 10).trim();
      return true;
    } else if (format == LogFormat.pclCE && text.contains('系统版本：')) {
      sys_ver = text.substring(text.indexOf('系统版本：') + 5).trim();
      return true;
    }
    return false;
  }

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

      String messageContent;
      if (format == LogFormat.pclCE) {
        currentP1 = match.group(2); 
        currentP2 = match.group(3); 
        currentP3 = match.group(4); 
        messageContent = match.group(5) ?? '';
      } else {
        currentP1 = match.group(2); 
        currentP2 = match.group(3) ?? "/"; 
        currentP3 = null;           
        messageContent = match.group(4) ?? '';
      }

      messageBuffer.write(messageContent);
      parseMetadata(messageContent); // Also check for metadata within the log message

    } else {
      // Not a log line, so it could be metadata or a multi-line message
      final bool isMetadata = parseMetadata(line);

      // Only append to message buffer if it's not a metadata line
      if (!isMetadata && currentTimestamp != null) {
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

  return LogParseResult(
    logs: parsedLogs,
    version: version,
    identity: identity,
    version_type: version_type,
    exc_path: exc_path,
    sys_encoding: sys_encoding,
    isAdmin: isAdmin,
    exit_flag: exit_flag,
    sys_ver: sys_ver,
  );
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

  String? _version;
  String? _identity;
  String? _version_type;
  String? _exc_path;
  String? _sys_encoding;
  bool? _isAdmin;
  String? _exit_flag;
  String? _sys_ver;

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

    setState(() {
      _isLoading = true;
      _logs = [];
      _version = null;
      _identity = null;
      _version_type = null;
      _exc_path = null;
      _sys_encoding = null;
      _isAdmin = null;
      _exit_flag = null;
      _sys_ver = null;
    });

    final params = {
      'filePath': _currentFile!.path,
      'format': _selectedFormat,
    };
    
    final result = await compute(parseLogFile, params);

    if (mounted) {
      setState(() {
        _logs = result.logs;
        _version = result.version;
        _identity = result.identity;
        _version_type = result.version_type;
        _exc_path = result.exc_path;
        _sys_encoding = result.sys_encoding;
        _isAdmin = result.isAdmin;
        _exit_flag = result.exit_flag;
        _sys_ver = result.sys_ver;
        _isLoading = false;
      });
    }
  }

  
  Color _getLevelColor(String? level) {
    if (level == null) return Colors.white;
    switch (level.toUpperCase()) {
      case 'ERR!': case 'FTL!': return const Color(0xFFFFEBEE);
      case 'WARN': return const Color(0xFFFFF3E0);
      case 'DBG': return const Color(0xFFE8F5E9);
      default: return Colors.white;
    }
  }

  Widget _buildInfoPanel() {
    Container container(Widget? child) => Container(
      width: 350,
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey.shade50,
      child: child,
    );

    if (_isLoading) {
      return container(const Center(child: CircularProgressIndicator()));
    }

    final List<Widget> children = [];

    if (_version != null) {
      children.add(Text('PCL 版本：$_version${_version_type == null ? '' : '（$_version_type）'}', style: commonStyle));
    }
    if (_identity != null) {
      children.add(Text('识别码：$_identity', style: commonStyle));
    }
    if (_exc_path != null) {
      children.add(Text('程序路径：$_exc_path', style: commonStyle));
    }
    if (_sys_encoding != null) {
      children.add(Text('日志所在的系统编码：$_sys_encoding', style: commonStyle));
    }
    if (_selectedFormat == LogFormat.pclCE && _sys_ver != null) {
      children.add(Text('日志所在的系统版本：$_sys_ver', style: commonStyle));
    }
    if (_isAdmin != null) {
      children.add(Text(
        _isAdmin! ? '日志发生时程序正在使用管理员权限。' : '日志发生时程序未使用管理员权限。',
        style: commonStyle.copyWith(color: _isAdmin! ? Colors.red : null),
      ));
    }
    if (_logs.isNotEmpty) {
      final bool success = _exit_flag?.toLowerCase() == 'success';
      children.add(Text(
        success ? '程序退出成功' : '程序退出失败',
        style: commonStyle.copyWith(color: success ? Colors.green : Colors.red),
      ));
    }

    if (children.isEmpty && _fileName != null) {
      return container(Center(child: Text("无法从日志中提取元数据。\n请检查日志格式是否正确。", style: commonStyle, textAlign: TextAlign.center)));
    }

    return container(
      ListView(
        children: children.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: e)).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PCL Log Viewer'),
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
            child: Row(
              children: [
                Expanded(
                  child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _logs.isEmpty
                      ? Center(child: Text("请选择文件并指定正确的日志格式。\n如果日志长时间不加载，请检查日志格式。", style: commonStyle.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center))
                      : Scrollbar(
                          controller: _horizontalController,
                          thumbVisibility: true,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = constraints.maxWidth;
                              
                              double otherColumnsWidth = _LogHeader.timeWidth + 32; // 32 is horizontal padding
                              if (_selectedFormat == LogFormat.pclCE) {
                                otherColumnsWidth += _LogHeader.levelWidth + _LogHeader.componentWidth + _LogHeader.moduleWidth;
                              } else {
                                otherColumnsWidth += _LogHeader.threadWidth + _LogHeader.moduleWidth;
                              }

                              final double messageWidth = max(200, screenWidth - otherColumnsWidth);
                              final double tableWidth = otherColumnsWidth + messageWidth;


                              return SingleChildScrollView(
                                controller: _horizontalController,
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: tableWidth,
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: SizedBox(
                                      width: tableWidth,
                                      height: constraints.maxHeight,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _LogHeader(format: _selectedFormat, style: commonStyle, messageWidth: messageWidth),
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
                                                    messageWidth: messageWidth,
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
                const VerticalDivider(width: 1),
                _buildInfoPanel(),
              ],
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
  final double messageWidth;

  const _LogHeader({required this.format, required this.style, required this.messageWidth});


  static const double timeWidth = 140;
  static const double levelWidth = 100;
  static const double componentWidth = 120;
  static const double moduleWidth = 140;
  static const double threadWidth = 320;

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
  final double messageWidth;

  const _LogDataRow({
    required this.log,
    required this.format,
    required this.style,
    required this.rowColor,
    required this.messageWidth,
  });

  @override
  Widget build(BuildContext context) {
    final cells = format == LogFormat.pclCE
        ? [
            _buildCell(log.timestamp, _LogHeader.timeWidth, style),
            _buildCell(log.level ?? "", _LogHeader.levelWidth, style.copyWith(fontWeight: FontWeight.bold)),
            _buildCell(log.component ?? "", _LogHeader.componentWidth, style),
            _buildCell(log.module, _LogHeader.moduleWidth, style),
            _buildMessageCell(log.message, messageWidth, style),
          ]
        : [
            _buildCell(log.timestamp, _LogHeader.timeWidth, style),
            _buildCell(log.thread ?? "", _LogHeader.threadWidth, style.copyWith(color: Colors.blue.shade800)),
            _buildCell(log.module, _LogHeader.moduleWidth, style),
            _buildMessageCell(log.message, messageWidth, style),
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