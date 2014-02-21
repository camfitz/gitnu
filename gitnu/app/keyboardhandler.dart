import 'dart:html';

import 'constants.dart';

/**
 * A generic window element KeyboardHandler for the terminal client. Two key
 * handlers will maintain a list with the currently pressed or not pressed keys.
 * Event listeners can then respond to multiple key presses simultaneously.
 */
class KeyboardHandler {
  List<int> _keys = new List<int>();
  Map<int, Function> _ctrlPlusKeyActions = new Map<int, Function>();
  Map<int, Function> _singleKeyActions = new Map<int, Function>();

  KeyboardHandler() {
    window.onKeyDown.listen((KeyboardEvent e) {
      if (_keys.contains(CTRL_KEY))
        e.preventDefault();
      keyDownAction(e.keyCode);
    });
    window.onKeyUp.listen((KeyboardEvent e) => keyUpAction(e.keyCode));
  }

  void keyDownAction(int keyCode) {
    if (!_keys.contains(keyCode))
      _keys.add(keyCode);

    if (_keys.contains(CTRL_KEY)) {
      for (int key in _keys) {
        if (_ctrlPlusKeyActions.containsKey(key))
          _ctrlPlusKeyActions[key](key);
      }
    } else {
      for (int key in _keys) {
        if (_singleKeyActions.containsKey(key))
          _singleKeyActions[key](key);
      }
    }
  }

  void keyUpAction(int keyCode) {
    _keys.remove(keyCode);
  }

  bool isPressed(int keyCode) => _keys.contains(keyCode);

  void registerShortcut(Function action, int keyCode, [bool controlKey]) {
    if (controlKey != null && controlKey)
      _ctrlPlusKeyActions[keyCode] = action;
    else
      _singleKeyActions[keyCode] = action;
  }

  void removeShortcut(int keyCode, [bool controlKey]) {
    if (controlKey != null && controlKey)
      _ctrlPlusKeyActions.remove(keyCode);
    else
      _singleKeyActions.remove(keyCode);
  }
}