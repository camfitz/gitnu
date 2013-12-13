// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This is a port of "Exploring the FileSystem APIs" to Dart.
// See: http://www.html5rocks.com/en/tutorials/file/filesystem/

library terminal_filesystem;
import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'package:chrome_gen/chrome_app.dart' as chrome;
part 'terminal.dart';
part '../../gitnuterminal.dart';

class TerminalFilesystem {
  //@camfitz mod to hold GitnuTerminal class
  GitnuTerminal term;

  void run() {
    //@camfitz mod to hold GitnuTerminal class
    term = new GitnuTerminal('#input-line', '#output', '#cmdline', '#container');
    term.initializeFilesystem(false, 1024 * 1024);

    //@camfitz no need for a theme
    //if (!window.location.hash.isEmpty) {
    //  var theme = window.location.hash.substring(1, window.location.hash.length).split('=')[1];
    //  term.setTheme(theme);
    //} else if (window.localStorage.containsKey('theme')) {
    //  term.setTheme(window.localStorage['theme']);
    //}

    // Setup the DnD listeners for file drop.
    var body = document.body;
    body.onDragEnter.listen(onDragEnter);
    body.onDragOver.listen(onDragOver);
    body.onDrop.listen(onDrop);
  }

  void onDragEnter(MouseEvent event) {
    event.stopPropagation();
    event.preventDefault();
    Element dropTarget = event.target;
    dropTarget.classes.add('dropping');
  }

  void onDragOver(MouseEvent event) {
    event.stopPropagation();
    event.preventDefault();

    // Explicitly show this is a copy.
    event.dataTransfer.dropEffect = 'copy';
  }

  void onDrop(MouseEvent event) {
    event.stopPropagation();
    event.preventDefault();
    Element dropTarget = event.target;
    dropTarget.classes.remove('dropping');
    term.addDroppedFiles(event.dataTransfer.files);
    term.writeOutput('<div>File(s) added!</div>');
  }
}

// main() now controlled from gitnu.dart
//void main() {
//  new TerminalFilesystem().run();
//}