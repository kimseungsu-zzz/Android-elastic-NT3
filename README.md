# Elastic (NT3)

[![Elastic NT3](https://github.com/kimseungsu-zzz/elastic-NT3/actions/workflows/nt3-ci.yml/badge.svg)](https://github.com/kimseungsu-zzz/elastic-NT3/actions/workflows/nt3-ci.yml)

A desktop-focused fork of Elastic Dashboard for FRC robots that use the
NetworkTables 3.0 protocol.

The NT3 transport uses TCP port 1735. Because browsers cannot open raw TCP
sockets, robot connectivity is supported on Windows, macOS, Linux, and Android builds.

[Download the latest release](https://github.com/kimseungsu-zzz/elastic-NT3/releases/latest)

## About

Elastic (NT3) is intended for FRC robot projects using NetworkTables 3. It can
be used as a competition driver dashboard or for testing. The application
contains only the NT3 transport and NT3-compatible topic types.

Core dashboard features include:

* Customizable color scheme with over 20 variants
* Optimized camera streams which automatically deactivate when not in use
* Automatic height resizing to the FRC Driver Station

![Example Layout](/screenshots/example_layout.png)

## NetworkTables compatibility

The client implements the NT3 handshake and entry protocol over TCP port 1735.
It supports the NT3 boolean, double, string, raw, RPC, boolean array, double
array, and string array wire types.

This distribution does not include newer topic features that have no NT3 wire
representation. Saved layouts should therefore reference ordinary NT3 topics.

## Supported platforms

| Platform | Robot connection | Release build |
| --- | --- | --- |
| Windows | Supported | Yes |
| macOS | Supported | Yes |
| Linux | Supported | Yes |
| Android | Supported (landscape, tablets recommended) | Yes (APK) |
| Web | Not supported (browsers cannot open raw TCP sockets) | No |

## Build and test

Install Flutter 3.47.1 or a compatible stable release, then run:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --concurrency=1
flutter build windows --release
```

Replace `windows` with `macos` or `linux` for another desktop target.

For Android, run `dart run flutter_launcher_icons` once to generate the launcher
icons, then `flutter build apk --release`. Android has no window management, so
the custom title bar buttons, window-position memory, and "resize to Driver
Station" are desktop-only. The device must be on the robot network.
Additional contribution guidance is in [CONTRIBUTING.md](CONTRIBUTING.md).

## License and attribution

Elastic (NT3) is available under the [MIT License](LICENSE). Upstream and fork
attribution is documented in [NOTICE.md](NOTICE.md). The privacy policy is in
[PRIVACY.md](PRIVACY.md).

## Special Thanks

This fork builds on the work of the original Elastic Dashboard contributors
and the following people:

* [Michael Jansen](https://github.com/mjansen4857) from Team 3015
* [Jonah](https://github.com/jwbonner) from Team 6328
* [Oh yes 10 FPS](https://github.com/oh-yes-0-fps) from Team 3173
* [Jason](https://github.com/jasondaming) and [Peter](https://github.com/PeterJohnson) from WPILib
* All mentors and advisors of Team 353, the POBots

See the [upstream contributors](https://github.com/Gold872/elastic_dashboard/graphs/contributors)
and the [Elastic (NT3) contributors](https://github.com/kimseungsu-zzz/elastic-NT3/graphs/contributors).
