import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:riverpod_graph/provider_edge.dart';
import 'package:riverpod_graph/util/html_template.dart';

class RiverpodGraphAnalyzer {
  final bool _printLogs;

  RiverpodGraphAnalyzer(this._printLogs);

  final _actors = <String>{};

  final edges = <ProviderEdge>[];

  Future<void> analyzeDirectory(Directory dir) async {
    final dartFiles = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      if (_printLogs) {
        print('Analyzing file: ${file.path}');
      }
      final content = await file.readAsString();
      if (_printLogs) {
        print('Content of ${file.path}: \n$content'); // Log content for debug
      }

      final result = parseString(content: content, path: file.path);
      final unit = result.unit;
      final lineInfo = result.lineInfo;
      final visitor =
        _Visitor(file.path, _actors, edges, lineInfo, _printLogs);
      unit.visitChildren(visitor);

      if (_printLogs) {
        print('Finished analyzing file: ${file.path}');
      }
    }
  }

  String generateMermaid() {
    final nodes = _actors.map((name) => {
      'data': {'id': name, 'label': name}
    });

    final edges = this.edges.map((edge) => {
      'data': {
        'source': edge.from,
        'target': edge.to,
        'label': edge.type.name, // e.g. "watch", "read"
        'trace': "${edge.file}:${edge.line}"
      },
      'classes': edge.type.name.toLowerCase(),
    });

    final elements = [...nodes, ...edges];
    final jsonGraph = jsonEncode(elements);

    return jsonGraph;
  }

  String generateHtml(String mermaidGraph) {
    final template = getHtmlTemplate();
    return template.replaceAll('{{graph}}', mermaidGraph);
  }

  void saveHtml(String content, String outputPath) {
    File(outputPath).writeAsStringSync(content);
  }
}

class _Visitor extends RecursiveAstVisitor<void> {
  final String _file;
  final Set<String> _actors;
  final List<ProviderEdge> _edges;
  final bool _printLogs;

  final LineInfo _lineInfo;

  _Visitor(
      this._file, this._actors, this._edges, this._lineInfo, this._printLogs);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    super.visitSimpleIdentifier(node);

    // Log when we encounter a potential provider or reference
    if (node.name.endsWith('Provider')) {
      if (_printLogs) {
        print('Found potential provider: ${node.name} in $_file');
      }
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    final method = node.methodName.name;
    if (!['watch', 'read', 'listen'].contains(method)) return;

    // The provider being watched is the first argument
    if (node.argumentList.arguments.isNotEmpty) {
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
        _actors.add(targetProvider);
        if (_printLogs) {
          print('Found ref.watch on: ${targetProvider.toString()} in $_file');
        }

        final type = switch (method) {
          'read' => RefAccessType.read,
          'listen' => RefAccessType.listen,
          _ => RefAccessType.watch
        };

        // Now we need to identify the provider that is invoking the 'ref.watch()'
        // This will be the provider in the scope of the node
        final currentActor = _findCurrentActor(node);

        if (currentActor != null) {
            _actors.add(currentActor);
          // Add an edge from the current provider to the watched provider
          _edges.add(ProviderEdge(
              currentActor, // This is the provider that contains ref.watch()
              targetProvider, // The provider being watched
              _file,
              _lineInfo.getLocation(node.offset).lineNumber,
              type));
        }
      }
    }
  }

  String? _findCurrentActor(AstNode? node) {
    if (node == null) return null;

    if (node is VariableDeclaration && node.name.lexeme.endsWith('Provider')) {
      return node.name.lexeme;
    }

    if (node is ClassDeclaration) {
      return node.name.lexeme;
    }

    if (node is FunctionDeclaration) {
      return node.name.lexeme;
    }

    return _findCurrentActor(node.parent);
  }

}
