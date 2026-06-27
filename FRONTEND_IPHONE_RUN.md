# Run Momentum App on iPhone

The Flutter app reads the backend URL from `API_BASE_URL`. For a physical iPhone, use the deployed Render URL. Do not use `localhost`, because `localhost` on an iPhone means the iPhone itself.

## Run on a physical iPhone

From the `momentum-app` folder:

```bash
flutter clean
flutter pub get
flutter devices
flutter run -d <iphone_id> --dart-define=API_BASE_URL=https://YOUR_RENDER_SERVICE.onrender.com
```

Replace `https://YOUR_RENDER_SERVICE.onrender.com` with the URL Render gives your backend Web Service.

## Release build later

When the Render URL is final, build iOS with the same define:

```bash
flutter build ios --release --dart-define=API_BASE_URL=https://YOUR_RENDER_SERVICE.onrender.com
```

Archive and distribute from Xcode after the release build.

## iOS signing notes

The current iOS bundle identifier is `com.mttauto.momentumApp`. The minimum iOS deployment target is `15.0`.

Open `ios/Runner.xcworkspace` in Xcode and confirm:

```text
Runner target > Signing & Capabilities > Team
Runner target > Signing & Capabilities > Bundle Identifier
```

Do not change the signing team in source unless you intentionally want to commit a different Apple Developer Team.

## iOS permissions

The app already has `NSLocationWhenInUseUsageDescription` for run/GPS tracking. It does not currently request always-on location, so `NSLocationAlwaysAndWhenInUseUsageDescription` is not needed.
