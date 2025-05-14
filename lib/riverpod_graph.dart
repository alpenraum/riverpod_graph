import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_graph/provider_edge.dart';

class RiverpodGraphAnalyzer {
  final _providers = <String, String>{}; // name -> file

  final edges = <ProviderEdge>[];

  Future<void> analyzeDirectory(Directory dir) async {
    final dartFiles = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      print('Analyzing file: ${file.path}');
      final content = await file.readAsString();
      print('Content of ${file.path}: \n$content'); // Log content for debug

      final result = parseString(content: content, path: file.path);
      final unit = result.unit;
      final lineInfo = result.lineInfo;
      final visitor = _Visitor(file.path, _providers, edges, lineInfo);
      unit.visitChildren(visitor);

      print('Finished analyzing file: ${file.path}');
    }
  }

  String generateMermaid() {
    final buffer = StringBuffer();
    buffer.writeln('graph TD');
    for (final edge in edges) {
      final from = edge.from;
      final to = edge.to;
      final label = '${edge.file}:${edge.line}';

      final arrow = switch (edge.type) {
        RefAccessType.watch => '-->',
        RefAccessType.read => '-.->',
        RefAccessType.listen => '==>',
      };

      buffer.writeln('  $from $arrow $to["$to\\n($label)"]:::${edge.type.name}');
      buffer.writeln('  classDef ${edge.type.name} fill:#f9f,stroke:#333,stroke-width:1px;');
    }
    return buffer.toString();
  }

  String generateHtml(String mermaidGraph) {
    final template = File('templates/graph_template.html').readAsStringSync();
    return template.replaceAll('<!--MERMAID_GRAPH-->', mermaidGraph);
  }

  void saveHtml(String content, String outputPath) {
    File(outputPath).writeAsStringSync(content);
  }

  void printTraceability() {
    for (final edge in edges) {
      print('${edge.from} --> ${edge.to} '
          '(${p.relative(edge.file)}:${edge.line})');
    }
  }
}

class _Visitor extends RecursiveAstVisitor<void> {
  final String file;
  final Map<String, String> providers;
  final List<ProviderEdge> edges;

  final LineInfo _lineInfo;

  _Visitor(this.file, this.providers, this.edges, this._lineInfo);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    super.visitSimpleIdentifier(node);

    // Log when we encounter a potential provider or reference
    if (node.name.endsWith('Provider')) {
      print('Found potential provider: ${node.name} in $file');
    }
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final name = node.name.toString();
    final parent = node.parent;
    if (parent is VariableDeclarationList) {
      final type = parent.type?.toString() ?? '';
      if (_isRiverpodProvider(type)) {
        providers[name] = file;
      }
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    final method = node.methodName.name;
    if (!['watch', 'read', 'listen'].contains(method)) return;

    // The provider being watched is the first argument
    final providerArgument = node.argumentList.arguments.first;

    String? targetProvider;

    if (providerArgument is SimpleIdentifier) {
      // case: ref.watch(fooProvider)
      targetProvider = providerArgument.name;
    } else if (providerArgument is PrefixedIdentifier) {
      // Case: ref.watch(counterProvider.notifier)
      targetProvider = providerArgument.prefix.name;
    } else if (providerArgument is PropertyAccess) {
      // Case: ref.watch(object.property)
      final target = providerArgument.target;
      if (target is SimpleIdentifier) {
        targetProvider = target.name;
      }
    }

    if (targetProvider != null) {
      // Log to confirm we found the provider being watched
      print('Found ref.watch on: ${targetProvider.toString()} in $file');

      final type = switch (method) {
        'read' => RefAccessType.read,
        'listen' => RefAccessType.listen,
        _ => RefAccessType.watch
      };

      // Now we need to identify the provider that is invoking the 'ref.watch()'
      // This will be the provider in the scope of the node
      final currentProvider = _findCurrentProvider(node);

      if (currentProvider != null) {
        // Add an edge from the current provider to the watched provider
        edges.add(ProviderEdge(
          currentProvider, // This is the provider that contains ref.watch()
          targetProvider, // The provider being watched
          file,
          _lineInfo.getLocation(node.offset).lineNumber,
          type
        ));
      }
    }
  }

  String? _findCurrentProvider(MethodInvocation node) {
    var parent = node.parent;

    // Traverse the parent chain to find the provider name (i.e., `fooProvider`)
    while (parent != null) {
      if (parent is VariableDeclaration) {
        // Check if this variable is a provider (ends with 'Provider')
        if (parent.name.lexeme.endsWith('Provider')) {
          return parent.name
              .lexeme; // This is the provider declaring the ref.watch() method
        }
      }
      parent = parent.parent;
    }
    return null;
  }

  bool _isRiverpodProvider(String type) {
    final base = type.replaceAll(RegExp(r'<.*>'), '');
    return [
      'Provider',
      'StateProvider',
      'FutureProvider',
      'StreamProvider',
      'StateNotifierProvider',
      'NotifierProvider',
      'ProviderFamily',
      'AutoDisposeProvider',
    ].any((prefix) => base.contains(prefix));
  }
}
