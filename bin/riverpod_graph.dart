import 'dart:io';

import 'package:riverpod_graph/riverpod_graph.dart';

void main(List<String> args) async {
  final targetDir = args.isNotEmpty ? Directory(args[args.length-1]) : Directory('lib');
  final printLogs =
      args.isNotEmpty ? args.any((arg) => arg == "--verbose") : false;
  if (!targetDir.existsSync()) {
    print('Directory ${targetDir.path} does not exist.');
    exit(1);
  }

  final analyzer = RiverpodGraphAnalyzer(printLogs);
  await analyzer.analyzeDirectory(targetDir);

  final mermaid = analyzer.generateMermaid();

  final html = analyzer.generateHtml(mermaid);
  analyzer.saveHtml(html, 'riverpod_graph.html');

  print('\n✅ Graph saved to riverpod_graph.html');
}
