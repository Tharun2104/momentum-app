# Momentum App

Momentum is a running and fitness tracking app built with Flutter for iOS and web. This repository contains the frontend app. The local backend lives in the sibling `momentum-api` repository.

## Prerequisites

- Flutter SDK installed and available on `PATH`.
- Xcode installed for iOS simulator and physical iPhone development.
- Docker Desktop running for the local backend.
- A connected iPhone or an iOS simulator for mobile testing.
- Apple development signing set up in Xcode for physical iPhone testing.

Check the available devices:

```bash
flutter devices
```

## Backend

Start the backend before testing run save flows:

```bash
cd "../momentum-api"
docker compose up -d
curl http://localhost:8080/health
```

The expected health response is:

```text
Momentum API hero is running
```

## Local Backend Testing

The Flutter app reads the backend URL from `API_BASE_URL`. If no value is
provided, it defaults to `http://localhost:8080`.

### Chrome / Web

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

### iPhone on Same Wi-Fi

1. Find Mac IP:

   ```bash
   ipconfig getifaddr en0
   ```

2. Run:

   ```bash
   flutter run -d <iphone-device-id> --dart-define=API_BASE_URL=http://<MAC_IP>:8080
   ```

### iPhone Using ngrok

1. Start backend:

   ```bash
   cd ../momentum-api
   ./mvnw spring-boot:run
   ```

2. Start ngrok:

   ```bash
   ngrok http 8080
   ```

3. Copy HTTPS URL:

   ```text
   https://abc123.ngrok-free.app
   ```

4. Run Flutter:

   ```bash
   flutter run -d <iphone-device-id> --dart-define=API_BASE_URL=https://abc123.ngrok-free.app
   ```

Notes:

- The ngrok URL changes each time unless using a reserved domain.
- The backend must still be running locally.
- The PostgreSQL Docker container must still be running locally.
- The iPhone needs internet access.
- No same Wi-Fi connection is required when using ngrok.

## Install Dependencies

From this `momentum-app` directory:

```bash
flutter pub get
```

## Run The App

Use the helper scripts in `tool/` so the API base URL is set correctly for each device.

### Physical iPhone

This is the primary testing path.

```bash
./tool/run_phone.sh
```

The script auto-detects the Mac Wi-Fi IP and passes it to Flutter as `API_BASE_URL`, because `localhost` on a real iPhone points to the phone, not the Mac.

If auto-detection fails, pass the Mac IP manually:

```bash
API_HOST=192.168.1.9 ./tool/run_phone.sh
```

### Chrome

```bash
./tool/run_chrome.sh
```

Chrome uses:

```text
http://localhost:8080
```

### iOS Simulator

```bash
./tool/run_simulator.sh
```

The simulator also uses:

```text
http://localhost:8080
```

## Physical iPhone Signing

Physical iPhone deployment requires Apple development signing.

Open the iOS workspace:

```bash
open ios/Runner.xcworkspace
```

Then in Xcode:

1. Select the `Runner` project.
2. Select the `Runner` target.
3. Open `Signing & Capabilities`.
4. Enable `Automatically manage signing`.
5. Select your Apple ID or Personal Team.
6. Keep the bundle identifier unique, currently `com.mttauto.momentumApp`.
7. Build once from Xcode or run `./tool/run_phone.sh`.

If the phone blocks the installed app, trust the certificate on the device:

```text
Settings > General > VPN & Device Management > Developer App > Trust
```

## Run Tracking Flow

The current app implements run recording and saved run review:

1. Open the app.
2. Tap `Run`.
3. Tap `Start` and allow When-In-Use location permission.
4. Move outdoors for better GPS accuracy.
5. Tap `Stop`.
6. Confirm the saved run summary appears.
7. Tap `History` from Home to review saved runs.
8. Tap a saved run to open Run Detail.

The app collects accepted GPS points in memory and sends one completed run payload to:

```text
POST /api/runs
```

Chrome keeps a lightweight sample-route test mode for quick backend smoke tests. Real GPS behavior should be verified on a physical iPhone. Background tracking and maps are intentionally not implemented yet.

For local physical iPhone testing, keep the iPhone able to reach the Mac backend. The normal setup is Mac and iPhone on the same Wi-Fi, with `./tool/run_phone.sh` passing the Mac LAN IP as `API_BASE_URL`.

## Verification

Run static analysis and tests:

```bash
flutter analyze
flutter test
```

## Documentation

- [Initial plan](docs/initial-plan.md)
