# ReadBox iOS

This folder contains the Swift source for the third-stage ReadBox iOS MVP:

- A SwiftUI app for settings, unread/read/favorite lists, reading, favorite toggling, deleting, and manual URL saving.
- A Share Extension that accepts `public.url` and `public.plain-text`, extracts the first HTTP(S) URL from text, and posts it to `POST /api/items` with `source = ios_share`.
- Shared settings stored in App Group `UserDefaults` so the app and extension use the same API Base URL and token.

## Xcode Setup

This folder includes an XcodeGen spec and a generated Xcode project:

```text
ios/ReadBox.xcodeproj
```

Open it directly:

```bash
open ios/ReadBox.xcodeproj
```

If you change the file layout later, regenerate the project with:

```bash
cd ios
xcodegen generate --spec project.yml
```

Manual fallback if you prefer to create the project yourself:

1. Create an iOS App target named `ReadBox`.
2. Create a Share Extension target named `ReadBoxShareExtension`.
3. Add `ios/ReadBox/*.swift` to the app target.
4. Add `ios/ReadBoxShareExtension/*.swift` to the share extension target.
5. Add `ios/Shared/*.swift` to both targets.
6. Use `ios/ReadBox/Info.plist` for the app target if Xcode is not generating Info settings.
7. Use `ios/ReadBoxShareExtension/Info.plist` for the extension target.

## App Group

The placeholder App Group is:

```text
group.com.example.readbox
```

Before building on a real device:

1. Change `ReadBoxSettings.appGroupID` in `ios/Shared/SettingsStore.swift`.
2. Change both entitlements files:
   - `ios/ReadBox/ReadBox.entitlements`
   - `ios/ReadBoxShareExtension/ReadBoxShareExtension.entitlements`
3. In Xcode, enable App Groups for both targets and select the same group.
4. Set matching bundle identifiers that your Apple developer account or AltStore workflow can sign.

## Local Network Notes

For local testing from an iPhone, use a LAN-reachable server URL such as:

```text
http://192.168.1.20:8000
```

`localhost` on the phone points to the phone itself, not your Mac or server.

For plain HTTP during development, configure App Transport Security in Xcode if needed. Production/self-hosted use should prefer HTTPS.

## AltStore Sideloading

1. Open the Xcode project after adding the files above.
2. Select your signing team or personal account.
3. Confirm both the app and Share Extension targets build.
4. Archive or build the app for your device.
5. Use AltStore/AltServer with your signed IPA according to your normal sideloading flow.

The source here intentionally avoids complex offline caching, background sync, account systems, annotation, and AI features. It only completes the ReadBox save/read/mark loop on iOS.
