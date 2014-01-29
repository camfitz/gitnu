library RootPicker;

import 'dart:html';
import 'dart:async';

import 'package:chrome_gen/chrome_app.dart' as chrome;

import 'constants.dart';
import 'gitnuoutput.dart';

/**
 * Handles the setup and storage of the root directory required by the terminal
 * application. When instantiated RootPicker will check if a root is stored
 * in localstorage, else will pop up a directory chooser.
 * If the change root button is clicked when the program is run RootPicker
 * will store the result and restart the terminal.
 */
class RootPicker {
  Function _onRootChanged;
  GitnuOutput _output;

  RootPicker(this._output, this._onRootChanged) {
    // Check if we set a rootFolder in a previous use of the app.
    chrome.storage.local.get(kRootFolder).then((items) {
      if (items[kRootFolder] == null) {
        forceDirectoryChoice();
      } else {
        chrome.fileSystem.isRestorable(items[kRootFolder]).then((value) {
          if (value)
            chrome.fileSystem.restoreEntry(items[kRootFolder]).then(
                _onRootChanged);
          else
            forceDirectoryChoice();
        });
      }
    });

    InputElement chooseDirButton = document.querySelector(kChooseDirButton);
    chooseDirButton.onClick.listen(chooseRootPrompt);
  }

  void forceDirectoryChoice() {
    _output.printHtml(
        '''Welcome to Gitnu terminal!<br>
           You need to choose a root folder before continuing.<br>
           <a href="#" id="chooseDirLink">
           Click to select root folder.</a><br>''');
    document.querySelector(kChooseDirLink).onClick.listen(chooseRootPrompt);
    // Force directory choice window
    chooseRootPrompt(null);
  }

  /*
   * Shows a folder picker prompt, allowing the user to choose a new root.
   * The entry is retained in chrome.storage.local.
   */
  void chooseRootPrompt(Event e) {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
        type: chrome.ChooseEntryType.OPEN_DIRECTORY);

    chrome.fileSystem.chooseEntry(options).then(
        (chrome.ChooseEntryResult result) {
      DirectoryEntry entry = result.entry;
      // use local storage to retain access to this file
      chrome.storage.local.set(
          {kRootFolder: chrome.fileSystem.retainEntry(entry)});
      _onRootChanged(entry);
    });
  }
}