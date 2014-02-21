library AuthPrompt;

import 'dart:html';
import 'dart:async';

import 'constants.dart';

/**
 * Displays authentication fields to collect a username and password.
 */
class AuthPrompt {
  InputElement _username;
  InputElement _password;
  InputElement _authButton;
  DivElement _passwordContainer;
  DivElement _passwordTitle;

  StreamSubscription _keyPressSubscription;
  StreamSubscription _buttonClickSubscription;

  Completer _completer;

  AuthPrompt(String title) {
    _username = document.querySelector(kUsername);
    _password = document.querySelector(kPassword);
    _username.value = "";
    _password.value = "";
    _authButton = document.querySelector(kAuthButton);
    _passwordContainer = document.querySelector(kPasswordContainer);
    _passwordTitle = document.querySelector(kPasswordTitle);

    _showWindow(title);
  }

  void _showWindow(String title) {
    _passwordContainer.style.display = "block";
    _keyPressSubscription = window.onKeyDown.listen(_windowClose);
    _buttonClickSubscription = _authButton.onClick.listen(_completeAuth);

    _completer = new Completer();

    _passwordTitle.innerHtml = """
        <p>$title</p>
        <p>Press 'q' to close window, pg-up/pg-down to navigate.</p>""";
  }

  void _completeAuth(Event event) {
    _closeWindow(new AuthDetails(_username.value, _password.value));
  }

  /**
   * Remove subscriptions, empty the page and hide the page.
   */
  void _closeWindow(AuthDetails output) {
    _username.value = "";
    _password.value = "";
    _passwordTitle.innerHtml = "";
    _passwordContainer.style.display = "none";
    _keyPressSubscription.cancel();
    _buttonClickSubscription.cancel();
    _completer.complete(output);
  }

  Future<AuthDetails> run() {
    return _completer.future;
  }

  void _windowClose(KeyboardEvent event) {
    if (event.keyCode == Q_KEY) {
      _closeWindow(null);
      event.preventDefault();
    }
  }
}

/**
 * Container for AuthDetails return object, holds [username] and [password]
 * strings.
 */
class AuthDetails {
  String username;
  String password;
  AuthDetails(this.username, this.password);
}