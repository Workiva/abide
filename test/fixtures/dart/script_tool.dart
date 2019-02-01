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

library script_tool;

import 'dart:async';
import 'dart:io';

Future<ProcessResult> run(String command,
    {List<String> additionalArgs: const <String>[],
    String workingDirectory,
    String outputFile,
    bool exitOnCompletion: false,
    bool exitOnFailure: true}) async {
  final StringBuffer fullCommand = new StringBuffer('$command ')
    ..writeAll(additionalArgs, ' ');
  final List<String> splitCommand = command.split(' ')..addAll(additionalArgs);
  final String executable = splitCommand.removeAt(0);
  final String dir = workingDirectory ?? Directory.current.path;
  print('Running "$fullCommand" in $dir directory.');
  final ProcessResult result =
      await Process.run(executable, splitCommand, workingDirectory: dir);
  if ((result.exitCode != 0 && exitOnFailure) || exitOnCompletion) {
    exit(result.exitCode);
  }
  return result;
}
