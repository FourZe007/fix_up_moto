#!/bin/bash
# Run this after a long gap (weeks/months) before `flutter run` to prevent
# EXC_BAD_ACCESS crashes caused by stale build artifacts on iOS devices.
set -e

echo "==> flutter clean"
flutter clean

echo "==> flutter pub get"
flutter pub get

echo "==> Clear Xcode DerivedData"
rm -rf ~/Library/Developer/Xcode/DerivedData

echo "==> CocoaPods deintegrate + fresh install"
cd ios
pod deintegrate
pod cache clean --all
pod install --repo-update
cd ..

echo ""
echo "Done. Run: flutter run"
