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

import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import 'package:abide/src/constants.dart';
import 'package:abide/src/result.dart';
import 'package:abide/src/util.dart';

AbideResult checkAnalysisOptions(
    {@required YamlMap abideYaml,
    @required YamlMap analysisOptions,
    @required String aoFilename,
    @required YamlMap pubspec,
    @required AbideResult resultToUpdate}) {
  final List<String> lintKeys = getTopLevelYamlKeys(abideYaml);

  if (analysisOptions != null) {
    resultToUpdate.checks[analysisOptionsFilename].pass = true;
    resultToUpdate.checks[strongMode].pass =
        checkIfStrongModeIsSet(analysisOptions);

    final YamlList analysisOptionsRules =
        getYamlValue(analysisOptions, 'linter:rules', new YamlList());

    for (String lintKey in lintKeys) {
      final bool isPresent = analysisOptionsRules.contains(lintKey);
      final String recommendation = abideYaml[lintKey]['recommendation'] ?? '';
      final bool avoid = recommendation == 'avoid';
      final bool required = recommendation == 'required';
      // assume it passes
      resultToUpdate.checks[lintKey]
        ..pass = true
        ..recommendation = recommendation;
      // unless it is a rule to avoid, or missing required
      if (avoid && isPresent || !isPresent && required) {
        resultToUpdate.checks[lintKey].pass = false;
      }
      if (recommendation == 'recommended' && !isPresent) {
        print('$recommendation lint rule: $lintKey');
      }
    }
  }

  return resultToUpdate;
}

/// Checks pubspec.yaml for recommended tool dependencies and updates AbideResults
/// with recommendations for which dependencies need to be install if they're missing.
AbideResult checkPubspec(
    {@required YamlMap pubspec, @required AbideResult resultToUpdate}) {
  if (pubspec != null) {
    resultToUpdate
      ..name = pubspec['name'] ?? ''
      ..version = pubspec['version'] ?? '';

    bool hasDevDeps = pubspec['dev_dependencies'] != null;
    bool hasDeps = pubspec['dependencies'] != null;

    pubspecChecks.forEach((String dependency, String pubspecCheckKey) {
      if (pubspec['name'] == dependency) {
        resultToUpdate.checks[pubspecCheckKey].pass = true;
      } else {
        bool matches =
            hasDeps && pubspec['dependencies'].containsKey(dependency);
        bool matchesDev =
            hasDevDeps && pubspec['dev_dependencies'].containsKey(dependency);
        if (matches || matchesDev) {
          resultToUpdate.checks[pubspecCheckKey].pass = true;
        }
      }
    });
  }

  return resultToUpdate;
}

/// Checks a variety of methods for how any command or file can be executed
/// from a Dockerfile or a smithy.yaml. Since smithy.yaml will eventually no
/// longer be used, Dockerfile will always be checked first.
///
/// 1. Look in the Dockerfile and smithy.yaml file for the specified run command.
/// 2. If the command is not found check if the task-runner from dev.dart is
/// executed in Dockerfile or smithy.yaml and look there for the specified run command.
/// 3. If the command is not found look for dart files that are executed in Dockerfile
/// and smithy.yaml and look in the found dart files for the specified run command.
/// 4. If the command is not found look in script files that are executed in Dockerfile and
/// smithy.yaml and look in the found script files for the specified command.
/// 5. Finally, if the command is not found look for make commands executed in Dockerfile and
/// smithy.yaml and look in a Makefile for the specified command or a task-runner
/// command executed in the Makefile. If the specified command is not found and a task-runner
/// command is look in dev.dart for the command.
AbideResult checkForRunCommand({
  @required List<String> dockerfile,
  @required AbideResult resultToUpdate,
  @required YamlMap smithy,

  /// This is an optional parameter meant to be used for testing purposes.
  /// It allows passing in an alternative file name to look into a specific
  /// dev.dart or Makefile.
  @visibleForTesting String alternateFileName,
}) {
  final List<FoundCommand> searchMethods = [
    foundRunCommandInDockerfileOrSmithy,
    foundRunCommandInTaskRunner,
    foundRunCommandInDartFiles,
    foundRunCommandInScriptFiles,
    foundRunCommandInMakefile,
  ];

  for (CommandChecks check in commandChecksList) {
    for (FoundCommand method in searchMethods) {
      bool methodResult = false;
      methodResult = method(
        commandsToCheck: check,
        dockerfile: dockerfile,
        smithy: smithy,
        alternateFileName: alternateFileName,
      );

      if (methodResult) {
        resultToUpdate.checks[check.abideResultCheckKey].pass = methodResult;
        break;
      }
    }
  }

  return resultToUpdate;
}

AbideResult checkIfAbides(YamlMap abideYaml) {
  final List<String> dockerfile = loadFileAsList(dockerfileName);
  final YamlMap smithy = loadSmithy();
  final YamlMap pubspec = loadPubspec();
  final YamlMap analysisOptions = loadAnalysisOptions();
  final String aoFilename = findAnalysisOptionsFile();
  final AbideResult result = new AbideResult(abideYaml,
      isDeprecatedFilename: aoFilename == oldAnalysisOptionsFilename);

  checkAnalysisOptions(
    abideYaml: abideYaml,
    analysisOptions: analysisOptions,
    aoFilename: aoFilename,
    pubspec: pubspec,
    resultToUpdate: result,
  );

  checkPubspec(pubspec: pubspec, resultToUpdate: result);

  checkForRunCommand(
    dockerfile: dockerfile,
    resultToUpdate: result,
    smithy: smithy,
  );

  result.calc();

  return result;
}

/// Looks through a Dockerfile and a smithy.yaml file for a run command and
/// returns true if it's found.
bool foundRunCommandInDockerfileOrSmithy({
  @required CommandChecks commandsToCheck,
  @required List<String> dockerfile,
  @required YamlMap smithy,
  @visibleForTesting String alternateFileName,
}) {
  if (dockerfile != null &&
      foundCommand(dockerfile, commandsToCheck.runCommand,
          commandsToCheck.commentedRunCommandWithHashTag)) {
    return true;
  } else if (smithy != null &&
      smithyContainsCommand(smithy, commandsToCheck.runCommand)) {
    return true;
  }

  return false;
}

/// Looks for a 'pub run dart_dev task-runner' in Dockerfile and smithy.yaml. If
/// found it will look into the dev.dart file for a run command and
/// return true if found.
bool foundRunCommandInTaskRunner({
  @required CommandChecks commandsToCheck,
  @required List<String> dockerfile,
  @required YamlMap smithy,
  @visibleForTesting String alternateFileName,
}) {
  if (dockerfile != null &&
      foundCommand(dockerfile, taskRunnerCommand, commentedTaskRunnerCommand)) {
    return foundCommand(
        loadFileAsList(alternateFileName ?? devFilename),
        commandsToCheck.runCommand,
        commandsToCheck.commentedRunCommandWithDoubleSlash);
  } else if (smithy != null &&
      smithyContainsCommand(smithy, taskRunnerCommand)) {
    return foundCommand(
        loadFileAsList(alternateFileName ?? devFilename),
        commandsToCheck.runCommand,
        commandsToCheck.commentedRunCommandWithDoubleSlash);
  }

  return false;
}

/// Looks for a command that executes a dart file(s) in Dockerfile and smithy.yaml.
/// If found it will look into the executed dart file(s) for a run command and
/// return true if found.
bool foundRunCommandInDartFiles({
  @required CommandChecks commandsToCheck,
  @required List<String> dockerfile,
  @required YamlMap smithy,
  @visibleForTesting String alternateFileName,
}) {
  if (dockerfile != null &&
      foundCommand(dockerfile, dartCommandInFile, commentedDartCommandInFile)) {
    return foundRunCommandInFilesRunInDockerfile(
        dockerfile,
        commandsToCheck.runCommand,
        commandsToCheck.commentedRunCommandWithDoubleSlash);
  } else if (smithy != null) {
    return foundRunCommandInFilesRunInSmithy(smithy, commandsToCheck.runCommand,
        commandsToCheck.commentedRunCommandWithDoubleSlash, dartCommandInFile);
  }

  return false;
}

/// Looks for script file(s) that are executed in Dockerfile and smithy.yaml.
/// If found it will look into the executed script file(s) for a run command and
/// return true if found.
bool foundRunCommandInScriptFiles({
  @required CommandChecks commandsToCheck,
  @required List<String> dockerfile,
  @required YamlMap smithy,
  @visibleForTesting String alternateFileName,
}) {
  if (dockerfile != null &&
      foundCommand(
          dockerfile, scriptCommandInFile, commentedScriptCommandInFile)) {
    return foundRunCommandInFilesRunInDockerfile(
        dockerfile,
        commandsToCheck.runCommand,
        commandsToCheck.commentedRunCommandWithHashTag);
  } else if (smithy != null) {
    return foundRunCommandInFilesRunInSmithy(smithy, commandsToCheck.runCommand,
        commandsToCheck.commentedRunCommandWithHashTag, scriptCommandInFile);
  }

  return false;
}

/// Looks for make commands executed in Dockerfile and smithy.ymal. If found it will
/// look in a Makefile for a 'pub run abide' command. If it's not found it will look for a
/// 'pub run dart_dev task-runner' command and search dev.dart for a run command.
/// If a the command is found it will return true.
bool foundRunCommandInMakefile({
  @required CommandChecks commandsToCheck,
  @required List<String> dockerfile,
  @required YamlMap smithy,
  @visibleForTesting String alternateFileName,
}) {
  final List<String> makefile =
      loadFileAsList(alternateFileName ?? makefileName);

  if (makefile != null) {
    if (dockerfile != null &&
        foundCommand(
            dockerfile, makeCommandInFile, commentedMakeCommandInFile)) {
      if (foundCommand(makefile, commandsToCheck.runCommand,
          commandsToCheck.commentedRunCommandWithHashTag)) {
        return true;
      } else if (foundCommand(
          makefile, taskRunnerCommand, commentedTaskRunnerCommand)) {
        return foundCommand(
            loadFileAsList(devFilename),
            commandsToCheck.runCommand,
            commandsToCheck.commentedRunCommandWithDoubleSlash);
      }
    } else if (smithy != null &&
        smithyContainsCommand(smithy, makeCommandInFile)) {
      if (foundCommand(makefile, commandsToCheck.runCommand,
          commandsToCheck.commentedRunCommandWithHashTag)) {
        return true;
      } else if (foundCommand(
          makefile, taskRunnerCommand, commentedTaskRunnerCommand)) {
        return foundCommand(
            loadFileAsList(devFilename),
            commandsToCheck.runCommand,
            commandsToCheck.commentedRunCommandWithDoubleSlash);
      }
    }
  }

  return false;
}
