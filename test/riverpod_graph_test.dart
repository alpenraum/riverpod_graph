import 'package:riverpod_graph/riverpod_graph.dart';
import 'package:test/test.dart';
import 'dart:io';

void main() {
  late RiverpodGraphAnalyzer analyzer;

  setUp(() {
    analyzer = RiverpodGraphAnalyzer();
  });

  test('detects simple provider dependency', () async {
    final tempDir = Directory.systemTemp.createTempSync('riverpod_test_');

    // Create a dummy pubspec.yaml so analyzer doesn't bail
    File('${tempDir.path}/pubspec.yaml').writeAsStringSync('name: temp_project\n');

    final file = File('${tempDir.path}/lib/main.dart');
    file.createSync(recursive: true);
    file.writeAsStringSync('''
import 'package:flutter_riverpod/flutter_riverpod.dart';

final barProvider = Provider((ref) => 42);

final fooProvider = Provider((ref) {
  return ref.watch(barProvider);
});
''');

    await analyzer.analyzeDirectory(tempDir);
    final mermaid = analyzer.generateMermaid();
    print(mermaid);

    expect(mermaid.contains('fooProvider --> barProvider'), isTrue);

    tempDir.deleteSync(recursive: true);
  });

  test('detects .notifier usage in ref.watch', () async {
    final tempDir = Directory.systemTemp.createTempSync('riverpod_test_');
    File('${tempDir.path}/pubspec.yaml').writeAsStringSync('name: temp_project\n');

    final file = File('${tempDir.path}/lib/example.dart');
    file.createSync(recursive: true);
    file.writeAsStringSync('''
import 'package:flutter_riverpod/flutter_riverpod.dart';

final counterProvider = StateNotifierProvider<Counter, int>((ref) => Counter());

class Counter extends StateNotifier<int> {
  Counter() : super(0);
}

final uiProvider = Provider((ref) {
  return ref.watch(counterProvider.notifier);
});
''');

    await analyzer.analyzeDirectory(tempDir);
    final mermaid = analyzer.generateMermaid();
    print(mermaid);

    expect(mermaid.contains('uiProvider --> counterProvider'), isTrue);

    tempDir.deleteSync(recursive: true);
  });

  test('includes line numbers and file path in traceability', () async {
    final tempDir = Directory.systemTemp.createTempSync('riverpod_test_');
    File('${tempDir.path}/pubspec.yaml').writeAsStringSync('name: temp_project\n');

    final file = File('${tempDir.path}/lib/test_file.dart');
    file.createSync(recursive: true);
    file.writeAsStringSync('''
import 'package:flutter_riverpod/flutter_riverpod.dart';

final oneProvider = Provider((ref) => 1);
final twoProvider = Provider((ref) => ref.watch(oneProvider));
''');

    await analyzer.analyzeDirectory(tempDir);

    final output = analyzer.generateMermaid();
    expect(output, contains('twoProvider --> oneProvider'));

    final edges = analyzer.edges; // Make this public in your class
    expect(edges.length, 1);
    expect(edges.first.file, file.path);
    expect(edges.first.line, greaterThan(0));

    tempDir.deleteSync(recursive: true);
  });
}
