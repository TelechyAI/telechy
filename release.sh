#!/usr/bin/env bash
set -euo pipefail

# Telechy Release Script
# Usage: ./release.sh <version>
# Example: ./release.sh 0.5.7

if [ $# -eq 0 ]; then
    echo "❌ Error: Version number required"
    echo "Usage: $0 <version>"
    echo "Example: $0 0.5.7"
    exit 1
fi

VERSION="$1"
TAG="v$VERSION"
APP_NAME="telechy"

echo "🚀 Preparing Telechy release $TAG"

# Expected files (no version in filename)
UPDATER_BUNDLE="Telechy.app.tar.gz"
SIGNATURE_FILE="Telechy.app.tar.gz.sig"
APP_BUNDLE="Telechy.app"
LATEST_JSON="latest.json"

# Check if required files exist
echo "📋 Checking required files..."
for file in "$UPDATER_BUNDLE" "$SIGNATURE_FILE" "$LATEST_JSON" "$APP_BUNDLE"; do
    if [ ! -f "$file" ] && [ ! -d "$file" ]; then
        echo "❌ Error: Required file '$file' not found"
        echo "Expected files:"
        echo "  - Telechy.app.tar.gz (updater bundle)"
        echo "  - Telechy.app.tar.gz.sig (signature file)"
        echo "  - latest.json (update manifest)"
        echo "  - Telechy.app (app bundle for manual install)"
        exit 1
    fi
done

echo "✅ All required files found"

# Read signature content
echo "🔐 Reading signature from $SIGNATURE_FILE..."
SIGNATURE_CONTENT=$(cat "$SIGNATURE_FILE")
if [ -z "$SIGNATURE_CONTENT" ]; then
    echo "❌ Error: Signature file is empty"
    exit 1
fi

echo "✅ Signature loaded (${#SIGNATURE_CONTENT} characters)"

# Update latest.json with signature and version
echo "📝 Updating $LATEST_JSON..."
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create temporary JSON with updated values
cat > temp_latest.json << EOF
{
  "version": "$TAG",
  "notes": "Telechy $TAG release with bug fixes and improvements",
  "pub_date": "$CURRENT_DATE",
  "platforms": {
    "darwin-aarch64": {
      "signature": "$SIGNATURE_CONTENT",
      "url": "https://github.com/TelechyAI/telechy/releases/download/$TAG/$UPDATER_BUNDLE"
    },
    "darwin-x86_64": {
      "signature": "$SIGNATURE_CONTENT",
      "url": "https://github.com/TelechyAI/telechy/releases/download/$TAG/$UPDATER_BUNDLE"
    }
  }
}
EOF

# Replace the original latest.json
mv temp_latest.json "$LATEST_JSON"
echo "✅ Updated $LATEST_JSON with version $TAG and current signature"

# Check if GitHub CLI is available
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) is not installed"
    echo "Install it with: brew install gh"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Error: Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI ready"

# Prepare release assets
RELEASE_ASSETS=(
    "$UPDATER_BUNDLE#macOS Updater Bundle"
    "$SIGNATURE_FILE#Bundle Signature"
    "$LATEST_JSON#Updater Manifest"
)

# Compress app bundle for upload (GitHub can't upload directories)
APP_ZIP="Telechy_${VERSION}.app.zip"
echo "📦 Compressing $APP_BUNDLE to $APP_ZIP..."
if [ -f "$APP_ZIP" ]; then
    rm "$APP_ZIP"
fi
zip -r -q "$APP_ZIP" "$APP_BUNDLE"
echo "✅ Created $APP_ZIP"

# Add compressed app bundle
RELEASE_ASSETS+=("$APP_ZIP#macOS App (Manual Install)")
echo "📦 Including $APP_ZIP for manual installation"

# Create GitHub release
echo "🚀 Creating GitHub release $TAG..."
gh release create "$TAG" \
    "${RELEASE_ASSETS[@]}" \
    --title "Telechy $VERSION" \
    --generate-notes

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Release $TAG created successfully!"
    echo "📍 View at: https://github.com/TelechyAI/telechy/releases/tag/$TAG"
    echo "🔄 Updater endpoint: https://github.com/TelechyAI/telechy/releases/latest/download/latest.json"
    
    # Clean up build files after successful release
    echo ""
    echo "🧹 Cleaning up build files..."
    rm -f "$UPDATER_BUNDLE"
    rm -f "$SIGNATURE_FILE"
    rm -f "$APP_ZIP"
    rm -rf "$APP_BUNDLE"
    echo "✅ Removed build artifacts:"
    echo "  - $UPDATER_BUNDLE"
    echo "  - $SIGNATURE_FILE"
    echo "  - $APP_ZIP"
    echo "  - $APP_BUNDLE"
    
    echo ""
    echo "🔍 Verify the release:"
    echo "  - Check that all assets uploaded correctly"
    echo "  - Test the updater endpoint responds with the new version"
    echo "  - Verify app can detect and install the update"
else
    echo "❌ Failed to create release"
    echo "🗂️ Build files left in place for debugging"
    exit 1
fi
