library StringUtils;

class StringUtils {
  StringUtils();

  /**
   * Parse Command Line Input
   * eg. "ls" "chips and stew"taters stuff
   * => [ls, chips and stewtaters, stuff]
   */
  static List<String> parseCommandLine(String commandLine) {
    commandLine = commandLine.trim();
    if (commandLine.endsWith('\\'))
      return null;

    bool isQuote(String c) {
      return c == '"' || c == "'";
    }

    bool inside = false;
    String currentQuote = '\0';
    String currentArg = "";
    bool wordFormed = false;
    bool escape = false;
    List<String> result = [];
    for (int i = 0; i < commandLine.length; i++) {
      if (commandLine[i] == '\\') {
        if (inside && commandLine[i + 1] == currentQuote) {
          if (currentQuote == '"')
            escape = true;
          else
            return null;
        } else if (!inside && isQuote(commandLine[i + 1])) {
          escape = true;
        } else {
          currentArg += commandLine[i];
          wordFormed = true;
        }
      } else if (inside) {
        if (commandLine[i] == currentQuote && !escape)
          inside = false;
        else {
          currentArg += commandLine[i];
        }
      } else if (isQuote(commandLine[i]) && !escape) {
        currentQuote = commandLine[i];
        inside = true;
        wordFormed = true;
      } else if (commandLine[i] == ' ') {
        if (wordFormed) {
          result.add(currentArg);
          currentArg = "";
          wordFormed = false;
        }
      } else {
        currentArg += commandLine[i];
        wordFormed = true;
      }

      if (escape && commandLine[i] != '\\')
        escape = false;
    }
    if (wordFormed)
      result.add(currentArg);
    if (inside)
      return null;  // unamatched "$currentQuote"
    return result;
  }
}