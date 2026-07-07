<div align="center">

  <!-- Banner -->
  <img src="https://github.com/74Thirsty/74Thirsty/blob/main/assets/usb.svg" width="100%">

  <!-- Badge Row -->
  <p>
    <img src="https://img.shields.io/badge/gadgetSavvy-Lead%20Developer-0EA5E9?logo=github&logoColor=white">
    <img src="https://img.shields.io/badge/Python-3.x-0EA5E9?logo=python&logoColor=white">
    <img src="https://img.shields.io/badge/ISO%20Support-✓-0EA5E9?logo=discogs&logoColor=white">
    <img src="https://img.shields.io/badge/UEFI%20Ready-✓-0EA5E9?logo=windows&logoColor=white">
    <img src="https://img.shields.io/badge/Legacy%20BIOS-✓-0EA5E9?logo=linux&logoColor=white">
    <img src="https://img.shields.io/badge/Write%20Speed-Optimized-0EA5E9?logo=speedtest&logoColor=white">
    <img src="https://img.shields.io/badge/Checksum-Verification-0EA5E9?logo=vercel&logoColor=white">
  </p>

</div>

Absolutely — now that I’ve read both **your script** and the **GitHub repository page** for `live-usb` from your active tab   [Current page](citation-section://318036686/1), here is a polished, repo‑ready **README** that accurately reflects both sources.

---

# Industrial Live USB TUI  
A terminal user interface (TUI) tool for writing Linux and Windows installation ISOs to USB flash drives, with optional persistence and disk repair utilities. Designed for technicians, forensic analysts, and power users who need a safe, repeatable, interactive workflow for preparing bootable media.

## Overview  
This project provides a guided, menu‑driven workflow using `whiptail` to:

- Select an ISO  
- Choose OS type (Linux hybrid or Windows 11)  
- Choose boot mode (UEFI/GPT, BIOS/MBR, or hybrid)  
- Optionally create persistence (Linux only)  
- Optionally repair partition tables (MBR/GPT)  
- Safely select a target USB drive  
- Confirm destructive actions  
- Write the ISO using `dd`  

The repository currently contains the main script (`live-usb.sh`) as shown on the GitHub page   [Current page](citation-section://318036686/1).

---

## Features

### ISO Handling
- Supports Linux hybrid ISOs (Kali, Parrot, etc.)
- Supports Windows 11 installer ISOs
- Validates ISO path before continuing

### Boot Mode Selection
- **UEFI / GPT**
- **Legacy BIOS / MBR**
- **Hybrid direct-write**

### Persistence (Linux Only)
- Optional persistence partition creation after ISO write

### Repair Utilities
- Initialize/repair **MBR**
- Initialize/repair **GPT**
- GRUB placeholder check

### Safety Mechanisms
- Detects and excludes the system root disk automatically  
- Requires typed `"ERASE"` confirmation  
- Unmounts all target partitions before writing  
- Uses `set -euo pipefail` for safe execution

---

## Requirements

The script checks for these tools:

- `lsblk`
- `findmnt`
- `awk`
- `sed`
- `grep`
- `wipefs`
- `parted`
- `dd`
- `sync`
- `whiptail`

Install whiptail if needed:

```
sudo apt install whiptail
```

---

## Installation

Clone the repository:

```
git clone https://github.com/74Thirsty/live-usb
cd live-usb
```

Make the script executable:

```
chmod +x live-usb.sh
```

---

## Usage

Run as root:

```
sudo ./live-usb.sh
```

You will be guided through:

1. Entering the ISO path  
2. Selecting ISO type  
3. Selecting boot mode  
4. Optional persistence  
5. Optional repair actions  
6. Selecting the target USB drive  
7. Reviewing a summary  
8. Typing `ERASE` to confirm  

After confirmation, the script unmounts the target drive and writes the ISO.

---

## Repository Structure

From the GitHub page   [Current page](citation-section://318036686/1):

```
live-usb/
├── LICENSE
├── README.md
└── live-usb.sh
```

The project is licensed under MIT.

---

## Notes

- This tool **will erase the selected USB drive completely**.  
- Persistence creation logic may vary depending on ISO type.  
- GRUB placeholder check is currently a stub for future expansion.  
- No releases or packages are published yet   [Current page](citation-section://318036686/2).

---

## License

MIT License — see `LICENSE` in the repository.

---

If you want, I can also generate:

- A **more polished GitHub‑style README with badges**  
- A **man page**  
- A **diagram of the workflow**  
- A **refactored version of the script**  
- A **Dockerized version** (since you have Docker tabs open)

Just tell me what direction you want to take this project.
