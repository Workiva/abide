# Abide

A command line tool to manage `analysis_options.yaml` and check if it abides by requirements.
This project is meant to be a tool for both local and CI use.

## What does it do?

### Running `abide` will check for these recommendations

- You should have abide installed in dev_dependencies in pubspec.yaml.
- You should have 'pub run abide' command as part of the CI run.
- You should have an `analysis_options.yaml`.
- `.analysis_options` should be renamed to `analysis_options.yaml`
- You should have **strong mode** set.
- You **must** have the *required* lints from [abide.yaml](lib/abide.yaml).
- You **must not** have *avoid* lint rules from [abide.yaml](lib/abide.yaml).
- You are encouraged to use the *recommended* lints.
- *Optional* lints are ignored by this tool. It's up to you or your team to decide if you want to use them.

> If you include the flag `--json` (or `-j` for short), it writes `abide.json` in the current directory with the results of analysis. This file can be used for further tooling or to report to a datastore for querying. You might consider adding `abide.json` to your `.gitignore` if it bothers you.

### Running `abide update` creates or updates your  `analysis_options.yaml` with all the recommended options set

- Rename .analysis_options to analysis_options.yaml
- It **WILL** modify your existing analysis_options.yaml file in the current directory if it exists.
- It will preserve any customizations you've added under analyzer -> errors.
- It will add ALL lint rules that exist, commenting out the ones to be avoided.
- It includes descriptions, recommendations (required, optional, avoid) and the reason for the recommendation.
- It will add a comment with the number of lints added by that rule. This let's you prioritize which lint rules to undertake fixing.
- It will auto-comment lint rules that
    1) have existing warnings in your code
    2) have a recommendation of recommended or optional
- with `--uncomment-clean` It will auto-uncomment lint rules that
    1) have no existing warnings in your code
    2) have a recommendation of recommended or optional

Example:
```yaml
    # Declare method return types.
    # recommendation: recommended
    # reason: React component render() method can return either ReactElement or false
    # FIXME: 1201 lint(s)
    # - always_declare_return_types
```

### Running `abide help` outputs

```bash
Usage: abide [command]
abide [--json|-j] (default: Checks that your analysis_options.yaml abides by recommendations)
abide update [--uncomment-clean|-c] (Updates your analysis_options.yaml with default recommendations)
abide help (shows this help)

--uncomment-clean will automatically uncomment recommended or optional rules that do not have any lints
  without this option, abide will attempt to preserve the state of any commented out rules.
```

## Installing

### As a dependency
Add it to your pubspec.yaml under dev_dependencies:
```
dev_dependencies:
  abide: ^1.6.0
```

This will allow you to `pub run abide` in this project directory. If you want to be
able to run abide on any project without updating project dependencies, use the
global install instructions below. You can install it both ways and run either
the project version or the global version
 - `pub run abide` - Runs the local project version
 - `pub global run abide` - Runs the globally installed version

### As a global install
1. To install or update to the latest version, run:
```
pub global activate abide
```

 2. It is highly recommended to add `~/.pub-cache/bin` to your system PATH to be able to run abide directly.
   - Without PATH set: `pub global run abide`
   - With PATH set: `abide` (much better)


<hr>
To install a local version, clone it from github and activate it from the current directory.

```
git clone git@github.com:Workiva/abide.git
cd abide
pub global activate --source path .
```

## Upgrading the lints in abide.yaml

For abide maintainers, there is an additional tool under `upgrade/` to automatically upgrade
the abide.yaml file with the latest lints directly from the code used in the linter package.
It is a separate tool with separate dependencies to not introduce the linter and analyzer
dependencies on the main abide project. It is best to get the latest lints by getting the
latest version of the linter package. The absolute latest is under Dart 2 (at the time of
this writing - March 2018). Maintainers should use the latest Dart 2 dev or stable release
to run abide_upgrade.

To use it, just globally activate it and run it in the abide root.

```bash
cd upgrade
pub global activate --source path .
cd ..
abide_upgrade
```
It will regenerate the lib/abide.yaml file with all the latest lints. It will preserve
any existing recommendations and reasons for existing lints and use `optional` for new lints.
After upgrading, review the abide.yaml for changes and make any needed changes to
recommendations for new lint rules.