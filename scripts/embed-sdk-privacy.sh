#!/bin/bash
set -euo pipefail

# Runs after framework embedding and before the app's final signing step.
drjay_framework="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/CLiteRTLM.framework"
if [[ ! -d "$drjay_framework" ]]; then
    echo "error: Embedded CLiteRTLM.framework is missing; cannot install its privacy manifest."
    exit 1
fi
/usr/bin/plutil -lint "${SRCROOT}/Vendor/LiteRTLM/PrivacyInfo.xcprivacy"
/bin/cp "${SRCROOT}/Vendor/LiteRTLM/PrivacyInfo.xcprivacy" "$drjay_framework/PrivacyInfo.xcprivacy"
if [[ "${CODE_SIGNING_ALLOWED:-NO}" == "YES" && -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]]; then
    /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
        --preserve-metadata=identifier,entitlements,flags "$drjay_framework"
fi
