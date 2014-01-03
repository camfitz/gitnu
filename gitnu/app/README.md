gitnu
=====

Git interactive terminal not unix. A Git terminal in a Chrome App.

Design
====

gitnu.dart
===
Pulls the other classes together and runs the app.

gitnufilesystem.dart
===
Allows terminal functions in the form of file operations.

gitnuoutput.dart
===
An instance of this class is created with a very basic output function from
GitnuTerminal and is then passed to each of the classes handling terminal 
functions to allow outputting to the terminal.

gitnuterminal.dart
===
Displays and operates the terminal itself. Handles command line input and calls
relevant functions.

gitwrapper.dart
===
Linking the Git library being developed in Spark (/ independently) with Gitnu.

statictoolkit.dart
===
Some basic operations needed across the implementation.