# Custom ROM Build Automation for Crave CI

A highly flexible, modular Bash-based automation suite designed for building various Android custom ROMs on Crave CI servers. Optimized for the **POCO F5 (marble)**, but easily adaptable for other devices.

## 🚀 Supported ROMs

This script currently includes pre-configured support for:
- **Evolution-X** (Android 16 - `bq1`)
- **LineageOS** (Android 15 - `22.1`)
- **crDroid** (Android 15 - `15.0`)
- **Lunaris-AOSP** (Android 16 - `16.2`)
- **Project Infinity-X** (Android 16 - `16`)

## ✨ Key Features

- **Multi-ROM Parameterization:** Build different ROMs by simply passing arguments to the script.
- **Modular Architecture:** Cleanly separated functions for environment setup, source syncing, security keys, compilation, and uploading.
- **Real-time Telegram Integration:**
    - Notifications for Build Start, Success, and Failure.
    - **Early Failure Alerts:** Immediate notification if sync, lunch, or envsetup fails.
    - **Error Log Delivery:** On failure, sends `out/error.log` (or last 120 lines of the build log) directly to Telegram as a document.
    - **Download Links:** Automatically sends a clickable GoFile link with file size and SHA256 checksum to your Telegram once the upload is complete.
- **Native GoFile Upload:** Self-contained upload function that resolves servers via the GoFile API and tries multiple servers with automatic fallback — no third-party scripts needed.
- **Retry Logic:** Automatic retries (3 attempts with 30s delay) for network operations like `repo sync` and Crave resync.
- **Stale Tree Cleanup:** Removes leftover device/vendor/kernel trees before syncing to prevent cross-ROM conflicts.
- **Smart Security:** Automatically handles ROM-specific requirements like Evolution-X signing keys.
- **Portable:** Falls back to standard `repo sync` when not running on Crave CI.

## 🛠️ Prerequisites

- **Crave CI Environment:** Designed specifically for use with `/opt/crave/resync.sh`.
- **System Tools:** `repo`, `git`, `curl`, `jq`.
- **Telegram Bot:** A bot added to your chat/group to receive status updates.

## 📖 Usage

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

### Adding a New ROM
Add a new case to the `ROM-SPECIFIC CONFIGURATION` block in `build.sh`:
```bash
*"newrom"*)
    ROM_NAME="NewROM"
    MANIFEST_URL="https://github.com/org/manifest"
    MANIFEST_BRANCH="main"
    LOCAL_MANIFEST_URL="https://github.com/your/local_manifest"
    LOCAL_MANIFEST_BRANCH="main"
    LUNCH_TARGET="newrom_${DEVICE}-user"
    BUILD_COMMAND="m bacon"
    ;;
```

### Build Identity
Configured inside `init_environment()`:
- `BUILD_USERNAME` — appears in the ROM's About page
- `BUILD_HOSTNAME` — appears in the ROM's About page

## 📂 Project Structure

- `build.sh` — The core automation script.
- `.gitignore` — Configured to ignore local context files.
- `README.md` — This documentation.

---
**Note:** Ensure you have the correct `local_manifests` for your device in the appropriate repository, or update `LOCAL_MANIFEST_URL` in the script.
