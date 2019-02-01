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
import 'dart:io';
import 'package:abide/abide.dart';
import 'package:yaml/yaml.dart';
import 'package:args/args.dart';

Future<Null> main(List<String> args) async {
  final ArgParser parser = new ArgParser()
    ..addFlag('json', abbr: 'j', negatable: false)
    ..addFlag('uncomment-clean', abbr: 'c', negatable: false)
    ..addOption('repo', abbr: 'r')
    ..addCommand('update')
    ..addCommand('help');

  ArgResults argResults;

  try {
    argResults = parser.parse(args);
  } on Exception catch (_) {
    print('You have entered an invalid argument. Entered arguments: $args\n');
    print(help);
    exit(2);
  }

  final bool writeJson = argResults['json'] == true;
  final bool uncommentClean = argResults['uncomment-clean'] == true;
  final ArgResults command = argResults.command;

  if (command?.name == 'help') {
    print(help);
    return;
  }

  final YamlMap abideYaml = await loadAbideYaml();
  if (command?.name == 'update') {
    await updateAnalysisOption(abideYaml, uncommentClean: uncommentClean);
  }

  final AbideResult result = checkIfAbides(abideYaml);
  print(result);
  if (writeJson) {
    result.repo = argResults['repo'];
    await writeAbideJson(result);
  }
  if (!result.abides) {
    exit(1);
  }
  exit(0);
}
