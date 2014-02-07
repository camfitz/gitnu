import 'package:unittest/unittest.dart';
import 'package:unittest/vm_config.dart';

import 'dart:async';

import '../app/gitnutabcompleter.dart';

/**
 * Setup the tests.
 * TODO (camfitz): Centralise the test runner for multiple test classes.
 */
void main() {
  useVMConfiguration();
  GitnuTerminalTest.run();
}

/**
 * Tests for the GitnuTerminal class.
 */
class GitnuTerminalTest {
  GitnuTerminalTest();

  static void run() {
    testTabCompleter();
  }

  /**
   * Tests for tabCompleter() function.
   */
  static void testTabCompleter() {

    Map<String, Function> testMap = {
        'test': (List<String> args) => null,
        'test1': (List<String> args) => new Future.value(['a', 'b']),
        'test2': (List<String> args) => new Future.value(['ce', 'cd']),
        'test3': (List<String> args) => new Future.value([]),
        'unique': (List<String> args) => new Future.value(['a', 'b', 'c'])
    };

    group('testTabCompleterWithSetup', () {
      test('emptyInput', () {
        return GitnuTabCompleter.tabCompleter("", testMap, testMap).then(
            (Completion completion) {
          expect(completion.last, equals(''));
          expect(completion.options, orderedEquals(testMap.keys.toList()));
        });
      });

      test('incompleteQuotation', () {
        return GitnuTabCompleter.tabCompleter("blah'", testMap, testMap).then(
            (Completion completion) {
          expect(completion, isNull);
        });
      });

      test('partialInput', () {
        return GitnuTabCompleter.tabCompleter("t", testMap, testMap).then(
            (Completion completion) {
          expect(completion.last, equals('t'));
          expect(completion.options,
                 orderedEquals(['test', 'test1', 'test2', 'test3']));
        });
      });

      test('fullInputSubstring', () {
        return GitnuTabCompleter.tabCompleter("test", testMap, testMap).then(
            (Completion completion) {
          expect(completion.last, equals('test'));
          expect(completion.options,
              orderedEquals(['test', 'test1', 'test2', 'test3']));
        });
      });

      test('fullInputUnique', () {
        return GitnuTabCompleter.tabCompleter("test2", testMap, testMap).then(
            (Completion completion) {
          expect(completion.last, equals('test2'));
          expect(completion.options, orderedEquals(['test2']));
        });
      });

      test('fullInputUniqueNoSubCompleter', () {
        return GitnuTabCompleter.tabCompleter("test3 ", testMap, testMap).then(
            (Completion completion) {
            expect(completion.last, '');
            expect(completion.options, []);
        });
      });

      test('fullInputUniqueSubCompleter', () {
        return GitnuTabCompleter.tabCompleter("test2 ", testMap, testMap).then(
            (Completion completion) {
            expect(completion.last, '');
            expect(completion.options, orderedEquals(['ce', 'cd']));
        });
      });

      test('fullInputUniqueSubCompleterPartial', () {
        return GitnuTabCompleter.tabCompleter("test2 c", testMap, testMap).then(
            (Completion completion) {
            expect(completion.last, 'c');
            expect(completion.options, orderedEquals(['ce', 'cd']));
        });
      });
    });
  }
}
