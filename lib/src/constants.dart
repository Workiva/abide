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

import 'dart:io';
import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

/// Looks through Dockerfile and smithy.yaml to find a run command
/// and returns true if found.
typedef bool FoundCommand({
  @required CommandChecks commandsToCheck,
  @required List<String> dockerfile,
  @required YamlMap smithy,
  @visibleForTesting String alternateFileName,
});

/// A class that houses the AbideResult check key affiliated with a specific
/// command like 'pub run abide', the run command and the commented versions of the
/// run command.
class CommandChecks {
  final String abideResultCheckKey;
  final RegExp runCommand;
  final RegExp commentedRunCommandWithHashTag;
  final RegExp commentedRunCommandWithDoubleSlash;

  CommandChecks._(
    this.abideResultCheckKey,
    this.runCommand,
    this.commentedRunCommandWithHashTag,
    this.commentedRunCommandWithDoubleSlash,
  );

  /// The check and commands associated with `pub run abide`.
  factory CommandChecks.abide() => CommandChecks._(
        abideRunCheckKey,
        abideRunCommand,
        commentedAbideRunCommandHashTag,
        commentedAbideRunCommandDoubleSlash,
      );

  /// The check and commands associated with `pub run dependency_validator`.
  factory CommandChecks.dependencyValidator() => CommandChecks._(
        dependencyValidatorRunCheckKey,
        dependencyValidatorRunCommand,
        commentedDependencyValidatorRunCommandHashTag,
        commentedDependencyValidatorRunCommandDoubleSlash,
      );
}

/// The list of dependencies that abide expects to find installed and their
/// respective pubspec check keys.
final Map<String, String> pubspecChecks = {
  'abide': abideInPubspecCheckKey,
  'dependency_validator': dependencyValidatorInPubspecCheckKey,
};

/// The list of CommandChecks used in checkForRunCommand() to verify that Abide
/// and Dependency Validator are being run in CI.
final List<CommandChecks> commandChecksList = [
  CommandChecks.abide(),
  CommandChecks.dependencyValidator(),
];

const String abideJsonFilename = 'abide.json';
const String abideInPubspecCheckKey = 'abide_in_pubspec';
const String abideRunCheckKey = 'abide_run';
const String abideYamlFilename = 'lib/abide.yaml';
const String analysisOptionsFilename = 'analysis_options.yaml';
const String dependencyValidatorInPubspecCheckKey =
    'dependency_validator_in_pubspec';
const String dependencyValidatorRunCheckKey = 'dependency_validator_run';
const String devFilename = 'tool/dev.dart';
const String dockerfileName = 'Dockerfile';
const String help = '''Usage: abide [command]
abide [--json|-j] (default: Checks that your analysis_options.yaml abides by recommendations)
abide update [--uncomment-clean] (Updates your analysis_options.yaml with default recommendations)
abide help (shows this help)
''';
const String makefileName = 'Makefile';
const String oldAnalysisOptionsFilename = '.analysis_options';
const String pubspecFilename = 'pubspec.yaml';
const String smithyFilename = 'smithy.yml';
const String smithyFilename2 = 'smithy.yaml';
const String strongMode = 'strong-mode';

final int dartMajorVersion = int.parse(Platform.version.split('.').first);

const List<String> possibleAnalysisOptionFilenames = <String>[
  analysisOptionsFilename,
  oldAnalysisOptionsFilename
];

final RegExp abideRunCommand = RegExp(r'pub run abide');

final RegExp commentedAbideRunCommandDoubleSlash =
    RegExp(r'\/\/.*pub run abide');

final RegExp commentedAbideRunCommandHashTag = RegExp(r'#.*pub run abide');

final RegExp commentedDartCommandInFile = RegExp(r'#.*\.dart');

final RegExp commentedDependencyValidatorRunCommandDoubleSlash =
    RegExp(r'\/\/.*pub run dependency_validator');

final RegExp commentedDependencyValidatorRunCommandHashTag =
    RegExp(r'#.*pub run dependency_validator');

final RegExp commentedMakeCommandInFile = RegExp(r'#.*\make');

final RegExp commentedScriptCommandInFile = RegExp(r'#.*\.sh\b');

final RegExp commentedTaskRunnerCommand =
    RegExp(r'#.*pub run dart_dev task-runner');

final RegExp dartCommandInFile = RegExp(r'\bdart\b.*\.dart');

final RegExp dartFile = RegExp(r'\S*\.dart');

final RegExp dependencyValidatorRunCommand =
    RegExp(r'pub run dependency_validator');

final RegExp makeCommandInFile = RegExp(r'.*\make');

final RegExp scriptCommandInFile = RegExp(r'.*\.sh\b');

final RegExp scriptFile = RegExp(r'\S*\.sh');

final RegExp taskRunnerCommand = RegExp(r'pub run dart_dev task-runner');
