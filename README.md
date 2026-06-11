# Momentum App

Momentum is a full-stack productivity and progress tracking experience for mobile and web. This repository contains the Flutter frontend that will run as the iOS app and web app while sharing one client codebase.

The frontend is built with Flutter and currently targets iOS, Android, and web. For the first development flow, we will use the iOS and web run commands below.

## Requirements

- Flutter SDK
- Xcode for iOS development
- A running Momentum API backend

## Run Locally

Install dependencies:

```bash
flutter pub get
```

Run the web app:

```bash
flutter run -d chrome
```

Run the mobile app on an iOS simulator or connected iPhone:

```bash
flutter run -d ios
```

If Flutter says no supported device was found for `ios`, start an iPhone simulator first:

```bash
open -a Simulator
flutter devices
flutter run -d ios
```

If only `macOS` and `Chrome` appear in `flutter devices`, there is no iOS simulator or iPhone available yet. Open Xcode, install the iOS platform if prompted, then start a simulator from Xcode or the Simulator app. Once an iPhone simulator is listed, `flutter run -d ios` will target it.

Run on a physical iPhone by connecting the device, trusting the Mac on the phone, opening `ios/Runner.xcworkspace` in Xcode, selecting your Apple development team, and then running:

```bash
flutter devices
flutter run -d ios
```

## Backend Connection

Start the backend from the `momentum-api` repository before using frontend flows that call the API.

## Documentation

- [Initial plan](docs/initial-plan.md)
