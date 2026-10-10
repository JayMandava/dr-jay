#!/bin/bash
set -euo pipefail

drjay_archive="${1:?Usage: bash scripts/check-release-archive.sh /path/DrJay.xcarchive}"
drjay_app="$drjay_archive/Products/Applications/Roastie.app"
drjay_widget="$drjay_app/PlugIns/RoastieWidgets.appex"
drjay_sdk="$drjay_app/Frameworks/CLiteRTLM.framework"

for drjay_bundle in "$drjay_app" "$drjay_widget" "$drjay_sdk"; do
    test -d "$drjay_bundle"
    /usr/bin/plutil -lint "$drjay_bundle/Info.plist" "$drjay_bundle/PrivacyInfo.xcprivacy"
done
for drjay_key in CFBundleShortVersionString CFBundleVersion; do
    drjay_app_value=$(/usr/bin/plutil -extract "$drjay_key" raw -o - "$drjay_app/Info.plist")
    drjay_widget_value=$(/usr/bin/plutil -extract "$drjay_key" raw -o - "$drjay_widget/Info.plist")
    if [[ "$drjay_app_value" != "$drjay_widget_value" ]]; then
        echo "error: App and widget $drjay_key differ."
        exit 1
    fi
done
for drjay_resource in PRIVACY.md LICENSE NOTICE; do
    test -s "$drjay_app/$drjay_resource"
done
test -d "$drjay_sdk/third_party_licenses.bundle"
if [[ $(/usr/bin/plutil -extract ApplicationProperties.ApplicationPath raw -o - "$drjay_archive/Info.plist") != "Applications/Roastie.app" ]]; then
    echo "error: Archive is not an iOS app archive."
    exit 1
fi
echo "Archive structure checks passed. Paid distribution signing and Xcode Validate App remain separate checks."
