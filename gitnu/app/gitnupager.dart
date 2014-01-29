library GitnuPager;

import 'dart:html';
import 'dart:async';

import 'constants.dart';

/**
 * Displays paged output from a command. Output is retrieved on demand as the user
 * pages through it.
 */
class GitnuPager {
  OutputElement _pagerOutput;
  DivElement _pagerContainer;
  DivElement _container;

  StreamSubscription _keyPressSubscription;
  StreamSubscription _scrollSubscription;

  OutputGenerator _outputGenerator;
  Completer _completer;

  GitnuPager(String title, this._outputGenerator) {
    _container = document.querySelector(kContainer);
    _pagerOutput = document.querySelector(kPagerOutput);
    _pagerContainer = document.querySelector(kPagerContainer);

    int bodyHeight = window.innerHeight;
    _pagerContainer.style.maxHeight = "${bodyHeight - kTopMargin}px";
    _pagerContainer.style.height = "${bodyHeight - kTopMargin}px";

    _showWindow(title);
  }

  /**
   * Returns true if the screen is covered.
   */
  bool _filled() => _pagerOutput.clientHeight > window.innerHeight;

  /**
   * Shows the window and sets up the scrolling and movement events.
   */
  void _showWindow(String title) {
    _pagerContainer.style.display = "block";
    _container.style.display = "none";
    _keyPressSubscription = window.onKeyDown.listen(_windowMove);

    _completer = new Completer();

    _print("<p>$title</p>");
    _print("<p>Press 'q' to close window, pg-up/pg-down to navigate.</p><br>");
  }

  /**
   * Remove subscriptions, empty the page and hide the page.
   */
  void _closeWindow() {
    _container.style.display = "block";
    _pagerOutput.innerHtml = "";
    _pagerContainer.style.display = "none";
    _keyPressSubscription.cancel();
    if (_scrollSubscription != null)
      _scrollSubscription.cancel();
    _completer.complete();
  }

  /**
   * Print to the pager window.
   */
  void _print(String line) {
    _pagerOutput.insertAdjacentHtml('beforeEnd', line);
  }

  /**
   * Runs the pager after setup. Printing will be begin.
   */
  Future run() {
    _fillScreen().then((_) {
      _scrollSubscription = _pagerContainer.onScroll.listen(_scrollAppend);
    });
    return _completer.future;
  }

  /**
   * Recursively calls getNext on the output generator and prints to screen
   * until the screen is full.
   */
  Future _fillScreen() {
    if (_filled())
      return new Future.value();
    return _outputGenerator.getNext().then((String content) {
      if (content == null)
        return;
      _print(content);
      _fillScreen();
    });
  }

  /**
   * Handles appending content onScroll.
   */
  void _scrollAppend(Event event) {
    int diffHeight = _pagerContainer.offsetHeight;
    int scrollHeight = _pagerContainer.scrollHeight;
    int offsetHeight = _pagerContainer.scrollTop;

    if (scrollHeight - offsetHeight < diffHeight) {
      _outputGenerator.getNext().then((String content) {
        if (content == null) {
          _scrollSubscription.cancel();
          return;
        }
        _print(content);
      }, onError: (e) => _scrollSubscription.cancel());
    }
  }

  /**
   * Handles scrolling in the popover window.
   */
  void _windowMove(KeyboardEvent event) {
    bool handled = true;
    switch (event.keyCode) {
      case Q_KEY:
        _closeWindow();
        break;
      case PG_UP_KEY:
        _pagerContainer.scrollByLines(-1);
        break;
      case PG_DOWN_KEY:
        _pagerContainer.scrollByLines(1);
        break;
      case END_KEY:
        _pagerOutput.scrollIntoView(ScrollAlignment.BOTTOM);
        break;
      case HOME_KEY:
        _pagerOutput.scrollIntoView(ScrollAlignment.TOP);
        break;
      default:
        handled = false;
        break;
    }
    if (handled)
      event.preventDefault();
  }
}

/**
 * Class template for an output generator to be provided when setting up a
 * pager. This output generator will take repeated calls to getNext to
 * populate the page as necessary.
 */
abstract class OutputGenerator {
  /**
   * getNext is called by the pager to populate the page as necessary.
   * Returns null to indicate no more items to output.
   */
  Future<String> getNext();
}