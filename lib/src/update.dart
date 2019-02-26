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
import 'package:yaml/yaml.dart';
import 'package:abide/src/constants.dart';
import 'package:abide/src/util.dart';

Future<String> updateAnalysisOption(YamlMap abideYaml,
    {String pathToAnalysisOptionsFile,
    bool uncommentClean,
    bool writeToFile = true}) async {
  YamlMap currentAnalysisOptions = loadAnalysisOptions(
      pathToAnalysisOptionsFile: pathToAnalysisOptionsFile,
      renameDeprecatedFilename: true);

  final String currentAnalysisOptionsString = loadAnalysisOptionsAsString(
      pathToAnalysisOptionsFile: pathToAnalysisOptionsFile);

  Map<String, Map<String, int>> lintErrorCounts = <String, Map<String, int>>{};
  // Write a version with ALL lint rules enabled
  // and then run dart analyzer to get counts of lint per rule
  // those counts are passed into the 2nd write run to decide
  // whether or not to comment out a lint rule with a lot of
  // new lint warnings. If we're not writing to a file, then lint
  // counts won't work, so skip that step.
  if (writeToFile) {
    writeAnalyisOptionsFile(
        all: true,
        abideYaml: abideYaml,
        currentAnalysisOptions: currentAnalysisOptions,
        currentAnalysisOptionsString: currentAnalysisOptionsString);
    lintErrorCounts = await getLintErrorCounts(abideYaml: abideYaml);
  }
  return writeAnalyisOptionsFile(
      abideYaml: abideYaml,
      currentAnalysisOptions: currentAnalysisOptions,
      currentAnalysisOptionsString: currentAnalysisOptionsString,
      lintErrorCounts: lintErrorCounts,
      uncommentClean: uncommentClean,
      writeToFile: writeToFile);
}

String writeAnalyisOptionsFile(
    {YamlMap abideYaml,
    YamlMap currentAnalysisOptions,
    String currentAnalysisOptionsString,
    bool all = false,
    bool uncommentClean = false,
    bool writeToFile = true,
    Map<String, Map<String, int>> lintErrorCounts =
        const <String, Map<String, int>>{}}) {
  currentAnalysisOptions ??= new YamlMap();

  String linterVersion = abideYaml['__linter_version'];
  final String currentInclude = getYamlValue(currentAnalysisOptions, 'include');
  final bool currentImplicitCasts = getYamlValue(
      currentAnalysisOptions, 'analyzer:strong-mode:implicit-casts', true);
  final bool currentImplicitDynamic = getYamlValue(
      currentAnalysisOptions, 'analyzer:strong-mode:implicit-dynamic', true);

  final StringBuffer sb = new StringBuffer('''
# Generated with ❤ by abide https://github.com/Workiva/abide
# Lint rules are based on the linter package version $linterVersion
# To find the latest version of the linter package visit https://pub.dartlang.org/packages/linter
#
# analysis_options.yaml docs: https://www.dartlang.org/guides/language/analysis-options 
''');
  if (currentInclude != null && currentInclude.isNotEmpty) {
    sb.writeln('include: $currentInclude');
  }
  sb.write('''
analyzer:
  # Strong mode is required. Applies to the current project.
  strong-mode:
    # When compiling to JS, both implicit options apply to the current 
    # project and all dependencies. They are useful to find possible 
    # Type fixes or areas for explicit typing.
    implicit-casts: $currentImplicitCasts
    implicit-dynamic: $currentImplicitDynamic
''');
  // Include the current analysis options errors config
  final YamlMap currentErrors =
      getYamlValue(currentAnalysisOptions, 'analyzer:errors');
  if (currentErrors != null) {
    final List<String> errKeys =
        currentErrors.keys.map<String>((k) => k.toString()).toList();
    if (errKeys.isNotEmpty) {
      sb.write('  errors:\n');
      errKeys.sort();
      for (String errKey in errKeys) {
        sb.write('    $errKey: ${currentErrors[errKey]}\n');
      }
    }
  }
  // Include the current analysis options exclude config
  final YamlList currentExcludes =
      getYamlValue(currentAnalysisOptions, 'analyzer:exclude');
  if (currentExcludes != null) {
    sb.write('  exclude:\n');
    for (String key in currentExcludes) {
      sb.write('    - "$key"\n');
    }
  }

  final StringBuffer errors = new StringBuffer();
  final StringBuffer output = new StringBuffer();

  int nMissingRecommendations = 0;
  final List<String> lintKeys = getTopLevelYamlKeys(abideYaml);
  for (String lint in lintKeys) {
    String recommendation = getYamlValue(abideYaml, '$lint:recommendation', '');
    final String reason = getYamlValue(abideYaml, '$lint:reason', '');
    final String docsLink = getYamlValue(abideYaml, '$lint:docs', '');
    final String description =
        getYamlValue(abideYaml, '$lint:description', lint);
    if (recommendation.isEmpty) {
      print('Missing recommendation for "$lint". Using "optional".');
      nMissingRecommendations++;
      recommendation = 'optional';
    }
    // ignore: prefer_interpolation_to_compose_strings
    final RegExp commentedOutLintRule = new RegExp(r'^\s*#+\s*-\s+' + lint,
        multiLine: true, caseSensitive: false);
    final bool avoid = recommendation == 'avoid';
    final bool required = recommendation == 'required';
    final bool wasPresentCommented =
        commentedOutLintRule.hasMatch(currentAnalysisOptionsString);
    final bool wasPresent =
        getYamlValue(currentAnalysisOptions, 'linter:rules:$lint');

    String issues = _lintResultFor(lint, lintErrorCounts);
    final bool hasIssues = issues.isNotEmpty;
    if (issues.isEmpty) {
      issues = '0 issues';
    }

    // preserve previous commented out state by default
    bool shouldCommentOut = wasPresentCommented;

    // comment out if there are existing lint issues
    if (hasIssues) {
      shouldCommentOut = true;
      if (wasPresent && !all) {
        print(
            '$lint commented out because it is has $issues that need fixing.');
      }
    }
    if (!all && !hasIssues && !required && !avoid && wasPresentCommented) {
      if (uncommentClean) {
        print('$lint uncommented because it has $issues (--uncomment-clean).');
      } else {
        print('$lint has $issues and could be uncommented if you like.');
      }
    }
    // uncomment required rules always
    if (required) {
      shouldCommentOut = false;
      if (wasPresentCommented && !all) {
        print('$lint uncommented because it is required. $issues need fixing.');
      }
    }
    // comment out avoid rules always
    if (avoid) {
      shouldCommentOut = true;
      if (wasPresent && !all) {
        print('$lint commented out because it is marked "avoid".');
      }
    }

    // allow override to uncomment everything
    if (all) {
      shouldCommentOut = false;
    }
    output
      ..write('    # $description\n')
      ..write('    # $docsLink\n')
      ..write('    # recommendation: $recommendation\n');
    if (reason.isNotEmpty) {
      output.write('    # reason: $reason\n');
    }
    String fixme = hasIssues && !avoid ? 'FIXME: ' : '';
    output
      ..write('    # $fixme$issues\n')
      ..write('    ${shouldCommentOut ? "# " : ""}- $lint\n\n');
  }
  if (errors.isNotEmpty) {
    sb.write('  errors:\n$errors');
  }
  if (output.isNotEmpty) {
    sb.write('''

# ALL lint rules are included. Unused lints should be commented
# out with a reason. An up to date list of all options is here
# http://dart-lang.github.io/linter/lints/options/options.html
# Descriptions of each rule is here http://dart-lang.github.io/linter/lints/
#
# To ignore a lint rule on a case by case basic in code just add a comment
# above it or at the end of the line like: // ignore: <linter rule>
# example: // ignore: invalid_assignment, const_initialized_with_non_constant_value
#
# More info about configuring analysis_options.yaml files
# https://www.dartlang.org/guides/language/analysis-options#excluding-lines-within-a-file
linter:
  rules:
$output
''');
  }
  String finalOutput = sb.toString();
  if (writeToFile) {
    new File(analysisOptionsFilename).writeAsStringSync(finalOutput);
  }
  if (!all) {
    print('Wrote $analysisOptionsFilename');
  }
  if (nMissingRecommendations > 0) {
    print(
        'There were missing recommendations. Please inform the maintainers of the abide tool to perform an abide upgrade.');
  }
  return finalOutput;
}

String _lintResultFor(String lint, Map<String, Map<String, int>> lintErrors) {
  String msg = '';
  if (lintErrors.containsKey(lint)) {
    for (String type in lintErrors[lint].keys) {
      final int count = lintErrors[lint][type];
      msg = '$msg $count $type(s)'.trim();
    }
  }
  return msg;
}

Future<Map<String, Map<String, int>>> getLintErrorCounts(
    {YamlMap abideYaml}) async {
  final Map<String, Map<String, int>> results = <String, Map<String, int>>{};

  // run the analyzer, count the number of errors for each lint rule
  final List<String> args = _findFilesFromEntryPoints(<String>[
    'lib',
    'test',
    'tool',
    'bin',
    'example',
    'test/unit',
    'test/functional'
  ]);

  if (args.isEmpty) {
    return results;
  }

  print('Running: dartanalyzer ${args.join(" ")}');

  final ProcessResult pr = await Process.run('dartanalyzer', args);
  print('');
  for (String line in pr.stdout.split('\n')) {
    try {
      if (!line.contains('•')) {
        continue;
      }
      final List<String> fields = line.split('•');

      if (fields.isEmpty) {
        continue;
      }

      final String type = fields[0].trim();
      final String lint = fields[2].trim();
      if (!results.containsKey(lint)) {
        results[lint] = <String, int>{};
        results[lint][type] = 0;
      }
      results[lint][type]++;
      // ignore: avoid_catches_without_on_clauses
    } catch (x) {
      print(x);
      continue;
    }
  }
  return results;
}

List<String> _findFilesFromEntryPoints(List<String> entryPoints) {
  final List<String> files = <String>[];
  for (String p in entryPoints) {
    if (FileSystemEntity.isDirectorySync(p)) {
      final Directory dir = new Directory(p);
      final List<FileSystemEntity> entities = dir.listSync();
      files.addAll(entities
          .where((FileSystemEntity e) =>
              FileSystemEntity.isFileSync(e.path) && e.path.endsWith('.dart'))
          .map((FileSystemEntity e) => e.path));
    } else if (FileSystemEntity.isFileSync(p) && p.endsWith('.dart')) {
      files.add(p);
    }
  }
  return files;
}
