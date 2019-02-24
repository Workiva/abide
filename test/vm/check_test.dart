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

@TestOn('vm')
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'package:abide/src/constants.dart';
import 'package:abide/src/check.dart';
import 'package:abide/src/result.dart';
import 'package:abide/src/util.dart';

Future<Null> main() async {
  final YamlMap abideYaml = await loadAbideYaml();

  group('dart2 check', () {
    Directory cwd = Directory.current;

    tearDown(() {
      Directory.current = cwd;
    });

    File setupPubspecLock(String path) {
      File pubspecLock = new File(path);
      if (pubspecLock.existsSync()) {
        pubspecLock.deleteSync();
      }
      return pubspecLock;
    }
  });

  group('Verify pubspec check', () {
    final YamlMap pubspec = loadPubspec();
    final YamlMap pubspecWithMissingDeps =
        loadYamlFile('test/fixtures/pubspec_missing_deps.yaml');
    final YamlMap pubspecWithDeps =
        loadYamlFile('test/fixtures/pubspec_with_deps.yaml');
    final YamlMap pubspecWithPromotedDeps =
        loadYamlFile('test/fixtures/pubspec_with_promoted_deps.yaml');

    test('that pubspec without Abide in dev_dependencies fails', () {
      final AbideResult result = new AbideResult(abideYaml);

      checkPubspec(pubspec: pubspecWithMissingDeps, resultToUpdate: result);

      expect(result.name, pubspecWithMissingDeps['name']);
      expect(result.version, pubspecWithMissingDeps['version']);
      expect(result.checks[abideInPubspecCheckKey].pass, isFalse);
    });

    test('that pubspec with Abide in dev_dependencies passes', () {
      final AbideResult result = new AbideResult(abideYaml);

      checkPubspec(pubspec: pubspecWithDeps, resultToUpdate: result);

      expect(result.name, pubspecWithDeps['name']);
      expect(result.version, pubspecWithDeps['version']);
      expect(result.checks[abideInPubspecCheckKey].pass, isTrue);
    });

    test('that if pubspec name is Abide pubspec check passes', () {
      final AbideResult result = new AbideResult(abideYaml);

      checkPubspec(pubspec: pubspec, resultToUpdate: result);

      expect(result.name, pubspec['name']);
      expect(result.version, pubspec['version']);
      expect(result.checks[abideInPubspecCheckKey].pass, isTrue);
    });

    test('that pubspec without dependency_validator in dev_dependencies fails',
        () {
      final AbideResult result = new AbideResult(abideYaml);

      checkPubspec(pubspec: pubspecWithMissingDeps, resultToUpdate: result);

      expect(result.checks[dependencyValidatorInPubspecCheckKey].pass, isFalse);
    });

    test('that pubspec with dependency_validator in dev_dependencies passes',
        () {
      final AbideResult result = new AbideResult(abideYaml);

      checkPubspec(pubspec: pubspecWithDeps, resultToUpdate: result);

      expect(result.checks[dependencyValidatorInPubspecCheckKey].pass, isTrue);
    });

    test('that pubspec with dependency_validator in dependencies passes', () {
      final AbideResult result = new AbideResult(abideYaml);

      checkPubspec(pubspec: pubspecWithPromotedDeps, resultToUpdate: result);

      expect(result.checks[dependencyValidatorInPubspecCheckKey].pass, isTrue);
    });

    test('that pubspec with dependency_validator as name passes', () {
      final AbideResult result = new AbideResult(abideYaml);

      checkPubspec(
          pubspec: loadYamlFile('test/fixtures/dep_validator_pubspec.yaml'),
          resultToUpdate: result);

      expect(result.checks[dependencyValidatorInPubspecCheckKey].pass, isTrue);
    });

    test('that pubspec with semver_audit as name passes', () {
      final AbideResult result = new AbideResult(abideYaml);

      checkPubspec(
          pubspec: loadYamlFile('test/fixtures/semver_audit_pubspec.yaml'),
          resultToUpdate: result);

      expect(result.checks[dependencyValidatorInPubspecCheckKey].pass, isTrue);
    });
  });

  group('Verify check for run command', () {
    // smithy.yaml fixtures used in more than one test
    final List<String> dockerfileNoRunCommand =
        loadFileAsList('test/fixtures/DockerfileNoRunCommand');
    final List<String> dockerfileWithCommentedRunCommand =
        loadFileAsList('test/fixtures/DockerfileWithCommentedRunCommand');
    final List<String> dockerfileWithMakeCommandContainingRunCommand =
        loadFileAsList(
            'test/fixtures/DockerfileWithMakeCommandContainingRunCommand');
    final List<String> dockerfileWithRunCommand =
        loadFileAsList('test/fixtures/DockerfileWithRunCommand');
    final List<String> dockerfileWithTaskRunner =
        loadFileAsList('test/fixtures/DockerfileWithTaskRunner');

    // Dockerfile fixtures used in more than one test
    final YamlMap smithyNoRunCommand =
        loadYamlFile('test/fixtures/smithy_no_run_command.yaml');
    final YamlMap smithyWithCommentedRunCommand =
        loadYamlFile('test/fixtures/smithy_with_commented_run_command.yaml');
    final YamlMap smithyWithMakeCommandContainingRunCommand = loadYamlFile(
        'test/fixtures/smithy_with_make_command_containing_run_command.yaml');
    final YamlMap smithyWithRunCommand =
        loadYamlFile('test/fixtures/smithy_with_run_command.yml');
    final YamlMap smithyWithTaskRunner =
        loadYamlFile('test/fixtures/smithy_with_task_runner.yaml');

    group('fails when run command ', () {
      test('is not found', () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileNoRunCommand,
          resultToUpdate: result,
          smithy: smithyNoRunCommand,
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test('is commented out', () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileWithCommentedRunCommand,
          resultToUpdate: result,
          smithy: smithyWithCommentedRunCommand,
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test('is commented in task-runner called from Dockerfile', () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileWithTaskRunner,
          resultToUpdate: result,
          smithy: smithyWithCommentedRunCommand,
          alternateFileName: 'test/fixtures/dart/devFileCommentedCommand.dart',
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test(
          'comes from dev.dart file that does not have a task-runner called from Dockerfile',
          () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileWithTaskRunner,
          resultToUpdate: result,
          smithy: smithyWithCommentedRunCommand,
          alternateFileName: 'test/fixtures/dart/devFileNoCommand.dart',
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test('is commented in task-runner called from Smithy', () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileNoRunCommand,
          resultToUpdate: result,
          smithy: smithyWithTaskRunner,
          alternateFileName: 'test/fixtures/dart/devFileCommentedCommand.dart',
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test(
          'comes from dev.dart file that does not have a task-runner called from Smithy',
          () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileNoRunCommand,
          resultToUpdate: result,
          smithy: smithyWithTaskRunner,
          alternateFileName: 'test/fixtures/dart/devFileNoCommand.dart',
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test('comes from a dart file that contains a commented out run command',
          () {
        final List<String> dockerfile = loadFileAsList(
            'test/fixtures/DockerfileWithDartCommandContainingCommentedOutRunCommand');
        final YamlMap smithy = loadYamlFile(
            'test/fixtures/smithy_with_dart_command_containing_commented_run_command.yaml');
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfile,
          resultToUpdate: result,
          smithy: smithy,
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test(
          'comes from a dart file that contains a run command that is commented in both Dockerfile and Smithy',
          () {
        final List<String> dockerfile =
            loadFileAsList('test/fixtures/DockerfileWithCommentedDartCommand');
        final YamlMap smithy = loadYamlFile(
            'test/fixtures/smithy_with_commented_dart_command.yaml');

        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfile,
          resultToUpdate: result,
          smithy: smithy,
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test('comes from a script executed in Dockerfile that is commented out',
          () {
        final List<String> dockerfile = loadFileAsList(
            'test/fixtures/DockerfileWithScriptContainingCommentedRunCommand');
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfile,
          resultToUpdate: result,
          smithy: smithyNoRunCommand,
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test('comes from a script executed in Smithy that is commented out', () {
        final YamlMap smithy = loadYamlFile(
            'test/fixtures/smithy_with_script_containing_commented_run_command.yaml');
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileNoRunCommand,
          resultToUpdate: result,
          smithy: smithy,
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test('commented in a Makefile in a Dockerfile', () {
        final List<String> dockerfile =
            loadFileAsList('test/fixtures/DockerfilWithCommentedMakeCommand');
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfile,
          resultToUpdate: result,
          smithy: smithyNoRunCommand,
          alternateFileName: 'test/fixtures/dart/MakefileWithRunCommand',
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test('is commented in a Makefile in a Dockerfile', () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileWithMakeCommandContainingRunCommand,
          resultToUpdate: result,
          smithy: smithyNoRunCommand,
          alternateFileName:
              'test/fixtures/dart/MakefileWithCommentedRunCommand',
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test(
          'comes from a commented task-runner command found in a Makefile in a Dockerfile',
          () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileWithMakeCommandContainingRunCommand,
          resultToUpdate: result,
          smithy: smithyNoRunCommand,
          alternateFileName:
              'test/fixtures/dart/MakefileWithCommentedTaskRunner',
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });
      test('is commented in a Makefile in Smithy', () {
        final YamlMap smithy = loadYamlFile(
            'test/fixtures/smithy_with_commented_make_command.yaml');
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileNoRunCommand,
          resultToUpdate: result,
          smithy: smithy,
          alternateFileName: 'test/fixtures/dart/MakefileWithRunCommand',
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test('is commented in a Makefile in Smithy', () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileNoRunCommand,
          resultToUpdate: result,
          smithy: smithyWithMakeCommandContainingRunCommand,
          alternateFileName:
              'test/fixtures/dart/MakefileWithCommentedRunCommand',
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });

      test(
          'comes from a commented task-runner command found in a Makefile in Smithy',
          () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileNoRunCommand,
          resultToUpdate: result,
          smithy: smithyWithMakeCommandContainingRunCommand,
          alternateFileName:
              'test/fixtures/dart/MakefileWithCommentedTaskRunner',
        );

        expect(result.checks[abideRunCheckKey].pass, isFalse);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isFalse);
      });
    });

    group('passes when run command', () {
      test('is found in Smithy file', () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileNoRunCommand,
          resultToUpdate: result,
          smithy: smithyWithRunCommand,
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('is found in Dockerfile', () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileWithRunCommand,
          resultToUpdate: result,
          smithy: smithyNoRunCommand,
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('is found in Dockerfile and run command is commented out in Smithy',
          () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileWithRunCommand,
          resultToUpdate: result,
          smithy: smithyWithCommentedRunCommand,
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('is found in Smithy and run command is commented out in Dockerfile',
          () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileWithCommentedRunCommand,
          resultToUpdate: result,
          smithy: smithyWithRunCommand,
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test(
          'is found in Dockerfile and Dockerfile also contains a commented out run command',
          () {
        final List<String> dockerfile = loadFileAsList(
            'test/fixtures/DockerfileWithRunCommandAndCommentedRunCommand');
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfile,
          resultToUpdate: result,
          smithy: smithyNoRunCommand,
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('is found in both smithy.yaml and Dockerfile', () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileWithRunCommand,
          resultToUpdate: result,
          smithy: smithyWithRunCommand,
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('comes from task-runner in Dockerfile', () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileWithTaskRunner,
          resultToUpdate: result,
          smithy: smithyNoRunCommand,
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('comes from task-runner in Smithy', () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileNoRunCommand,
          resultToUpdate: result,
          smithy: smithyWithTaskRunner,
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('comes from a chanied dart file executed in a Dockerfile', () {
        final List<String> dockerfile =
            loadFileAsList('test/fixtures/DockerfileWithChainedDartCommand');
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfile,
          resultToUpdate: result,
          smithy: smithyNoRunCommand,
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('comes from an unchained dart file executed in a Dockerfile', () {
        final List<String> dockerfile =
            loadFileAsList('test/fixtures/DockerfileWithUnchainedDartCommand');
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfile,
          resultToUpdate: result,
          smithy: smithyNoRunCommand,
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('comes from a dart file executed in Smithy', () {
        final YamlMap smithy =
            loadYamlFile('test/fixtures/smithy_with_dart_command.yaml');
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileNoRunCommand,
          resultToUpdate: result,
          smithy: smithy,
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('comes from script excecuted in Dockerfile', () {
        final List<String> dockerfile = loadFileAsList(
            'test/fixtures/DockerfileWithScriptContainingRunCommand');
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfile,
          resultToUpdate: result,
          smithy: smithyNoRunCommand,
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('comes from script executed in Smithy', () {
        final YamlMap smithy = loadYamlFile(
            'test/fixtures/smithy_with_script_containing_run_command.yaml');
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileNoRunCommand,
          resultToUpdate: result,
          smithy: smithy,
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('comes from a Makefile command executed in Dockerfile', () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileWithMakeCommandContainingRunCommand,
          resultToUpdate: result,
          smithy: smithyNoRunCommand,
          alternateFileName: 'test/fixtures/dart/MakefileWithRunCommand',
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test(
          'comes from a task-runner command found in a Makefile in a Dockerfile',
          () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileWithMakeCommandContainingRunCommand,
          resultToUpdate: result,
          smithy: smithyNoRunCommand,
          alternateFileName: 'test/fixtures/dart/MakefileWithTaskRunner',
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('comes from a Makefile command executed in Smithy', () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileNoRunCommand,
          resultToUpdate: result,
          smithy: smithyWithMakeCommandContainingRunCommand,
          alternateFileName: 'test/fixtures/dart/MakefileWithRunCommand',
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });

      test('comes from a task-runner command found in a Makefile in Smithy',
          () {
        final AbideResult result = new AbideResult(abideYaml);

        checkForRunCommand(
          dockerfile: dockerfileNoRunCommand,
          resultToUpdate: result,
          smithy: smithyWithMakeCommandContainingRunCommand,
          alternateFileName: 'test/fixtures/dart/MakefileWithTaskRunner',
        );

        expect(result.checks[abideRunCheckKey].pass, isTrue);
        expect(result.checks[dependencyValidatorRunCheckKey].pass, isTrue);
      });
    });
  });
}
