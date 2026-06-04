# iOS Build Instructions

This document provides step-by-step instructions for building the Flutter iOS app for simulator and Appetize.

## Prerequisites

- **Flutter SDK**: [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Xcode**: Version 12.0 or higher (for iOS 13.0+)
- **CocoaPods**: Usually installed with Xcode, or install via `gem install cocoapods`
- **macOS**: 10.15 or higher

## Quick Start

### Option 1: Using Build Script (Recommended)

```bash
# Make script executable
chmod +x scripts/build_ios.sh

# Build for simulator
./scripts/build_ios.sh simulator

# Build for device/release
./scripts/build_ios.sh release
```

### Option 2: Manual Build Commands

#### Step 1: Setup Flutter
```bash
flutter pub get
cd ios
pod install
cd ..
```

#### Step 2: Build for Simulator
```bash
flutter build ios --simulator --debug --no-codesign
```

Output location: `build/ios/iphonesimulator/Runner.app`

#### Step 3: Build for Device (Release)
```bash
flutter build ios --release
```

Output location: `build/ios/iphoneos/Runner.app`

#### Step 4: Create Zip for Appetize
```bash
cd build/ios/iphonesimulator
zip -r Runner.app.zip Runner.app
cd ../../..
```

## Appetize Deployment

### Upload to Appetize

1. Go to [Appetize.io](https://appetize.io)
2. Sign in to your account
3. Click "Upload an app"
4. Upload the zip file: `build/ios/iphonesimulator/Runner.app.zip`
5. Configure your app settings
6. Share the public link

### Appetize Configuration

Create an `appetize_config.json` file:

```json
{
  "platform": "ios",
  "app_path": "build/ios/iphonesimulator/Runner.app.zip",
  "bundle_id": "com.example.flutterApplication1",
  "size": "iphone12",
  "timeout": 600,
  "device_type": "iphone12"
}
```

## GitHub Actions CI/CD

The project includes an automated GitHub Actions workflow that:

1. ✅ Builds on every push to `main` or `develop`
2. ✅ Runs Flutter analysis
3. ✅ Builds iOS app for simulator
4. ✅ Creates zip file
5. ✅ Uploads artifacts
6. ✅ Displays build info

### View Build Artifacts

1. Go to your GitHub repository
2. Click "Actions"
3. Select the latest workflow run
4. Scroll down to "Artifacts"
5. Download the `ios-app` zip file

## Troubleshooting

### Issue: "No .app folder found"

**Solution:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios --simulator --debug --no-codesign
```

### Issue: "CocoaPods could not find compatible versions"

**Solution:**
```bash
cd ios
rm -rf Pods
rm -rf Podfile.lock
pod install
cd ..
flutter build ios --simulator --debug --no-codesign
```

### Issue: "Xcode build failed"

**Solution:**
```bash
# Clean Xcode build cache
xcode-select --reset
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios --simulator --debug --no-codesign
```

### Issue: "Runner.app size is too large"

**Solution:**
- Check for unnecessary dependencies in `pubspec.yaml`
- Use `flutter build ios --simulator --release` for optimized size
- Remove unused assets from `assets/` folder

## Build Output Locations

| Build Type | Output Path |
|-----------|------------|
| Simulator Debug | `build/ios/iphonesimulator/Runner.app` |
| Device Release | `build/ios/iphoneos/Runner.app` |
| Appetize Zip | `build/ios/iphonesimulator/Runner.app.zip` |

## Environment Variables

Add to `.env` or shell profile for automation:

```bash
export FLUTTER_CHANNEL=stable
export FLUTTER_VERSION=3.9.2
export IOS_PLATFORM_VERSION=13.0
```

## Additional Resources

- [Flutter iOS Build Documentation](https://flutter.dev/docs/deployment/ios)
- [Appetize.io Documentation](https://appetize.io/docs)
- [CocoaPods Troubleshooting](https://guides.cocoapods.org/using/troubleshooting.html)
- [Xcode Build Guide](https://developer.apple.com/xcode/)

## Support

For issues:
1. Check the troubleshooting section above
2. Review Flutter logs: `flutter logs`
3. Check Xcode build logs: `open ios/Pods/Target Support Files/Pods-Runner/Pods-Runner-acknowledgements.markdown`
4. Visit [Flutter Issues](https://github.com/flutter/flutter/issues)
