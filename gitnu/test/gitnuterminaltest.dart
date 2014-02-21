import 'package:unittest/unittest.dart';
import 'package:unittest/html_config.dart';

import 'dart:async';

import '../app/constants.dart';
import '../app/gitnutabcompleter.dart';
import '../app/gitnuterminal.dart';

/**
 * Setup the tests.
 * TODO (camfitz): Centralise the test runner for multiple test classes.
 */
void main() {
  useHtmlConfiguration();
  GitnuTerminalTest.run();
}

/**
 * Tests for the GitnuTerminal class.
 */
class GitnuTerminalTest {
  GitnuTerminalTest();

  static void run() {
    shortcutKeyTests();
    testTabCompleter();
  }

  /**
   * Tests for GitnuTerminal shortcut keys
   */
  static void shortcutKeyTests() {
    GitnuTerminal terminal;

    void simulateCtrlShortcut(int keyCode) {
      terminal.keyboardHandler.keyDownAction(CTRL_KEY);
      terminal.keyboardHandler.keyDownAction(keyCode);
      terminal.keyboardHandler.keyUpAction(CTRL_KEY);
      terminal.keyboardHandler.keyUpAction(keyCode);
    }

    group('testCtrlW', () {
      setUp(() {
        terminal = new GitnuTerminal(new GitnuTerminalView.mock());
      });

      test('twoWords', () {
        terminal.view.input.value = 'one two';
        simulateCtrlShortcut(W_KEY);
        expect(terminal.view.input.value, equals('one '));
      });

      test('trailingWhitespace', () {
        terminal.view.input.value = 'one two    ';
        simulateCtrlShortcut(W_KEY);
        expect(terminal.view.input.value, equals('one '));
      });

      test('oneWord', () {
        terminal.view.input.value = 'one';
        simulateCtrlShortcut(W_KEY);
        expect(terminal.view.input.value, equals(''));
      });
    });

    group('testCtrlWCtrlY', () {
      setUp(() {
        terminal = new GitnuTerminal(new GitnuTerminalView.mock());
        terminal.view.input.value = 'one two  ';
      });

      test('restoreWord', () {
        simulateCtrlShortcut(W_KEY);
        expect(terminal.view.input.value, equals('one '));
        simulateCtrlShortcut(Y_KEY);
        expect(terminal.view.input.value, equals('one two  '));
      });

      test('doubleRestoreWord', () {
        simulateCtrlShortcut(W_KEY);
        simulateCtrlShortcut(Y_KEY);
        simulateCtrlShortcut(Y_KEY);
        expect(terminal.view.input.value, equals('one two  two  '));
      });

      test('removeWordsAndRestore', () {
        simulateCtrlShortcut(W_KEY);
        simulateCtrlShortcut(W_KEY);
        expect(terminal.view.input.value, equals(''));
        simulateCtrlShortcut(Y_KEY);
        expect(terminal.view.input.value, equals('one two  '));
      });
    });
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
