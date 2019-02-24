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
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'package:abide/src/util.dart';
import 'package:abide/src/update.dart';

Future<Null> main() async {
  YamlMap abideYaml = await loadAbideYaml();

  group('Update', () {
    test('preserves an existing include key', () async {
      String result = await updateAnalysisOption(abideYaml,
          pathToAnalysisOptionsFile:
              'test/fixtures/analysis/includes_pedantic/analysis_options.yaml',
          uncommentClean: false,
          writeToFile: false);
      YamlMap yamlOutput = loadYaml(result);
      expect(yamlOutput['include'] == 'package:pedantic/analysis_options.yaml',
          isTrue);
    });
  });
}
