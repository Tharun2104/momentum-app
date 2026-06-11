# Momentum Frontend Initial Plan

## Overall Goal

Momentum will be a full-stack productivity and progress tracking app available on iOS and web. The frontend goal is to provide a shared Flutter client that delivers the main user experience across both platforms while connecting to the Momentum API backend.

## Frontend Scope

- Build one Flutter app that can run on iOS and web.
- Keep screens and services organized as features are added.
- Connect client workflows to backend APIs through a dedicated service layer.
- Maintain platform run commands for quick local testing.
- Keep the initial setup simple until the core product flows are decided.

## Initial Frontend Commands

Install dependencies:

```bash
flutter pub get
```

Run the web app:

```bash
flutter run -d chrome
```

Run the iOS app:

```bash
flutter run -d ios
```

## Early Work Plan

- Confirm the first user workflow before adding more screens.
- Keep API calls isolated in service classes.
- Add shared UI structure only when repeated patterns appear.
- Test on both web and iOS as core behavior is introduced.
