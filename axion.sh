#!/bin/bash

# =========================================================
# CONFIGURATION
# =========================================================
# This token was retrieved from your previous log for continuous functionality.
TG_BOT_TOKEN="8150376575:AAFCpGpdXQsmYwM6GYoF1PiTmdX3mysHEM8"
TG_BUILD_CHAT_ID="-5028083879"
DEVICE_CODE="marble"
BUILD_TARGET="AxionOS AOSP"
ANDROID_VERSION="16"

# SHELL CONFIGURATION
export TZ="Asia/Dhaka"
export BUILD_USERNAME=nhAsif
export BUILD_HOSTNAME=marvel

# =========================================================
# TELEGRAM FUNCTIONS
# =========================================================

# Function to safely format and send a text message to Telegram
send_telegram() {
  local chat_id="$1"
  local message="$2"

  # 1. Escape characters required by MarkdownV2 that are NOT meant to be formatters.
  # We use a comprehensive escaping logic to ensure *bold* text works.
  local escaped_message=$(echo "$message" | sed \
    -e 's/\*/\*TEMP\*/g' \
    -e 's/_/\_TEMP\_/g' \
    -e 's/\[/\\[/g' \
    -e 's/\]/\\]/g' \
    -e 's/(/\\(/g' \
    -e 's/)/\\)/g' \
    -e 's/~/\\~/g' \
    -e 's/`/\`/g' \
    -e 's/>/\\>/g' \
    -e 's/#/\\#/g' \
    -e 's/+/\\+/g' \
    -e 's/-/\\-/g' \
    -e 's/=/\\=/g' \
    -e 's/|/\\|/g' \
    -e 's/{/\\{/g' \
    -e 's/}/\\}/g' \
    -e 's/\./\\./g' \
    -e 's/!/\\!/g')

  # 2. Revert the temporary placeholders for the actual formatting characters that are intended for bold/italic.
  local re_escaped_message=$(echo "$escaped_message" | sed \
    -e 's/\*TEMP\*/\*/g' \
    -e 's/\_TEMP\_/\_/g')
  
  # 3. URL encode special characters for transmission, including newlines.
  local encoded_message=$(echo "$re_escaped_message" | sed \
    -e 's/%/%25/g' \
    -e 's/&/%26/g' \
    -e 's/+/%2b/g' \
    -e 's/ /%20/g' \
    -e 's/\"/%22/g' \
    -e 's/'"'"'/%27/g' \
    -e 's/\n/%0A/g')
    
  echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] Sending message to Telegram (${chat_id})"
  # We must explicitly set parse_mode to MarkdownV2
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${chat_id}" \
    -d "text=${encoded_message}" \
    -d "parse_mode=MarkdownV2" \
    -d "disable_web_page_preview=true"
}

# Function to format total seconds into HH:MM:SS string
format_duration() {
    local T=$1
    local H=$((T/3600))
    local M=$(( (T%3600)/60 ))
    local S=$((T%60))
    printf "%02d hours, %02d minutes, %02d seconds" $H $M $S
}


# =========================================================
# BUILD LOGIC FUNCTION
# =========================================================

start_build_process() {

    # --- STEP 1: START TIMER AND SEND INITIAL NOTIFICATION ---
    START_TIME=$(date +%s)

    # Message for Build Started
    local initial_msg="⚙️ *ROM Build Started!*
    *ROM:* $BUILD_TARGET
    *Android:* $ANDROID_VERSION
    *Device:* $DEVICE_CODE
    *Start Time:* $(date '+%Y-%m-%d %H:%M:%S %Z')"
    send_telegram "$TG_BUILD_CHAT_ID" "$initial_msg"
    echo "Build Started at $(date '+%Y-%m-%d %H:%M:%S')"

    # =========================================================
    # ORIGINAL BUILD STEPS
    # =========================================================

    # Init AxionOS Android 16 branch
    repo init --depth=1 --no-repo-verify -u https://github.com/AxionAOSP/android.git -b lineage-23.0 --git-lfs -g default,-mips,-darwin,-notdefault

    # Resync sources
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
    /opt/crave/resync.sh
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
    /opt/crave/resync.sh

    # Clean up existing trees
    echo "Starting remove repositories..."
    # Device
    rm -rf device/xiaomi/marble
    rm -rf device/xiaomi/sm8450-common
    rm -rf device/xiaomi/miuicamera-marble
    # Vendor
    rm -rf vendor/xiaomi/marble
    rm -rf vendor/xiaomi/sm8450-common
    rm -rf vendor/xiaomi/miuicamera-marble
    # Kernel
    rm -rf kernel/xiaomi/sm8450
    rm -rf kernel/xiaomi/sm8450-devicetrees
    rm -rf kernel/xiaomi/sm8450-modules
    # Hardware
    rm -rf hardware/xiaomi
    rm -rf hardware/dolby
    # Apps
    rm -rf packages/apps/GameBar
    # Build output
    rm -rf out/target/product/marble
    echo "Successfully deleted previous repositories."

    echo "Cloning device stuff..."
    # Device Trees
    git clone --depth=1 https://github.com/Marble-trees/android_device_xiaomi_marble device/xiaomi/marble
    git clone --depth=1 https://github.com/Chaitanyakm/device_xiaomi_miuicamera-marble device/xiaomi/miuicamera-marble
    git clone --depth=1 https://github.com/Marble-trees/android_device_xiaomi_sm8450-common device/xiaomi/sm8450-common

    # Vendor Trees
    git clone --depth=1 https://gitlab.com/Chaitanyakm/vendor_xiaomi_miuicamera-marble vendor/xiaomi/miuicamera-marble
    git clone --depth=1 https://github.com/Marble-trees/proprietary_vendor_xiaomi_marble vendor/xiaomi/marble
    git clone --depth=1 https://github.com/Marble-trees/proprietary_vendor_xiaomi_sm8450-common vendor/xiaomi/sm8450-common

    # Kernel & Toolchain
    git clone --depth=1 https://github.com/LineageOS/android_kernel_xiaomi_sm8450 kernel/xiaomi/sm8450
    git clone --depth=1 https://github.com/LineageOS/android_kernel_xiaomi_sm8450-devicetrees kernel/xiaomi/sm8450-devicetrees
    git clone --depth=1 https://github.com/LineageOS/android_kernel_xiaomi_sm8450-modules kernel/xiaomi/sm8450-modules

    # Camera/Hardware
    git clone --depth=1 https://github.com/Marble-trees/android_hardware_dolby hardware/dolby
    git clone --depth=1 https://github.com/LineageOS/android_hardware_xiaomi hardware/xiaomi
    git clone https://github.com/Marble-trees/packages_apps_GameBar packages/apps/GameBar

    echo "Tree sync complete."

    # Setup the build environment
    . build/envsetup.sh
    echo "Environment setup success."

    # Generate private keys
    gk -s

    # Build ROM
    echo "========================="
    echo "Starting ROM Compilation..."
    echo "========================="
    axion marble gms pico user
    axion -br -j$(nproc --all)

    BUILD_STATUS=$? # Capture exit code immediately

    # --- STEP 3: CALCULATE TIME AND SEND FINAL NOTIFICATION ---
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    local DURATION_FORMATTED=$(format_duration $DURATION)
    
    if [[ $BUILD_STATUS -eq 0 ]]; then
        local status_icon="✅"
        local status_text="Success"
    else
        local status_icon="❌"
        local status_text="Failure (Exit Code: $BUILD_STATUS)"
    fi

    # Final Message with Android Version
    local final_msg="${status_icon} *Build Finished!*
    *ROM:* $BUILD_TARGET
    *Android:* $ANDROID_VERSION
    *Device:* $DEVICE_CODE
    *Duration:* $DURATION_FORMATTED
    *Status:* $status_text"
    send_telegram "$TG_BUILD_CHAT_ID" "$final_msg"

    # KernelSU Function
    local ksu_warning="⚠️ *This build is using KSU-Next by default!*"
    local non_ksu_warning="🧪 *This build is using Alchemist-LTO+ without KSU-Next by default!*"
    local kernel_dir="kernel/xiaomi/sm8450"

    local current_branch=$(git -C "$kernel_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
    local warning_message=""

    echo "Current branch ($kernel_dir): $current_branch"

    if [ "$current_branch" == "ksu-next" ]; then
       warning_message="$ksu_warning"
    elif [ "$current_branch" == "bka" ]; then
       warning_message="$non_ksu_warning"
    else
       echo "Warning not sent because branch ($current_branch) is not 'ksu-next' or 'bka'."
    fi

    # KernelSU Warning Message to Telegram
    if [ -n "$warning_message" ]; then
       send_telegram "$TG_BUILD_CHAT_ID" "$warning_message"
    fi

    # Conditional Upload ROM
    if [[ $BUILD_STATUS -eq 0 ]]; then
        echo "Build successful. Starting upload script..."
        # Calls the go-up script
        rm -rf go-up*
        wget https://raw.githubusercontent.com/nekoshirro/tools-gofile/refs/heads/private/go-up
        chmod +x go-up
        ./go-up out/target/product/marble/*axion*marble*.zip
    else
        echo "Build failed. Skipping upload."
    fi

    # Display any error logs
    echo "Here is your error"
    cat out/error.log
}

# =========================================================
# MAIN EXECUTION
# =========================================================

# Check required environment variables (optional but good practice)
start_build_process
