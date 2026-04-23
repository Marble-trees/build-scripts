#!/bin/bash

# =========================================================
# CONFIGURATION & TOKENS
# =========================================================
TG_BOT_TOKEN="8749239007:AAHxq22b91xoBUFUXNsTIy-aK2P7j0fFNoU"
TG_BUILD_CHAT_ID="1729991333"

# Input Arguments
ROM_INPUT=${1:-"evolution"}
DEVICE=${2:-"marble"}

# =========================================================
# ROM-SPECIFIC CONFIGURATION
# =========================================================
case "${ROM_INPUT,,}" in
    *"evolution"*)
        ROM_NAME="Evolution-X"
        MANIFEST_URL="https://github.com/Evolution-X/manifest"
        MANIFEST_BRANCH="bq2"
        LOCAL_MANIFEST_URL="https://github.com/Marble-trees/local-manifest"
        LOCAL_MANIFEST_BRANCH="main"
        LUNCH_TARGET="lineage_${DEVICE}-bp4a-user"
        BUILD_COMMAND="m evolution"
        ;;
    *"infinity"*)
        ROM_NAME="Infinity-X"
        MANIFEST_URL="https://github.com/ProjectInfinity-X/manifest"
        MANIFEST_BRANCH="16"
        LOCAL_MANIFEST_URL="https://github.com/Marble-trees/local-manifest"
        LOCAL_MANIFEST_BRANCH="main"
        LUNCH_TARGET="infinity_${DEVICE}-user"
        BUILD_COMMAND="m bacon"
        ;;
    *"lineage"*)
        ROM_NAME="LineageOS"
        MANIFEST_URL="https://github.com/LineageOS/android"
        MANIFEST_BRANCH="lineage-22.1"
        LOCAL_MANIFEST_URL="https://github.com/alioth-stuffs/local_manifest"
        LOCAL_MANIFEST_BRANCH="lineage"
        LUNCH_TARGET="lineage_${DEVICE}-user"
        BUILD_COMMAND="mka bacon"
        ;;
    *"crdroid"*)
        ROM_NAME="crDroid"
        MANIFEST_URL="https://github.com/crdroidandroid/android"
        MANIFEST_BRANCH="15.0"
        LOCAL_MANIFEST_URL="https://github.com/alioth-stuffs/local_manifest"
        LOCAL_MANIFEST_BRANCH="crdroid"
        LUNCH_TARGET="lineage_${DEVICE}-user"
        BUILD_COMMAND="mka bacon"
        ;;
    *"lunaris"*)
        ROM_NAME="Lunaris-AOSP"
        MANIFEST_URL="https://github.com/Lunaris-AOSP/android"
        MANIFEST_BRANCH="16.2"
        LOCAL_MANIFEST_URL="https://github.com/Marble-trees/local-manifest"
        LOCAL_MANIFEST_BRANCH="main"
        LUNCH_TARGET="lineage_${DEVICE}-bp4a-user"
        BUILD_COMMAND="m bacon"
        ;;
    *)
        echo "Error: Unknown ROM type '$ROM_INPUT'"
        exit 1
        ;;
esac

# Common Build Target Display
ANDROID_VERSION="16"

# =========================================================
# TELEGRAM FUNCTIONS
# =========================================================

send_telegram() {
  local chat_id="$1"
  local message="$2"
  
  # Escape HTML special characters
  local escaped=$(echo "$message" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
  
  # Convert *bold* to <b>bold</b>
  local html=$(echo "$escaped" | sed 's/\*\([^*]*\)\*/<b>\1<\/b>/g')
  
  # Convert [text](link) to <a href="link">text</a>
  html=$(echo "$html" | sed 's/\[\([^]]*\)\](\([^)]*\))/<a href="\2">\1<\/a>/g')

  echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] Sending message to Telegram (${chat_id})"
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${chat_id}" \
    --data-urlencode "text=${html}" \
    -d "parse_mode=HTML" \
    -d "disable_web_page_preview=true"
}

format_duration() {
    local T=$1
    local H=$((T/3600))
    local M=$(( (T%3600)/60 ))
    local S=$((T%60))
    printf "%02d hours, %02d minutes, %02d seconds" $H $M $S
}

handle_error() {
    local exit_code=$1
    local stage="$2"
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local duration_fmt=$(format_duration $duration)

    local error_msg="❌ *Build Failed Early!*
*ROM:* $ROM_NAME
*Stage:* $stage
*Exit Code:* $exit_code
*Time Elapsed:* $duration_fmt"
    
    send_telegram "$TG_BUILD_CHAT_ID" "$error_msg"
    echo "Error in stage: $stage (Exit Code: $exit_code)"
    exit "$exit_code"
}

# =========================================================
# MODULAR BUILD STEPS
# =========================================================

init_environment() {
    export TZ="Asia/Dhaka"
    export BUILD_USERNAME=nhAsif
    export BUILD_HOSTNAME=marvel
    START_TIME=$(date +%s)

    local initial_msg="⚙️ *ROM Build Started!*
*ROM:* $ROM_NAME
*Android:* $ANDROID_VERSION
*Device:* $DEVICE
*Start Time:* $(date '+%Y-%m-%d %H:%M:%S %Z')"
    send_telegram "$TG_BUILD_CHAT_ID" "$initial_msg"
}

sync_sources() {
    /opt/crave/resync.sh
}

setup_keys() {
    if [[ "${ROM_INPUT,,}" == *"evolution"* ]]; then
        echo "Setting up Evolution-X signing keys..."
        git clone https://github.com/Evolution-X/vendor_evolution-priv_keys-template vendor/evolution-priv/keys --depth 1 || return 0
        chmod +x vendor/evolution-priv/keys/keys.sh
        pushd vendor/evolution-priv/keys > /dev/null
        ./keys.sh
        popd > /dev/null
    fi
}

compile_rom() {
    echo "Setting up build environment..."
    . build/envsetup.sh || handle_error $? "envsetup"
    
    echo "Lunching target: $LUNCH_TARGET"
    lunch "$LUNCH_TARGET" || handle_error $? "lunch"

    echo "========================="
    echo "Starting ROM Compilation..."
    echo "========================="
    $BUILD_COMMAND
    BUILD_STATUS=$?
}

finalize_build() {
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    DURATION_FORMATTED=$(format_duration $DURATION)
    
    if [[ $BUILD_STATUS -eq 0 ]]; then
        local status_icon="✅"
        local status_text="Success"
    else
        local status_icon="❌"
        local status_text="Failure (Exit Code: $BUILD_STATUS)"
    fi

    local final_msg="${status_icon} *Build Finished!*
*ROM:* $ROM_NAME
*Android:* $ANDROID_VERSION
*Device:* $DEVICE
*Duration:* $DURATION_FORMATTED
*Status:* $status_text"
    send_telegram "$TG_BUILD_CHAT_ID" "$final_msg"

    if [[ $BUILD_STATUS -eq 0 ]]; then
        echo "Build successful. Starting upload..."
        upload_build
    else
        echo "Build failed. Displaying error logs..."
        [ -f out/error.log ] && cat out/error.log
    fi
}

upload_build() {
    echo "Downloading GoFile upload script..."
    rm -rf upload*
    wget -q https://raw.githubusercontent.com/Sanjivns/GoFile-Upload/refs/heads/master/upload
    chmod +x upload
    
    local build_zip=$(ls out/target/product/${DEVICE}/${ROM_NAME}*.zip 2>/dev/null | head -n 1)
    if [ -n "$build_zip" ]; then
        echo "Uploading $build_zip..."
        # Capture output to extract link
        local upload_output=$(./upload "$build_zip")
        echo "$upload_output"
        
        # Extract the GoFile download link (usually looks like https://gofile.io/d/XXXXXX)
        local download_link=$(echo "$upload_output" | grep -o 'https://gofile.io/d/[a-zA-Z0-9]*')
        
        if [ -n "$download_link" ]; then
            local link_msg="📦 *Upload Complete!*
*ROM:* $ROM_NAME
*Device:* $DEVICE
*Link:* [Click Here to Download]($download_link)"
            send_telegram "$TG_BUILD_CHAT_ID" "$link_msg"
        else
            echo "Error: Could not extract download link from upload output."
            send_telegram "$TG_BUILD_CHAT_ID" "⚠️ *Upload finished but link extraction failed.* Check logs."
        fi
    else
        echo "Error: No build ZIP found for upload."
        send_telegram "$TG_BUILD_CHAT_ID" "❌ *Upload failed:* Build ZIP not found."
    fi
}

# =========================================================
# MAIN EXECUTION
# =========================================================

main() {
    init_environment
    sync_sources
    setup_keys
    compile_rom
    finalize_build
}

main
