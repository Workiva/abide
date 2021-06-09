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

@TestOn('vm')
import 'package:test/test.dart';

import 'package:abide/src/util.dart';

void main() {
  group('Utility method getFileNamesFromCommandLine', () {
    const String badCommand = 'some command';
    const String commentedCommand =
        '#hey && ./foo.sh && ./bar.sh && dart baz.dart';
    const String commentWithinCommandDart =
        'hey && dart foo.dart && #./bar.sh && dart baz.dart';
    const String commentWithinCommandScript =
        'hey && ./foo.sh && #&& ./bar.sh && dart baz.dart';
    const String goodDartCommand = 'dart foo.dart';
    const String goodScriptCommand = './foo.sh';
    const String multipleCommandsOnSingleLine =
        'hey && ./foo.sh && ./bar.sh && dart baz.dart';

    test('returns nothing when command does not contain dart or script files',
        () {
      final Iterable<String> results = getFileNamesFromCommandLine(badCommand);
      expect(results, isEmpty);
    });

    test('returns nothing when command is commented', () {
      final Iterable<String> results =
          getFileNamesFromCommandLine(commentedCommand);
      expect(results, isEmpty);
    });

    test('returns dart file name when command contains a dart file', () {
      final Iterable<String> results =
          getFileNamesFromCommandLine(goodDartCommand);
      expect(results.length, 1);
      expect(results.contains('foo.dart'), isTrue);
    });

    test('returns script file name when command contains a script file', () {
      final Iterable<String> results =
          getFileNamesFromCommandLine(goodScriptCommand);
      expect(results.length, 1);
      expect(results.contains('./foo.sh'), isTrue);
    });

    test(
        'returns all dart and script file names when command has multiple commands on a single line',
        () {
      final Iterable<String> results =
          getFileNamesFromCommandLine(multipleCommandsOnSingleLine);
      expect(results.length, 3);
      expect(results.contains('./foo.sh'), isTrue);
      expect(results.contains('./bar.sh'), isTrue);
      expect(results.contains('baz.dart'), isTrue);
    });

    test(
        'returns uncommented dart file names when command has mid-line comment',
        () {
      final Iterable<String> results =
          getFileNamesFromCommandLine(commentWithinCommandDart);

      expect(results.length, 1);
      expect(results.contains('foo.dart'), isTrue);
      expect(results.contains('./bar.sh'), isFalse);
      expect(results.contains('baz.dart'), isFalse);
    });

    test(
        'returns uncommented script file names when command has mid-line comment',
        () {
      final Iterable<String> results =
          getFileNamesFromCommandLine(commentWithinCommandScript);

      expect(results.length, 1);
      expect(results.contains('./foo.sh'), isTrue);
      expect(results.contains('./bar.sh'), isFalse);
      expect(results.contains('baz.dart'), isFalse);
    });
  });
}
