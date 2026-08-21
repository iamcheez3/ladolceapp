#!/bin/sh
# Injects GOOGLE_MAPS_API_KEY from the project's .env into the built Info.plist,
# mirroring the manifestPlaceholders setup in android/app/build.gradle.kts so
# .env stays the single source of truth for the key on both platforms.
#
# Without this the Google Maps iOS SDK never receives a key and the app hard
# crashes the moment a GoogleMap widget is built (the add-favorite-place sheet).
set -e

ENV_FILE="${SRCROOT}/../.env"
PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ ! -f "$ENV_FILE" ]; then
  echo "error: .env not found at $ENV_FILE — Google Maps needs GOOGLE_MAPS_API_KEY from it." >&2
  exit 1
fi

API_KEY=$(grep '^[[:space:]]*GOOGLE_MAPS_API_KEY=' "$ENV_FILE" | tail -n 1 | cut -d '=' -f 2- | tr -d '[:space:]')

if [ -z "$API_KEY" ]; then
  echo "error: GOOGLE_MAPS_API_KEY is missing or empty in $ENV_FILE" >&2
  exit 1
fi

/usr/libexec/PlistBuddy -c "Set :GoogleMapsApiKey $API_KEY" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :GoogleMapsApiKey string $API_KEY" "$PLIST"

echo "Injected GOOGLE_MAPS_API_KEY into $PLIST"
