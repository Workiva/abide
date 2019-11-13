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

import 'package:abide/src/constants.dart';
import 'package:abide/src/util.dart';
import 'package:yaml/yaml.dart';

class AbideResult {
  String name = '';
  String repo;
  String version = '';
  List<String> errors = <String>[];
  Map<String, Check> checks = <String, Check>{};

  int passing = 0;
  int passingPoints = 0;
  int totalPoints = 0;
  int total = 0;
  int percent = 0;
  bool abides = false;

  AbideResult(YamlMap abideYaml,
      {bool isDeprecatedFilename = false,
      bool hasAnalysisOptionsFile = false,
      bool isStrongModeSet = false}) {
    checks.addAll(<String, Check>{
      oldAnalysisOptionsFilename: Check()
        ..description = 'Do not use deprecated filename .analysis_options'
        ..pass = !isDeprecatedFilename,
      analysisOptionsFilename: Check()
        ..description = 'analysis_options.yaml exists'
        ..pass = hasAnalysisOptionsFile,
      strongMode: Check()
        ..description = 'analyzer strong mode is used'
        ..pass = isStrongModeSet,
    });
    final List<String> lintKeys = getTopLevelYamlKeys(abideYaml);
    // each lint rule becomes a check
    for (String lintKey in lintKeys) {
      final String recommendation = abideYaml[lintKey]['recommendation'] ?? '';
      int weight = 1;
      if (recommendation == 'required' || recommendation == 'avoid') {
        weight = 3;
      }
      if (recommendation == 'recommended') {
        weight = 2;
      }
      if (recommendation == 'optional') {
        weight = 1;
      }
      checks[lintKey] = Check()
        ..weight = weight
        ..description = '$recommendation lint rule: $lintKey';
    }

    // add non lint rule checks
    checks.addAll(<String, Check>{
      abideInPubspecCheckKey: Check()
        ..weight = 12
        ..description =
            'pubspec.yaml does not contain Abide. Add Abide to your dev_dependencies in pubspec.yaml',
      abideRunCheckKey: Check()
        ..weight = 12
        ..description =
            'Abide is not run in CI. Add "pub run abide" command to run Abide in CI.',
      dependencyValidatorInPubspecCheckKey: Check()
        ..weight = 8
        ..description =
            'pubspec.yaml does not contain Dependency Validator. Add Dependency Validator to your dev_dependencies in pubspec.yaml',
      dependencyValidatorRunCheckKey: Check()
        ..weight = 8
        ..description =
            'Dependency Validator is not run in CI. Add "pub run dependency_validator" command to run Dependency Validator in CI.',
    });
  }

  void calc() {
    passingPoints = 0;
    totalPoints = 0;
    for (Check c in checks.values) {
      totalPoints += c.weight;
      if (c.pass) {
        passingPoints += c.weight;
      }
    }
    passing = checks.values.where((Check c) => c.pass).length;
    total = checks.keys.length;
    percent =
        (passingPoints.toDouble() / totalPoints.toDouble() * 100.0).floor();
    abides = passing == total;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'repo': repo,
        'version': version,
        'abides': abides,
        'passing': passing,
        'total': total,
        'percent': percent,
        'checks': checks.values.toList()
      };

  @override
  String toString() {
    final StringBuffer sb = StringBuffer();
    final Iterable<String> failingChecks = checks.values
        .where((Check c) => !c.pass)
        .map((Check c) =>
            '  error • (${c.weight}${c.weight == 1 ? "pt" : "pts"}) ${c.description}\n');

    sb
      ..writeAll(failingChecks)
      ..write('$name@$version ')
      ..write(passing == total ? 'abides. ' : 'DOES NOT abide. ')
      ..write('$passingPoints points out of $totalPoints ($percent%)');

    return sb.toString();
  }
}

class Check {
  String description = '';
  String recommendation;
  bool pass = false;
  int weight = 1;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'description': description,
        'adhering': pass,
        'weight': weight
      };
}
