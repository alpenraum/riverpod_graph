import 'dart:io';

import 'package:riverpod_graph/riverpod_graph.dart';

void main(List<String> args) async {
  final targetDir = args.isNotEmpty ? Directory(args[0]) : Directory('lib');
  if (!targetDir.existsSync()) {
    print('Directory ${targetDir.path} does not exist.');
    exit(1);
  }

  final analyzer = RiverpodGraphAnalyzer();
  await analyzer.analyzeDirectory(targetDir);

  final mermaid = analyzer.generateMermaid();
  analyzer.printTraceability();

  final html = analyzer.generateHtml(mermaid);
  analyzer.saveHtml(html, 'riverpod_graph.html');

  print('\n✅ Graph saved to riverpod_graph.html');
}

