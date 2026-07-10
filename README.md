# Mirage

A sleek, lightweight Flutter utility for Linux that temporarily spoofs your operating system release information.

## Overview

Mirage is designed for scenarios where a specific application refuses to run because it strictly checks for a specific Linux distribution. Mirage elegantly bypasses these arbitrary restrictions by temporarily masking your host OS as **Ubuntu 24.04 LTS (Noble Numbat)**.

The app provides a modern, minimalist interface to:
1. View the live contents of your system's `/etc/os-release` file.
2. Back up your native OS release files and override them with Ubuntu 24.04 identifiers.
3. Instantly restore your system's original state with a single click.

## Features

- **Safe Operations**: Always backs up your original `/etc/os-release`, `/etc/lsb-release`, and `/usr/lib/os-release` files before making any modifications.
- **Smart Privilege Escalation**: Automatically detects and uses the appropriate graphical `sudo` wrapper for your Desktop Environment (`pkexec`, `kdesu`, `kdesudo`, or `lxqt-sudo`). 
- **Universal Fallback**: If no standard graphical wrapper is found, it automatically generates a temporary `SUDO_ASKPASS` script using `kdialog` or `zenity` to ensure you still get a native GUI password prompt.
- **Clean UI**: Built with Shadcn-inspired design principles, providing clear visual indicators of your system's current spoofing state.

## Requirements

- A Linux Desktop Environment (X11 or Wayland).
- Flutter SDK (for building the app).
- Polkit (`policykit-1`) or a compatible GUI sudo wrapper (`kdesu`, `zenity`, or `kdialog`).

### Optional Dependencies

For GUI privilege escalation, having one of the following installed is recommended:
- `pkexec`
- `kdesu`
- `kdesu`
- `kdesudo`
- `lxqt-sudo`

## Getting Started

1. Clone the repository.
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application locally:
   ```bash
   flutter run -d linux
   ```
4. Build the release binary:
   ```bash
   flutter build linux --release
   ```
   The compiled executable will be located at `build/linux/x64/release/bundle/mirage`.

## How It Works

When you click **"Spoof to Ubuntu"**, Mirage executes a shell script as `root` (via your system's GUI authentication agent) that copies your current OS files to `*.bak` and overwrites the originals with standard Ubuntu 24.04 strings. 

When you click **"Restore Native OS"**, it executes a script to move the `*.bak` files back to their original locations, completely undoing the spoof.

## License

This project is open-source and intended for educational and utility purposes. Always ensure you are complying with the Terms of Service of any third-party applications you use this tool with.