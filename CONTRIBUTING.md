# Contributing to Elastic (NT3)

Thank you for contributing to Elastic (NT3). This fork is focused on a stable,
desktop NetworkTables 3 dashboard.

This document provides a set of guidelines to help you contribute to the project.

## Ways to Contribute

- **Bug Reports:** Open a [bug report](https://github.com/kimseungsu-zzz/elastic-NT3/issues/new?template=bug_report.md).
- **Enhancements:** Open a [feature request](https://github.com/kimseungsu-zzz/elastic-NT3/issues/new?template=feature_request.md).
- **Code Contributions:** If you'd like to fix a bug or implement a feature, please follow the workflow described below.

## Contribution Workflow

To ensure a standardized process, please follow this development workflow:

1. **Fork the Repository:** Start by [forking this repository](https://github.com/kimseungsu-zzz/elastic-NT3/fork).
2. **Create a Branch:** Create a new branch from `main` in your fork for your changes. Use a descriptive name, such as `fix-connection-error` or `add-new-widget`.
    ```bash
    git checkout -b <your-branch-name>
    ```
3. **Make Changes:** Write your code and any necessary tests.
4. **Commit Your Changes:** Commit your work with clear and concise commit messages.
5. **Push to Your Fork:** Push your branch to your forked repository.
    ```bash
    git push origin <your-branch-name>
    ```
6. **Open a Pull Request:** Open a pull request against the `main` branch of
   Elastic (NT3). Explain the change and link relevant issues.

## Building from Source

### Flutter App

Elastic (NT3) requires Flutter 3.47.1 or a compatible stable release and the
platform-specific desktop dependencies described in the
[Flutter documentation](https://docs.flutter.dev/get-started).

Once Flutter is installed, download the package dependencies:
```bash
flutter pub get
```

To build and run the desktop app for debugging:
```bash
flutter run -d <PLATFORM>
```

To create a release build:
```bash
flutter build <PLATFORM>
```
* The output executable will be located in:
    * Windows: `<PROJECT DIR>/build/windows/x64/runner/Release`
    * macOS: `<PROJECT DIR>/build/macos/Build/Products/Release`
    * Linux: `<PROJECT DIR>/build/linux/x64/release/bundle`

## Running Unit Tests

Elastic (NT3) uses Flutter's test framework and Mockito.

First, generate the necessary mock classes:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Then, execute all automated unit tests:
```bash
flutter test --concurrency=1
```

## Pull Request Checklist

Before submitting a pull request, please ensure you have completed the following:

- All unit tests pass successfully:
    ```bash
    flutter test --concurrency=1
    ```
- All files are formatted according to the Dart style guide. Run the following commands to format your code:
    ```bash
    dart format lib test
    ```
- The code is free of any static analysis warnings or errors. Apply fixes and analyze your code:
    ```bash
    flutter analyze
    ```
- Your pull request has a clear title and a detailed description.
- You have linked the pull request to any relevant issues.

## Licensing

By contributing to Elastic (NT3), you agree that your contributions will be
licensed under the project [MIT License](LICENSE). Preserve upstream notices
and update [NOTICE.md](NOTICE.md) when adding code with separate attribution
requirements.
