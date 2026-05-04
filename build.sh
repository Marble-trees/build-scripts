#!/bin/bash

# =========================================================
# CONFIGURATION & TOKENS
# =========================================================
set -o pipefail

TG_BOT_TOKEN="8749239007:AAHxq22b91xoBUFUXNsTIy-aK2P7j0fFNoU"
TG_BUILD_CHAT_ID="1729991333"

# Input Arguments
ROM_INPUT=${1:-"evolution"}
DEVICE=${2:-"marble"}

# Build log file
LOG="build.log"
OUT_DIR="out/target/product/${DEVICE}"

# =========================================================
# ROM-SPECIFIC CONFIGURATION
# =========================================================
case "${ROM_INPUT,,}" in
    *"evolution"*)
        ROM_NAME="Evolution-X"
        MANIFEST_URL="https://github.com/Evolution-X/manifest"
        MANIFEST_BRANCH="bq1"
        LOCAL_MANIFEST_URL="https://github.com/alioth-stuffs/local_manifest"
        LOCAL_MANIFEST_BRANCH="evolu"
        LUNCH_TARGET="lineage_${DEVICE}-bp4a-user"
        BUILD_COMMAND="m evolution"
        ;;
    *"infinity"*)
        ROM_NAME="Infinity-X"
        MANIFEST_URL="https://github.com/ProjectInfinity-X/manifest"
        MANIFEST_BRANCH="16"
        LOCAL_MANIFEST_URL="https://github.com/Marble-trees/local-manifest"
        LOCAL_MANIFEST_BRANCH="inf"
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
# UTILITY FUNCTIONS
# =========================================================

retry() {
    local max_attempts=$1; shift
    local delay=$1; shift
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        echo "[Attempt $attempt/$max_attempts] $*"
        if "$@"; then
            return 0
        fi
        echo "Failed. Retrying in ${delay}s..."
        sleep "$delay"
        ((attempt++))
    done

    echo "All $max_attempts attempts failed."
    return 1
}

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

  echo -e "\n[$(date '+%Y-%m-%d %I:%M:%S %p')] Sending message to Telegram (${chat_id})"
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${chat_id}" \
    --data-urlencode "text=${html}" \
    -d "parse_mode=HTML" \
    -d "disable_web_page_preview=true"
}

send_telegram_file() {
  local chat_id="$1"
  local file_path="$2"
  local caption="$3"

  echo -e "\n[$(date '+%Y-%m-%d %I:%M:%S %p')] Sending file to Telegram (${chat_id})"
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" \
    -F chat_id="$chat_id" \
    -F document=@"$file_path" \
    -F caption="$caption" > /dev/null
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
*Time Elapsed:* $duration_fmt
*Failure Time:* $(date '+%Y-%m-%d %I:%M:%S %p %Z')"
    
    send_telegram "$TG_BUILD_CHAT_ID" "$error_msg"
    echo "Error in stage: $stage (Exit Code: $exit_code)"
    exit "$exit_code"
}

# =========================================================
# GOFILE UPLOAD (native, with multi-server fallback)
# =========================================================

gofile_upload() {
    local file="$1"
    local filename
    filename=$(basename "$file")

    [ -f "$file" ] || {
        echo "⚠️ Skipped (not found): $filename" >&2
        return 1
    }

    # Resolve available GoFile servers
    local servers
    mapfile -t servers < <(curl -s "https://api.gofile.io/servers" | jq -r '.data.servers[].name')

    if [ "${#servers[@]}" -eq 0 ]; then
        echo "Error: Could not resolve any GoFile servers." >&2
        return 1
    fi

    # Try servers in random order for load distribution
    for server in $(printf "%s\n" "${servers[@]}" | shuf); do
        local response
        response=$(curl -4 --http1.1 -sf --connect-timeout 30 --max-time 600 \
            -F "file=@${file}" \
            "https://${server}.gofile.io/contents/uploadFile")

        local link
        link=$(echo "$response" | jq -r '.data.downloadPage // empty')

        if [ -n "$link" ]; then
            echo "$link"
            return 0
        fi

        echo "GoFile server $server failed, trying next..." >&2
    done

    return 1
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
*Start Time:* $(date '+%Y-%m-%d %I:%M:%S %p %Z')"
    send_telegram "$TG_BUILD_CHAT_ID" "$initial_msg"
}

clean_stale_trees() {
    echo "Cleaning stale device/vendor/kernel trees..."
    rm -rf .repo/local_manifests
    rm -rf {device,kernel,hardware,vendor}/xiaomi
    rm -rf {device,kernel,hardware,vendor}/qcom
}

sync_sources() {
    send_telegram "$TG_BUILD_CHAT_ID" "🔄 *Syncing sources...*
*ROM:* $ROM_NAME"

    echo "Initializing repo..."
    repo init --depth=1 --no-repo-verify -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --git-lfs -g default,-mips,-darwin,-notdefault
    
    echo "Cloning local manifest..."
    git clone "$LOCAL_MANIFEST_URL" --depth 1 -b "$LOCAL_MANIFEST_BRANCH" .repo/local_manifests
    
    echo "Syncing sources..."
    if [ -f /opt/crave/resync.sh ]; then
        retry 3 30 /opt/crave/resync.sh || handle_error $? "sync"
    else
        retry 3 30 repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags || handle_error $? "sync"
    fi

    send_telegram "$TG_BUILD_CHAT_ID" "✅ *Source sync completed!*"
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
    . build/envsetup.sh
    if ! type lunch &>/dev/null; then
        handle_error 1 "envsetup"
    fi
    
    echo "Lunching target: $LUNCH_TARGET"
    lunch "$LUNCH_TARGET" || handle_error $? "lunch"

    echo "Running installclean..."
    mka installclean

    echo "========================="
    echo "Starting ROM Compilation..."
    echo "========================="
    touch "$LOG"
    $BUILD_COMMAND 2>&1 | tee "$LOG"
    BUILD_STATUS=${PIPESTATUS[0]}
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
*Status:* $status_text
*Finished Time:* $(date '+%Y-%m-%d %I:%M:%S %p %Z')"
    send_telegram "$TG_BUILD_CHAT_ID" "$final_msg"

    if [[ $BUILD_STATUS -eq 0 ]]; then
        echo "Build successful. Starting upload..."
        upload_build
    else
        echo "Build failed. Sending error logs..."
        if [ -f out/error.log ]; then
            send_telegram_file "$TG_BUILD_CHAT_ID" "out/error.log" "📜 Build Error Log — ${ROM_NAME} | ${DEVICE}"
        elif [ -f "$LOG" ]; then
            tail -n 120 "$LOG" > error_tail.log
            send_telegram_file "$TG_BUILD_CHAT_ID" "error_tail.log" "📜 Last 120 lines — ${ROM_NAME} | ${DEVICE} (no out/error.log found)"
            rm -f error_tail.log
        fi
    fi
}

upload_build() {
    local build_zip

    # Try to find a zip matching both ROM name and device codename (under 3.5GB)
    build_zip=$(find ${OUT_DIR}/ -maxdepth 1 -iname "*${ROM_NAME}*${DEVICE}*.zip" -size -3584M 2>/dev/null | head -n 1)

    # Fallback: match by device name only (under 3.5GB)
    if [ -z "$build_zip" ]; then
        build_zip=$(find ${OUT_DIR}/ -maxdepth 1 -iname "*${DEVICE}*.zip" -size -3584M 2>/dev/null | head -n 1)
    fi

    if [ -z "$build_zip" ]; then
        echo "Error: No build ZIP found matching '${ROM_NAME}' or '${DEVICE}' in ${OUT_DIR}/"
        send_telegram "$TG_BUILD_CHAT_ID" "❌ *Upload failed:* Build ZIP not found."
        return 1
    fi

    local filename
    filename=$(basename "$build_zip")

    local filesize
    filesize=$(du -h "$build_zip" | cut -f1)

    local sha256
    sha256=$(sha256sum "$build_zip" | cut -d' ' -f1)

    echo "Uploading $build_zip (${filesize}, SHA256: ${sha256})..."

    local download_link
    download_link=$(gofile_upload "$build_zip")

    if [ -n "$download_link" ]; then
        local link_msg="📦 *Upload Complete!*
*ROM:* $ROM_NAME
*Device:* $DEVICE
*File:* $filename
*Size:* $filesize
*SHA256:* $sha256
*Link:* [Click Here to Download]($download_link)"
        send_telegram "$TG_BUILD_CHAT_ID" "$link_msg"
    else
        echo "Error: GoFile upload failed."
        send_telegram "$TG_BUILD_CHAT_ID" "⚠️ *Upload failed.* All GoFile servers returned errors."
    fi
}

# =========================================================
# MAIN EXECUTION
# =========================================================

main() {
    init_environment
    clean_stale_trees
    sync_sources
    setup_keys
    compile_rom
    finalize_build
}

main
