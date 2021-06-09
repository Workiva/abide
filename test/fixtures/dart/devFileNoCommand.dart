// @dart=2.7
// ^ Do not remove until migrated to null safety. More info at https://wiki.atl.workiva.net/pages/viewpage.action?pageId=189370832
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

library tool.dev;

import 'dart:async';
import 'mock_dart_dev.dart';

Future<Null> main(List<String> args) async {
  // Define the entry points for static analysis.
  config.analyze
    ..entryPoints = ['bin/', 'lib/', 'test/', 'tool/']
    ..strong = true
    ..fatalWarnings = true;

  // Define the directories where the LICENSE should be applied.
  config.copyLicense.directories = ['bin/', 'lib/', 'test/', 'tool/'];

  // Configure whether or not the HTML coverage report should be generated.
  config.coverage
    ..html = true
    ..pubServe = true;

  // Define the directories to include when running the
  // Dart formatter.
  config.format
    ..paths = ['bin/', 'lib/', 'test/', 'tool/']
    ..exclude = [
      'test/vm/generated_runner.dart',
    ];

  config.genTestRunner.configs = <TestRunnerConfig>[
    new TestRunnerConfig(env: Environment.vm, directory: 'test/vm/'),
  ];

  // Define the location of your test suites.
  config.test
    ..unitTests = ['test/vm/']
    ..platforms = ['vm', 'content-shell'];

  // Execute the dart_dev tooling.
  // ignore: avoid_as
  await dev(args) as List<String>;
}
