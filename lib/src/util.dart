// Copyright 2017-2019 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:abide/src/constants.dart';
import 'package:abide/src/result.dart';
import 'package:meta/meta.dart';
import 'package:resource/resource.dart';
import 'package:yaml/yaml.dart';

/// Gets a sorted list of the top level yaml keys except ones
/// starting with double underscore
List<String> getTopLevelYamlKeys(YamlMap yaml) => yaml.keys
    .map<String>((k) => k.toString())
    .where((k) => !k.startsWith('__'))
    .toList()
      ..sort();

Future<YamlMap> loadAbideYaml() async {
  const Resource resource = const Resource('package:abide/abide.yaml');
  final String string = await resource.readAsString();
  return loadYaml(string);
}

@visibleForTesting
YamlMap loadYamlFile(String file) {
  if (file == null) {
    return null;
  }
  final File f = new File(file);
  if (!f.existsSync()) {
    return null;
  }
  return loadYaml(f.readAsStringSync());
}

String loadFileAsString(String fileName) {
  final File f = new File(fileName);
  if (!f.existsSync()) {
    return null;
  }
  return f.readAsStringSync();
}

List<String> loadFileAsList(String fileName) {
  final File f = new File(fileName);
  if (!f.existsSync()) {
    return null;
  }

  return f.readAsLinesSync();
}

YamlMap loadPubspec() => loadYamlFile(pubspecFilename);

YamlMap loadSmithy() =>
    loadYamlFile(smithyFilename) ?? loadYamlFile(smithyFilename2);

YamlMap loadAnalysisOptions(
    {String pathToAnalysisOptionsFile, bool renameDeprecatedFilename: false}) {
  if (pathToAnalysisOptionsFile != null) {
    return loadYamlFile(pathToAnalysisOptionsFile);
  } else {
    return loadYamlFile(findAnalysisOptionsFile(
        renameDeprecatedFilename: renameDeprecatedFilename));
  }
}

String loadAnalysisOptionsAsString({String pathToAnalysisOptionsFile}) {
  final String filename =
      pathToAnalysisOptionsFile ?? findAnalysisOptionsFile();
  if (filename == null) {
    return '';
  }
  return new File(filename).readAsStringSync();
}

/// Find an existing analysis option file in the given directory or current dir
String findAnalysisOptionsFile({bool renameDeprecatedFilename: false}) {
  final File oldAOpt = new File(oldAnalysisOptionsFilename);
  final File aOpt = new File(analysisOptionsFilename);
  final bool oldAOptExists = oldAOpt.existsSync();
  bool aOptExists = aOpt.existsSync();

  // If neither exists, return null early
  if (!aOptExists && !oldAOptExists) {
    return null;
  }

  // Handle updating the deprecated filename
  if (renameDeprecatedFilename && oldAOptExists) {
    // Just delete .analysis_options if there's also analysis_options.yaml
    if (aOptExists) {
      print(
          'warn: multiple analysis option files were found. Removing $oldAnalysisOptionsFilename');
      oldAOpt.deleteSync();
    } else {
      // If there's only .analysis_options then rename it to analysis_options.yaml
      print(
          'warn: Renaming $oldAnalysisOptionsFilename to $analysisOptionsFilename');
      oldAOpt.renameSync(analysisOptionsFilename);
      aOptExists = true;
    }
  }

  // If we aren't updating anything, just return the right found filename
  if (aOptExists) {
    return analysisOptionsFilename;
  }
  if (oldAOptExists) {
    return oldAnalysisOptionsFilename;
  }
  return null;
}

dynamic getYamlValue(YamlMap map, String pathWithColonSeparators,
    [Object defaultValue]) {
  try {
    final List<String> paths = pathWithColonSeparators.split(':');
    dynamic currentYamlObject = map;
    while (paths.isNotEmpty) {
      if (currentYamlObject == null) {
        return defaultValue;
      }
      if (currentYamlObject is bool ||
          currentYamlObject is String ||
          currentYamlObject is num) {
        return currentYamlObject;
      }
      String key = paths.removeAt(0);
      if (paths.isEmpty &&
          currentYamlObject is YamlMap &&
          currentYamlObject.containsKey(key)) {
        return currentYamlObject[key] ?? defaultValue;
      }
      if (paths.isEmpty && currentYamlObject is YamlList) {
        return (currentYamlObject as YamlList).contains(key); //ignore: avoid_as
      }
      currentYamlObject = currentYamlObject[key];
      if (currentYamlObject == null) {
        return defaultValue;
      }
    }
  } on Exception catch (_) {
    return defaultValue;
  }
  return defaultValue;
}

/// Looks in dart files or script files that are executed in a Dockerfile for a
/// specifed run command and returns true if found.
bool foundRunCommandInFilesRunInDockerfile(List<String> file, RegExp runCommand,
        RegExp commentedOutCommandToFind) =>
    file
        .expand(getFileNamesFromCommandLine)
        .any((dartOrScriptFileName) => foundCommand(
              loadFileAsList(dartOrScriptFileName),
              runCommand,
              commentedOutCommandToFind,
            ));

/// Looks in dart files or script files that are executed in a smithy.yaml for a
/// specified run command and returns true if found.
bool foundRunCommandInFilesRunInSmithy(YamlMap smithy, RegExp commandToFind,
    RegExp commentedOutCommandToFind, RegExp fileCommandToFind) {
  final List<YamlList> smithyScripts = <YamlList>[
    smithy['before_script'],
    smithy['script'],
    smithy['after_script'],
  ];

  for (YamlList list in smithyScripts) {
    if (list != null) {
      for (String item in list) {
        if (item.contains(fileCommandToFind)) {
          for (String fileName in getFileNamesFromCommandLine(item)) {
            if (foundCommand(loadFileAsList(fileName), commandToFind,
                commentedOutCommandToFind)) {
              return true;
            }
          }
        }
      }
    }
  }

  return false;
}

/// Looks for a specific command in a file and returns true if found.
bool foundCommand(
    List<String> file, RegExp commandToFind, RegExp commentedCommandToFind) {
  if (file == null) {
    return false;
  } else {
    return file.any((line) =>
        !line.contains(commentedCommandToFind) && line.contains(commandToFind));
  }
}

/// Returns the file names from a line that runs one or more commands that execute either
/// a dart or script file specifically in a Dockerfile or a smithy.yaml.
Iterable<String> getFileNamesFromCommandLine(String command) sync* {
  final int commentStart = command.indexOf('#');

  yield* dartFile.allMatches(command).where((match) {
    if (commentStart != -1) {
      return match.start < commentStart;
    } else {
      return true;
    }
  }).map((match) => match[0]);

  yield* scriptFile.allMatches(command).where((match) {
    if (commentStart != -1) {
      return match.start < commentStart;
    } else {
      return true;
    }
  }).map((match) => match[0]);
}

/// Checks if smithy.yaml contains a specific command pattern and returns true
/// if found. This is used specifically to find if smithy.yaml contains a command
/// that executes task-runner, a specified run command or a make command.
bool smithyContainsCommand(YamlMap smithy, Pattern commandPattern) =>
    smithy['before_script'].toString().contains(commandPattern) ||
    smithy['script'].toString().contains(commandPattern) ||
    smithy['after_script'].toString().contains(commandPattern);

bool checkIfStrongModeIsSet(YamlMap analysisOptions) {
  try {
    return analysisOptions['analyzer'] != null &&
        (analysisOptions['analyzer']['strong-mode'] == 'true' ||
            analysisOptions['analyzer']['strong-mode'] == true ||
            analysisOptions['analyzer']['strong-mode'] is YamlMap);
  } on Exception catch (_) {}
  return false;
}

Future<Null> writeAbideJson(AbideResult result) async {
  String json = json.encode(result);
  final String file = '${Directory.current.path}/abide.json';
  print('Writing $file');
  new File(file).writeAsStringSync(json);
}
