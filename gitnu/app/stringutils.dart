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
      return null; // unmatched "$currentQuote"
    return result;
  }

  /**
   * Searches the args list for a switch that includes a string parameter, if
   * found the switch and its parameter are removed from the list.
   * Returns defaultValue string if the switch is not present.
   * Throws FormatException if the switch is present with no parameter.
   * Throws FormatException if the switch is present with invalid parameter.
   * Returns the switch parameter string if switch is present.
   */
  static String stringSwitch(List<String> args, String switchName,
                             String defaultValue) {
    String switchValue = switchFinder(args, switchName);
    if(switchValue == "")
      return defaultValue;
    // A valid parameter is any string that is not itself a switch.
    if (switchValue[0] != "-")
      return switchValue;
    throw new FormatException("invalid parameter $switchValue for $switchName");
  }

  /**
   * Searches the args list for a switch that includes an int parameter, if
   * found the switch and its parameter are removed from the list.
   * Returns defaultValue if the switch is not present.
   * Throws FormatException if the switch is present with no parameter.
   * Throws FormatException if the switch is present with invalid parameter.
   * Returns the switch parameter int if switch is present.
   */
  static int intSwitch(List<String> args, String switchName, int defaultValue) {
    String switchValue = switchFinder(args, switchName);
    if (switchValue == "")
      return defaultValue;
    if (int.parse(switchValue, onError: (value) => -1) != -1)
      return int.parse(switchValue);
    throw new FormatException("invalid parameter $switchValue for $switchName");
  }

  /**
   * Searches the args list for a switch that includes a parameter, if found
   * removes the switch and its parameter from the list.
   * Throws FormatException if the switch is present with no parameter.
   * Returns the empty string if the switch is not present.
   * Returns the parameter string if found.
   */
  static String switchFinder(List<String> args, String switchName) {
    String prepend = '-';
    if (switchName.length > 1)
      prepend = '--';
    int index = args.indexOf(prepend + switchName);
    if (index != -1) {
      if (index + 1 < args.length) {
        args.removeAt(index);
        return args.removeAt(index);
      }
      throw new FormatException("no parameter included with $switchName");
    }
    return "";
  }
}