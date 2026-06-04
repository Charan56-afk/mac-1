#!/bin/bash

# iOS Build Script for Flutter - Appetize Ready
# This script builds the Flutter app for iOS simulator and creates a .zip file for Appetize
# Appetize requires: .zip or .tar.gz containing a compressed .app bundle

set -e

echo "==================================="
echo "Flutter iOS Build Script (Appetize Ready)"
echo "==================================="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    exit 1
fi

# Parse arguments
BUILD_TYPE="${1:-simulator}"  # simulator or release
OUTPUT_DIR="${2:-build/ios}"

echo "📱 Build Type: $BUILD_TYPE"
echo "📁 Output Directory: $OUTPUT_DIR"

# Step 1: Clean previous builds
echo ""
echo "🧹 Cleaning previous builds..."
flutter clean

# Step 2: Get dependencies
echo ""
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Step 3: CocoaPods setup
echo ""
echo "📚 Setting up CocoaPods..."
cd ios
pod install --repo-update
cd ..

# Step 4: Build iOS app
echo ""
echo "🔨 Building iOS app..."

if [ "$BUILD_TYPE" = "simulator" ]; then
    echo "📱 Building for iOS Simulator..."
    flutter build ios --simulator --debug --no-codesign
    APP_PATH="build/ios/iphonesimulator"
    APP_NAME="Runner.app"
elif [ "$BUILD_TYPE" = "release" ]; then
    echo "📱 Building for iOS Device (Release)..."
    flutter build ios --release
    APP_PATH="build/ios/iphoneos"
    APP_NAME="Runner.app"
else
    echo "❌ Unknown build type: $BUILD_TYPE"
    echo "Usage: ./scripts/build_ios.sh [simulator|release]"
    exit 1
fi

# Step 5: Verify build output
echo ""
echo "✅ Build completed!"

if [ -d "$APP_PATH/$APP_NAME" ]; then
    echo "✓ App bundle found at: $APP_PATH/$APP_NAME"
    echo ""
    echo "📊 App Size:"
    du -sh "$APP_PATH/$APP_NAME"
    
    # Step 6: Create zip for Appetize (Appetize requires .zip or .tar.gz)
    if [ "$BUILD_TYPE" = "simulator" ]; then
        echo ""
        echo "📦 Creating Appetize-compatible .zip file..."
        
        cd "$APP_PATH"
        
        # Remove existing zip if it exists
        if [ -f "$APP_NAME.zip" ]; then
            rm "$APP_NAME.zip"
        fi
        
        # Create the zip file with the .app bundle inside
        # This creates: Runner.app.zip containing Runner.app/
        zip -r "$APP_NAME.zip" "$APP_NAME" > /dev/null 2>&1
        
        FULL_ZIP_PATH="$(pwd)/$APP_NAME.zip"
        
        echo "✓ Zip created: $FULL_ZIP_PATH"
        echo ""
        echo "📊 Zip Size:"
        du -sh "$APP_NAME.zip"
        echo ""
        
        # Verify zip contains the .app bundle
        echo "📋 Zip contents:"
        unzip -l "$APP_NAME.zip" | head -20
        
        echo ""
        echo "🎉 Appetize Ready! File: $FULL_ZIP_PATH"
        echo ""
        echo "📤 Upload to Appetize:"
        echo "1. Go to: https://appetize.io"
        echo "2. Click 'Upload an app' or drag-and-drop"
        echo "3. Upload: $FULL_ZIP_PATH"
        echo "4. Wait for processing"
        echo "5. Share the public link"
        
        cd - > /dev/null
    else
        echo ""
        echo "ℹ️  For device deployment, use Xcode:"
        echo "   open ios/Runner.xcworkspace"
    fi
else
    echo "❌ App bundle not found at: $APP_PATH/$APP_NAME"
    echo "Please check the build logs above for errors."
    exit 1
fi

echo ""
echo "==================================="
echo "✅ Build process completed!"
echo "==================================="
echo ""
