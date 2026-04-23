# Custom ROM Build Automation for Crave CI

A highly flexible, modular Bash-based automation suite designed for building various Android custom ROMs on Crave CI servers. Optimized for the **POCO F5 (marble)**, but easily adaptable for other devices.

## 🚀 Supported ROMs

This script currently includes pre-configured support for:
- **Evolution-X** (Android 16 - `bq2`)
- **LineageOS** (Android 15 - `22.1`)
- **crDroid** (Android 15 - `15.0`)
- **Lunaris-AOSP** (Android 16 - `16.2`)
- **Project Infinity-X** (Android 16 - `16`)

## ✨ Key Features

- **Multi-ROM Parameterization:** Build different ROMs by simply passing arguments to the script.
- **Modular Architecture:** Cleanly separated functions for environment setup, source syncing, security keys, compilation, and uploading.
- **Real-time Telegram Integration:**
    - Notifications for Build Start and Success.
    - **Early Failure Alerts:** Immediate notification if sync, lunch, or envsetup fails.
    - **Download Links:** Automatically sends a clickable GoFile link to your Telegram once the upload is complete.
- **Automated Delivery:** Integrates with GoFile for fast, automated ROM uploads.
- **Smart Security:** Automatically handles ROM-specific requirements like Evolution-X signing keys.

## 🛠️ Usage

### Command Syntax
```bash
./build.sh [rom_name] [device_codename]
```

### Examples
- **Build Evolution-X for marble (Default):**
  ```bash
  ./build.sh evolution marble
  ```
- **Build crDroid for marble:**
  ```bash
  ./build.sh crdroid marble
  ```
- **Build Infinity-X for marble:**
  ```bash
  ./build.sh infinity marble
  ```

## ⚙️ Configuration

The script contains hardcoded configuration for:
- **Telegram Bot Token:** `TG_BOT_TOKEN`
- **Telegram Chat ID:** `TG_BUILD_CHAT_ID`
- **Build Identity:** `BUILD_USERNAME` and `BUILD_HOSTNAME`

To add a new ROM, simply add a new case to the `ROM-SPECIFIC CONFIGURATION` block in `build.sh` with the corresponding manifest URL and branch.

## 📋 Prerequisites

- **Crave CI Environment:** Designed specifically for use with `/opt/crave/resync.sh`.
- **System Tools:** `repo`, `git`, `curl`, `jq`, `wget`.
- **Telegram Bot:** A bot added to your chat/group to receive status updates.

## 📂 Project Structure

- `build.sh`: The core automation script.
- `.gitignore`: Configured to ignore local instructional context (`GEMINI.md`).
- `README.md`: This documentation.

---
**Note:** Ensure you have the correct `local_manifests` for your device in the `alioth-stuffs/local_manifest` repository or update the `LOCAL_MANIFEST_URL` in the script.
