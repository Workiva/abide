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

enum Environment { vm }

class TestRunnerConfig {
  TestRunnerConfig({Environment env, String directory}) {}
}

Future<Null> dev(List<String> args) {}

class Config {
  ConfigAnalyze analyze = new ConfigAnalyze();
  ConfigCopyLicense copyLicense = new ConfigCopyLicense();
  ConfigCoverage coverage = new ConfigCoverage();
  ConfigFormat format = new ConfigFormat();
  ConfigTaskRunner taskRunner = new ConfigTaskRunner();
  ConfigGenTestRunner genTestRunner = new ConfigGenTestRunner();
  ConfigTest test = new ConfigTest();
}

class ConfigAnalyze {
  List<String> entryPoints = [];
  bool strong;
  bool fatalWarnings;
}

class ConfigCopyLicense {
  List<String> directories = [];
}

class ConfigCoverage {
  bool html;
  bool pubServe;
}

class ConfigFormat {
  List<String> paths = [];
  List<String> exclude = [];
}

class ConfigTaskRunner {
  List<String> tasksToRun = [];
}

class ConfigGenTestRunner {
  List<TestRunnerConfig> configs = [];
}

class ConfigTest {
  List<String> unitTests = [];
  List<String> platforms = [];
}

Config config = new Config();
