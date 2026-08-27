# Elastic (NT3)

[![Elastic NT3](https://github.com/kimseungsu-zzz/elastic-NT3/actions/workflows/nt3-ci.yml/badge.svg)](https://github.com/kimseungsu-zzz/elastic-NT3/actions/workflows/nt3-ci.yml)

A desktop-focused fork of Elastic Dashboard for FRC robots that use the
NetworkTables 3.0 protocol.

The NT3 transport uses TCP port 1735. Because browsers cannot open raw TCP
sockets, robot connectivity is supported on Windows, macOS, and Linux builds.

## About

Elastic (NT3) is intended for FRC robot projects using NetworkTables 3. It can
be used as a competition driver dashboard or for testing. The application
contains only the NT3 transport and NT3-compatible topic types.

Core dashboard features include:
* Customizable color scheme with over 20 variants
* Optimized camera streams which automatically deactivate when not in use
* Automatic height resizing to the FRC Driver Station

![Example Layout](/screenshots/example_layout.png)

## Building and Contributing
View the instructions for building code and making contributions to the project in the [CONTRIBUTING.md](CONTRIBUTING.md) file

## Special Thanks

This dashboard wouldn't have been made without the help and inspiration from the following people

* [Michael Jansen](https://github.com/mjansen4857) from Team 3015
* [Jonah](https://github.com/jwbonner) from Team 6328
* [Oh yes 10 FPS](https://github.com/oh-yes-0-fps) from Team 3173
* [Jason](https://github.com/jasondaming) and [Peter](https://github.com/PeterJohnson) from WPILib
* All mentors and advisors of Team 353, the POBots

## Contributors

<a href="https://github.com/Gold872/elastic_dashboard/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=Gold872/elastic_dashboard" />
</a>
