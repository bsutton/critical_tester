#! /usr/bin/env dcli

import 'dart:io';

import 'package:dcli/dcli.dart';

import 'process_output.dart';
import 'util/counts.dart';

late bool _show;
late String _logPath =
    join(Directory.systemTemp.path, 'critical_test', 'unit_tests.log');

late String hookPath =
    join(DartProject.current.pathToProjectRoot, 'tool', 'critical_test_hook');
late String prehookPath = join(hookPath, 'pre_test_hook');
late String posthookPath = join(hookPath, 'post_test_hook');

/// returns true if all tests passed.
void runTests(
    {required String pathToProjectRoot,
    String? logPath,
    bool show = false,
    required String? tags,
    required String? excludeTags,
    required bool coverage,
    required bool showProgress,
    required Counts counts}) {
  if (logPath != null) {
    _logPath = logPath;
  }
  _show = show;

  clearFailedTracker();

  print(green(
      'Running unit tests for ${DartProject.fromPath(pwd).pubSpec.name}'));
  print('Logging all output to $_logPath');

  if (showProgress) {
    // ignore: missing_whitespace_between_adjacent_strings
    print('Legend: ${green('Success')}:${red('Errors')}:${blue('Skipped')}');
  }

  prepareLog();
  runPreHooks();

  _runAllTests(
      counts: counts,
      pathToPackageRoot: pathToProjectRoot,
      tags: tags,
      excludeTags: excludeTags,
      coverage: coverage,
      showProgress: showProgress);

  print('');

  runPostHooks();
}

/// Find and run each unit test file.
/// Returns true if all tests passed.
void _runAllTests(
    {required Counts counts,
    required String pathToPackageRoot,
    required String? tags,
    required String? excludeTags,
    required bool coverage,
    required bool showProgress}) {
  final pathToTestRoot = join(pathToPackageRoot, 'test');

  find('*_test.dart', workingDirectory: pathToTestRoot).forEach((testScript) {
    runTest(
        counts: counts,
        testScript: testScript,
        pathToPackageRoot: pathToPackageRoot,
        show: _show,
        logPath: _logPath,
        tags: tags,
        excludeTags: excludeTags,
        coverage: coverage,
        showProgress: showProgress);
  });
}

/// returns true if the test passed.
void runSingleTest({
  required Counts counts,
  required String testScript,
  required String pathToProjectRoot,
  String? logPath,
  bool show = false,
  String? tags,
  String? excludeTags,
  required bool coverage,
  required bool showProgress,
}) {
  if (logPath != null) {
    _logPath = logPath;
  }
  _show = show;

  print('Logging all output to $_logPath');

  if (showProgress) {
    // ignore: missing_whitespace_between_adjacent_strings
    print('Legend: ${green('Success')}:${red('Errors')}:${blue('Skipped')}');
  }
  prepareLog();
  runPreHooks();

  runTest(
      counts: counts,
      testScript: testScript,
      pathToPackageRoot: pathToProjectRoot,
      show: _show,
      logPath: _logPath,
      tags: tags,
      excludeTags: excludeTags,
      coverage: coverage,
      showProgress: showProgress);

  print('');

  runPostHooks();
}

/// returns true if all tests passed.
void runFailedTests({
  required Counts counts,
  required String pathToProjectRoot,
  String? logPath,
  bool show = false,
  String? tags,
  String? excludeTags,
  required bool coverage,
  required bool showProgress,
}) {
  if (logPath != null) {
    _logPath = logPath;
  }
  _show = show;

  print('Logging all output to $_logPath');

  if (showProgress) {
    // ignore: missing_whitespace_between_adjacent_strings
    print('Legend: ${green('Success')}:${red('Errors')}:${blue('Skipped')}');
  }

  final failedTests = read(pathToFailedTracker).toList();

  clearFailedTracker();

  prepareLog();
  runPreHooks();

  for (final failedTest in failedTests) {
    runTest(
        counts: counts,
        testScript: failedTest,
        pathToPackageRoot: pathToProjectRoot,
        show: _show,
        logPath: _logPath,
        tags: tags,
        excludeTags: excludeTags,
        coverage: coverage,
        showProgress: showProgress);
  }

  print('');

  runPostHooks();
}

void runPreHooks() => runHooks(prehookPath, 'pre-hook');
void runPostHooks() => runHooks(posthookPath, 'post-hook');

void runHooks(String pathTo, String type) {
  if (exists(prehookPath)) {
    var hooks = find('*', workingDirectory: pathTo, recursive: false).toList();
    hooks.sort((lhs, rhs) => lhs.compareTo(rhs));

    for (var file in hooks) {
      if (isFile(file)) {
        if (_isIgnoredFile(file)) return;
        if (isExecutable(file)) {
          print('Running $type $file');
          file.run;
        } else {
          Settings().verbose('Skipping non-executable $type $file');
        }
      } else {
        Settings().verbose('Ignoring non-file $type $file');
      }
    }
  }
}

const _ignoredExtensions = ['.yaml', '.ini', '.config'];
bool _isIgnoredFile(String pathToHook) {
  final _extension = extension(pathToHook);

  return _ignoredExtensions.contains(_extension);
}

void prepareLog() {
  if (!exists(dirname(_logPath))) {
    createDir(dirname(_logPath), recursive: true);
  }
  _logPath.truncate();
}
