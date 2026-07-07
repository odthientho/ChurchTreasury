#!/bin/bash
# ChurchTreasury setup — generates the Xcode project with XcodeGen.
set -e

cd "$(dirname "$0")"

if ! command -v xcodegen &> /dev/null; then
    echo "Installing XcodeGen..."
    brew install xcodegen
fi

xcodegen generate

echo ""
echo "✅ Project generated: ChurchTreasury.xcodeproj"
echo ""
echo "Next steps:"
echo "  1. Open ChurchTreasury.xcodeproj in Xcode"
echo "  2. Select your Team under Signing & Capabilities (required for iCloud on a real device)"
echo "  3. Build & run"
