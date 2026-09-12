# BitLocker Utility 3.1 (Modernized)

A PowerShell-based tool to manipulate BitLocker from a WinPE Environment. Ideal for unlocking or decrypting drives when Windows refuses to boot.

## 🚀 What's New in Version 3.1
- **Replaced WMI with CIM**: Uses `Get-CimInstance` and `Invoke-CimMethod` instead of the obsolete `Get-WmiObject`.
- **Clean Object Creation**: Replaced slow `Add-Member` loops with direct `PSCustomObject` synthesis.
- **Regex Input Validation**: Ensures valid drive letters and properly formatted BitLocker recovery keys.
- **Robust Error Handling**: Native `$LASTEXITCODE` checking for `manage-bde` operations.
- **Safer Launchers**: `.cmd` files updated to use `-NoProfile` and `-ExecutionPolicy Bypass`.
- **Cross-Platform Building**: Now includes a Bash script to generate the WinPE ISO from Ubuntu!

## 🛠 Features
- **Show All Drives**: Lists volumes, encryption status, methods, and Recovery Key IDs.
- **Unlock BitLocker Drive**: Prompts for the recovery key to unlock a locked drive.
- **Turn OFF / Suspend BitLocker**: Decrypts the drive completely or suspends protection.

## 📦 How to Build the WinPE ISO

### Option 1: From Windows
1. Install Windows ADK.
2. Run `BuiltWinPE/WinPEBuilder.bat` to build a WinPE ISO with the tool included.

### Option 2: From Ubuntu Linux
1. Ensure you have a standard Windows 10/11 ISO file.
2. Run the bash script from the repo root: `sudo ./BuiltWinPE/build-iso-ubuntu.sh /path/to/Windows.iso`
3. The script will inject the tool into the WinPE environment and generate a bootable ISO.

## 👥 Credits
- Original Author: Carlos Martinez (@cmartinezone) - 2019
- Modernized by: Pablo & AI - 2024
