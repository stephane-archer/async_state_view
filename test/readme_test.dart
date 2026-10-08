import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:async_state_view/async_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'readme/scan_controller.dart';
import 'readme/scan_select.dart';
import 'readme/scan_switch.dart';
import 'readme/scan_view.dart';
import 'readme/user_page.dart';
import 'readme/user_refresh.dart';

/// A scanner whose runs the test drives through their stream controllers.
class FakeScanner implements Scanner {
  final runs = <StreamController<Totals>>[];

  @override
  Stream<Totals> scan() {
    final run = StreamController<Totals>();
    runs.add(run);
    return run.stream;
  }
}

/// A repository whose fetches the test completes.
class FakeUserRepository implements UserRepository {
  final fetches = <Completer<User>>[];

  @override
  Future<User> fetchCurrentUser() {
    final fetch = Completer<User>();
    fetches.add(fetch);
    return fetch.future;
  }
}

/// Lets pending stream events reach their listeners.
Future<void> flushEvents() => Future<void>.delayed(Duration.zero);

/// Delivers pending stream events and Future completions in a widget test,
/// then builds the frame they schedule.
///
/// A single pump builds a frame only if one was scheduled before it, such as
/// by an animation, so it would miss the rebuild that these events schedule.
Future<void> pumpEvents(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// Records what [select] returns each time a widget below a provider of
/// [controller] builds.
Future<List<R>> recordBuilds<R>(
  WidgetTester tester,
  ScanController controller,
  R Function(BuildContext context) select,
) async {
  final builds = <R>[];
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: Builder(
        builder: (context) {
          builds.add(select(context));
          return const SizedBox();
        },
      ),
    ),
  );
  return builds;
}

/// Reads the lines of [path] with `\n` line endings, which a Windows checkout
/// may replace with `\r\n`.
List<String> readLines(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n').split('\n');

/// A Dart block of the README.
class ReadmeBlock {
  const ReadmeBlock(this.line, this.excerpt, this.lines);

  /// The README line number of the block's first line of code.
  final int line;

  /// The fixture region that the comment before the block names, such as
  /// `test/readme/user_page.dart#user-page` for
  /// `<!-- excerpt: test/readme/user_page.dart#user-page -->`.
  final String? excerpt;

  /// The code, without the indentation of its fence, such as in a list item.
  final List<String> lines;
}

/// README Dart blocks that show no fixture region, because they only show the
/// package's import.
const uncheckedReadmeBlocks = [
  "import 'package:async_state_view/async_state_view.dart';",
];

/// The Dart blocks of the README.
///
/// A block is fenced by three or more backticks or tildes, and its language is
/// the first word after the opening fence, in any case. Finding every such
/// block keeps a block that names no excerpt from going unchecked.
List<ReadmeBlock> readmeBlocks() {
  final fence = RegExp(r'^( *)(`{3,}|~{3,})(.*)$');
  final excerptComment = RegExp(r'^\s*<!-- excerpt: ([^\s#]+#[^\s#]+) -->$');
  final lines = readLines('README.md');
  final blocks = <ReadmeBlock>[];
  for (var i = 0; i < lines.length; i++) {
    final opening = fence.firstMatch(lines[i]);
    if (opening == null) continue;
    final comment = i > 0 ? excerptComment.firstMatch(lines[i - 1]) : null;
    final indentation = RegExp('^ {0,${opening[1]!.length}}');
    final marker = opening[2]!;
    final language = opening[3]!.trim().split(' ').first.toLowerCase();
    final firstLine = i + 2;
    final code = <String>[];
    // The closing fence repeats the opening character at least as many times,
    // with nothing after it.
    for (i++; i < lines.length; i++) {
      final closing = fence.firstMatch(lines[i]);
      if (closing != null &&
          closing[2]!.startsWith(marker) &&
          closing[3]!.trim().isEmpty) {
        break;
      }
      code.add(lines[i].replaceFirst(indentation, ''));
    }
    if (language == 'dart') {
      blocks.add(ReadmeBlock(firstLine, comment?[1], code));
    }
  }
  return blocks;
}

/// A line of a fixture region.
class RegionLine {
  const RegionLine(this.text, this.line, {required this.endsPart});

  /// The line without the indentation that its part shares.
  final String text;

  /// The fixture line number.
  final int line;

  /// Whether the line ends a part of the region.
  final bool endsPart;
}

/// The lines between [start] and [end] of a fixture, without the indentation
/// that they share, as a part of a region.
List<RegionLine> regionPart(List<String> lines, int start, int end) {
  final code = lines.sublist(start, end);
  final indent = code
      .where((line) => line.trim().isNotEmpty)
      .map((line) => line.length - line.trimLeft().length)
      .fold(1 << 30, min);
  return [
    for (var i = 0; i < code.length; i++)
      RegionLine(
        code[i].trim().isEmpty ? '' : code[i].substring(indent),
        start + i + 1,
        endsPart: i == code.length - 1,
      ),
  ];
}

/// The regions of the fixture at [path], by name.
///
/// A region holds the lines between `// #region <name>` and `// #endregion`.
/// Reopening it adds a part after a blank line, so that one README block can
/// show code from different places of the fixture, such as a function and a
/// call to it.
Map<String, List<RegionLine>> fixtureRegions(String path) {
  final opening = RegExp(r'^\s*// #region (\S+)$');
  final closing = RegExp(r'^\s*// #endregion$');
  final lines = readLines(path);
  final regions = <String, List<RegionLine>>{};
  String? open;
  var start = 0;
  for (var i = 0; i < lines.length; i++) {
    final name = opening.firstMatch(lines[i])?[1];
    if (name != null) {
      if (open != null) fail('$path:${i + 1} opens #$name inside #$open.');
      open = name;
      start = i + 1;
    } else if (closing.hasMatch(lines[i])) {
      if (open == null) fail('$path:${i + 1} closes no region.');
      final region = regions.putIfAbsent(open, () => []);
      if (region.isNotEmpty) region.add(RegionLine('', start, endsPart: false));
      region.addAll(regionPart(lines, start, i));
      open = null;
    }
  }
  if (open != null) fail('$path does not close #$open.');
  return regions;
}

/// The paths of the fixtures under test/readme.
List<String> fixturePaths() => [
      for (final entity in Directory('test/readme').listSync())
        if (entity is File && entity.path.endsWith('.dart'))
          entity.path.replaceAll(r'\', '/'),
    ]..sort();

/// Checks that [block] shows the fixture region it names, line by line, and
/// that a region holding imports starts its fixture, so that the README shows
/// every import the example needs.
///
/// The last line of a part may end with a comma that the README leaves out,
/// so that a fixture can hold an expression as an argument.
void expectShowsRegion(ReadmeBlock block) {
  final excerpt = block.excerpt;
  if (excerpt == null) {
    fail('README.md:${block.line} names no excerpt. Hold the block in a '
        'region of a fixture under test/readme, and name it in an '
        '"<!-- excerpt: test/readme/<fixture>#<region> -->" line before the '
        'opening fence.');
  }
  final [path, name] = excerpt.split('#');
  final region = fixtureRegions(path)[name];
  if (region == null) fail('$path has no region #$name.');
  if (region.any((line) => line.text.startsWith('import ')) &&
      region.first.line != 2) {
    fail('$path#$name holds imports, so it must start $path.');
  }

  for (var i = 0; i < max(block.lines.length, region.length); i++) {
    final readme = i < block.lines.length ? block.lines[i] : null;
    final fixture = i < region.length ? region[i] : null;
    if (readme != null &&
        fixture != null &&
        (fixture.text == readme ||
            fixture.endsPart && fixture.text == '$readme,')) {
      continue;
    }
    fail('README.md:${block.line + i} differs from $path#$name'
        '${fixture == null ? '' : ' at line ${fixture.line}'}:\n'
        '  README:  ${readme == null ? 'the end of the block' : '"$readme"'}\n'
        '  fixture: '
        '${fixture == null ? 'the end of the region' : '"${fixture.text}"'}');
  }
}

void main() {
  for (final block in readmeBlocks()) {
    if (uncheckedReadmeBlocks.contains(block.lines.join('\n'))) continue;
    test('README.md:${block.line} shows ${block.excerpt ?? 'a region'}', () {
      expectShowsRegion(block);
    });
  }

  test('the README shows every fixture region', () {
    final shown = readmeBlocks().map((block) => block.excerpt).toSet();
    final unshown = [
      for (final path in fixturePaths())
        for (final name in fixtureRegions(path).keys)
          if (!shown.contains('$path#$name')) '$path#$name',
    ];
    expect(
      unshown,
      isEmpty,
      reason: 'Show each of these regions in a README block, or remove it.',
    );
  });

  test('nullableLabel matches a null value that a loading state carries', () {
    expect(nullableLabel(const AsyncLoading.withValue(null)), 'So far: null');
    expect(nullableLabel(const AsyncLoading.withValue(1)), 'So far: 1');
    expect(nullableLabel(const AsyncLoading()), 'Starting…');
  });

  group('ScanController', () {
    late FakeScanner scanner;
    late ScanController controller;

    setUp(() {
      scanner = FakeScanner();
      controller = ScanController(scanner);
    });

    tearDown(() => controller.dispose());

    test('publishes progress as loading and the last value as data', () async {
      controller.startScan();
      expect(controller.scan, const AsyncLoading<Totals>());

      scanner.runs.last
        ..add(const Totals(1))
        ..add(const Totals(2));
      await flushEvents();
      expect(controller.scan, const AsyncLoading.withValue(Totals(2)));

      await scanner.runs.last.close();
      expect(controller.scan, const AsyncData(Totals(2)));
    });

    test('keeps the first error over later events and the end', () async {
      final error = StateError('failed');
      controller.startScan();
      scanner.runs.last
        ..add(const Totals(1))
        ..addError(error)
        ..add(const Totals(2));
      unawaited(scanner.runs.last.close());
      await flushEvents();

      expect(controller.scan, isA<AsyncError<Totals>>());
      expect(controller.scan.hasValue, isFalse);
      expect((controller.scan as AsyncError<Totals>).error, same(error));
    });

    test('publishes empty totals for a scan without events', () async {
      controller.startScan();
      await scanner.runs.last.close();

      expect(controller.scan, const AsyncData(Totals.empty));
    });

    test('ignores the previous run after a restart', () async {
      controller.startScan();
      final previous = scanner.runs.last..add(const Totals(5));
      await flushEvents();

      // The previous run's next event is queued but not yet delivered.
      previous.add(const Totals(6));
      controller.startScan();
      expect(controller.scan, const AsyncLoading<Totals>());

      previous.add(const Totals(7));
      unawaited(previous.close());
      await flushEvents();
      expect(controller.scan, const AsyncLoading<Totals>());

      scanner.runs.last.add(const Totals(1));
      await flushEvents();
      expect(controller.scan, const AsyncLoading.withValue(Totals(1)));
    });

    test('stops listening when disposed', () {
      final disposed = ScanController(scanner)..startScan();
      disposed.dispose();

      expect(scanner.runs.last.hasListener, isFalse);
    });

    test('is labelled by the README switch', () async {
      controller.startScan();
      expect(scanLabel(controller), 'Starting…');

      scanner.runs.last.add(const Totals(1));
      await flushEvents();
      expect(scanLabel(controller), '1 so far…');

      await scanner.runs.last.close();
      expect(scanLabel(controller), '1 in total');

      controller.startScan();
      scanner.runs.last.addError(StateError('failed'));
      await flushEvents();
      expect(scanLabel(controller), 'Failed: Bad state: failed');
    });

    testWidgets('is rendered by the README ScanView', (tester) async {
      controller.startScan();
      await tester.pumpWidget(
        MaterialApp(home: ScanView(controller: controller)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      scanner.runs.last.add(const Totals(1));
      await pumpEvents(tester);
      expect(find.text('1 so far…'), findsOneWidget);

      unawaited(scanner.runs.last.close());
      await pumpEvents(tester);
      expect(find.text('1 in total'), findsOneWidget);
    });

    testWidgets('rebuilds the README found selector when found changes',
        (tester) async {
      controller.startScan();
      final builds = await recordBuilds(tester, controller, scanFound);

      for (final count in [0, 1, 2, 3]) {
        scanner.runs.last.add(Totals(count));
        await pumpEvents(tester);
      }
      unawaited(scanner.runs.last.close());
      await pumpEvents(tester);

      expect(builds, [
        const AsyncLoading<bool>(),
        const AsyncLoading.withValue(false),
        const AsyncLoading.withValue(true),
        const AsyncData(true),
      ]);
    });

    testWidgets(
        'rebuilds the README count selector when the scan starts, ends or '
        'fails', (tester) async {
      controller.startScan();
      final builds = await recordBuilds(tester, controller, scanCount);

      for (final count in [1, 2, 3]) {
        scanner.runs.last.add(Totals(count));
        await pumpEvents(tester);
      }
      unawaited(scanner.runs.last.close());
      await pumpEvents(tester);

      controller.startScan();
      await tester.pump();
      scanner.runs.last
        ..add(const Totals(1))
        ..addError(StateError('failed'));
      await pumpEvents(tester);

      expect(builds, [
        const AsyncLoading<int>(),
        const AsyncData(3),
        const AsyncLoading<int>(),
        isA<AsyncError<int>>(),
      ]);
    });
  });

  group('UserPage', () {
    const page = MaterialApp(home: Scaffold(body: UserPage()));
    late FakeUserRepository repository;

    setUp(() {
      repository = FakeUserRepository();
      userRepository = repository;
    });

    testWidgets('loads the user when it starts', (tester) async {
      await tester.pumpWidget(page);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.fetches.single.complete(const User('Ada'));
      await pumpEvents(tester);
      expect(find.text('Hello, Ada'), findsOneWidget);
    });

    testWidgets('loads the user again on retry', (tester) async {
      await tester.pumpWidget(page);
      repository.fetches.single.completeError(Exception('offline'));
      await pumpEvents(tester);
      expect(
        find.text('Could not load the user: Exception: offline'),
        findsOneWidget,
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.fetches.last.complete(const User('Ada'));
      await pumpEvents(tester);
      expect(find.text('Hello, Ada'), findsOneWidget);
    });

    testWidgets('ignores a load that fails after it is removed',
        (tester) async {
      await tester.pumpWidget(page);
      await tester.pumpWidget(const SizedBox());

      // Calling setState after dispose would throw and fail the test.
      repository.fetches.single.completeError(Exception('offline'));
      await tester.pump();
    });
  });

  group('UserRefreshPage', () {
    late FakeUserRepository repository;

    setUp(() {
      repository = FakeUserRepository();
      userRepository = repository;
    });

    testWidgets('keeps the user through a failed refresh and its retry',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: UserRefreshPage())),
      );
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

      repository.fetches.last.complete(const User('Ada'));
      await pumpEvents(tester);
      expect(find.text('Hello, Ada'), findsNWidgets(2));

      await tester.tap(find.text('Refresh'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Hello, Ada'), findsNWidgets(2));

      repository.fetches.last.completeError(Exception('offline'));
      await pumpEvents(tester);
      // Only the builder with errorWithValue shows the user with the error.
      expect(find.text('Failed: Exception: offline'), findsOneWidget);
      expect(
        find.text('Could not refresh: Exception: offline'),
        findsOneWidget,
      );
      expect(find.text('Hello, Ada'), findsOneWidget);

      await tester.tap(find.text('Refresh'));
      await tester.pump();
      // The retry keeps the user but not the error.
      expect(find.textContaining('offline'), findsNothing);
      expect(find.text('Hello, Ada'), findsNWidgets(2));

      repository.fetches.last.complete(const User('Bob'));
      await pumpEvents(tester);
      expect(find.text('Hello, Bob'), findsNWidgets(2));
    });
  });
}
