# gitnu

Git interactive terminal not unix. A Git terminal in a Chrome App.

## Design

### Gitnu `gitnu.dart`
Pulls the other classes together and runs the app.

### GitnuFilesystem `gitnufilesystem.dart`
Allows terminal functions in the form of file operations.

### GitnuOutput `gitnuoutput.dart`
An instance of this class is created with a very basic output function from
GitnuTerminal and is then passed to each of the classes handling terminal 
functions to allow outputting to the terminal.

### GitnuTerminal `gitnuterminal.dart`
Displays and operates the terminal itself. Handles command line input and calls
relevant functions.

### GitWrapper `gitwrapper.dart`
Linking the Git library being developed in Spark (/ independently) with Gitnu.

### StaticToolkit `statictoolkit.dart`
Some basic operations needed across the implementation.

## Dependencies

This app currently depends on Spark for its Git library, although there are 
plans to move the Spark Git library into its own Repo.