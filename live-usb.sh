#!/usr/bin/env bash
set -euo pipefail

APP="Industrial Live USB TUI"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1"
    exit 1
  }
}

need lsblk
need findmnt
need awk
need sed
need grep
need wipefs
need parted
need dd
need sync

if ! command -v whiptail >/dev/null 2>&1; then
  echo "Install whiptail first:"
  echo "sudo apt install whiptail"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Run as root:"
  echo "sudo bash $0"
  exit 1
fi

ROOT_SRC="$(findmnt -n -o SOURCE /)"
ROOT_DISK="/dev/$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null || true)"

if [[ "$ROOT_DISK" == "/dev/" || -z "$ROOT_DISK" ]]; then
  ROOT_DISK="$(lsblk -no NAME,MOUNTPOINT | awk '$2=="/"{print "/dev/"$1}')"
fi

ISO_PATH=$(whiptail --title "$APP" --inputbox "Enter full path to ISO:" 10 80 3>&1 1>&2 2>&3)

[[ -z "${ISO_PATH:-}" ]] && exit 0

if [[ ! -f "$ISO_PATH" ]]; then
  whiptail --msgbox "ISO not found:\n$ISO_PATH" 10 70
  exit 1
fi

OS_TYPE=$(whiptail --title "$APP" --menu "Select ISO type:" 15 60 5 \
  "linux-dd" "Kali / Parrot / Linux hybrid ISO direct write" \
  "windows11" "Windows 11 installer USB" \
  3>&1 1>&2 2>&3)

BOOT_MODE=$(whiptail --title "$APP" --menu "Boot mode / partition style:" 15 60 4 \
  "uefi" "UEFI / GPT" \
  "bios" "Legacy BIOS / MBR" \
  "hybrid" "Hybrid / ISO default direct-write" \
  3>&1 1>&2 2>&3)

PERSISTENCE="no"

if [[ "$OS_TYPE" == "linux-dd" ]]; then
  if whiptail --title "$APP" --yesno "Create a persistence partition after writing the ISO?" 10 70; then
    PERSISTENCE="yes"
  fi
fi

REPAIR_ACTION=$(whiptail --title "$APP" --menu "Optional repair action:" 16 70 6 \
  "none" "No repair action" \
  "mbr" "Repair / initialize MBR" \
  "gpt" "Repair / initialize GPT" \
  "grub" "Install GRUB bootloader placeholder check" \
  3>&1 1>&2 2>&3)

DRIVE_OPTIONS=()

while read -r NAME SIZE MODEL RM TYPE; do
  DEV="/dev/$NAME"

  [[ "$TYPE" != "disk" ]] && continue
  [[ "$DEV" == "$ROOT_DISK" ]] && continue

  DRIVE_OPTIONS+=("$DEV" "$SIZE | removable=$RM | $MODEL")
done < <(lsblk -dn -o NAME,SIZE,MODEL,RM,TYPE)

if [[ ${#DRIVE_OPTIONS[@]} -eq 0 ]]; then
  whiptail --msgbox "No eligible target drives found.\n\nSystem disk excluded:\n$ROOT_DISK" 12 70
  exit 1
fi

TARGET=$(whiptail --title "$APP" --menu "Select target USB drive.\n\nSystem disk excluded: $ROOT_DISK" 20 90 10 \
  "${DRIVE_OPTIONS[@]}" \
  3>&1 1>&2 2>&3)

[[ -z "${TARGET:-}" ]] && exit 0

SUMMARY="
ISO: $ISO_PATH

Target: $TARGET
System disk excluded: $ROOT_DISK

OS type: $OS_TYPE
Boot mode: $BOOT_MODE
Persistence: $PERSISTENCE
Repair action: $REPAIR_ACTION

THIS WILL ERASE:
$TARGET
"

whiptail --title "$APP" --yesno "$SUMMARY" 22 80 || exit 0

CONFIRM=$(whiptail --title "$APP" --inputbox "Type ERASE to confirm wiping $TARGET:" 10 70 3>&1 1>&2 2>&3)

[[ "$CONFIRM" == "ERASE" ]] || exit 0

unmount_target() {
  mapfile -t MOUNTS < <(lsblk -nrpo MOUNTPOINT "$TARGET" | grep -v '^$' || true)

  for m in "${MOUNTS[@]}"; do
    umount "$m" || true
  done
}

wipe_target() {
  unmount_target
  swapoff --all || true
  wipefs -a "$TARGET"
  dd if=/dev/zero of="$TARGET" bs=1M count=16 conv=fsync status=progress
  sync
}

write_linux_dd() {
  wipe_target

  whiptail --infobox "Writing Linux ISO to $TARGET...\nThis can take a while." 8 70

  dd if="$ISO_PATH" of="$TARGET" bs=4M status=progress oflag=sync conv=fsync
  sync

  if [[ "$PERSISTENCE" == "yes" ]]; then
    whiptail --infobox "Creating persistence partition..." 8 70

    parted -s "$TARGET" print >/dev/null || true
    parted -s "$TARGET" mkpart primary ext4 100% 100% || true
    partprobe "$TARGET" || true
    sleep 2

    PERSIST_PART="$(lsblk -nrpo NAME "$TARGET" | tail -n 1)"

    if [[ -n "$PERSIST_PART" && "$PERSIST_PART" != "$TARGET" ]]; then
      mkfs.ext4 -F -L persistence "$PERSIST_PART"

      TMPDIR="$(mktemp -d)"
      mount "$PERSIST_PART" "$TMPDIR"
      echo "/ union" > "$TMPDIR/persistence.conf"
      sync
      umount "$TMPDIR"
      rmdir "$TMPDIR"
    fi
  fi
}

write_windows11() {
  need mkfs.vfat
  need mkfs.ntfs
  need rsync
  need 7z

  wipe_target

  if [[ "$BOOT_MODE" == "bios" ]]; then
    parted -s "$TARGET" mklabel msdos
    parted -s "$TARGET" mkpart primary fat32 1MiB 1024MiB
    parted -s "$TARGET" set 1 boot on
    parted -s "$TARGET" mkpart primary ntfs 1024MiB 100%
  else
    parted -s "$TARGET" mklabel gpt
    parted -s "$TARGET" mkpart ESP fat32 1MiB 1024MiB
    parted -s "$TARGET" set 1 esp on
    parted -s "$TARGET" mkpart primary ntfs 1024MiB 100%
  fi

  partprobe "$TARGET"
  sleep 2

  BOOT_PART="${TARGET}1"
  DATA_PART="${TARGET}2"

  if [[ "$TARGET" =~ nvme|mmcblk ]]; then
    BOOT_PART="${TARGET}p1"
    DATA_PART="${TARGET}p2"
  fi

  mkfs.vfat -F32 -n WINBOOT "$BOOT_PART"
  mkfs.ntfs -f -L WININSTALL "$DATA_PART"

  ISO_MNT="$(mktemp -d)"
  BOOT_MNT="$(mktemp -d)"
  DATA_MNT="$(mktemp -d)"

  mount -o loop,ro "$ISO_PATH" "$ISO_MNT"
  mount "$BOOT_PART" "$BOOT_MNT"
  mount "$DATA_PART" "$DATA_MNT"

  whiptail --infobox "Copying Windows boot files..." 8 70

  rsync -a --exclude=sources/install.wim "$ISO_MNT/" "$BOOT_MNT/"
  mkdir -p "$DATA_MNT/sources"
  rsync -a "$ISO_MNT/" "$DATA_MNT/"

  sync

  umount "$ISO_MNT" "$BOOT_MNT" "$DATA_MNT"
  rmdir "$ISO_MNT" "$BOOT_MNT" "$DATA_MNT"
}

repair_action() {
  case "$REPAIR_ACTION" in
    none)
      return 0
      ;;
    mbr)
      parted -s "$TARGET" mklabel msdos
      ;;
    gpt)
      parted -s "$TARGET" mklabel gpt
      ;;
    grub)
      whiptail --msgbox "GRUB repair is distro-specific.\n\nFor Kali/Parrot live ISOs, direct ISO writing is preferred.\nFor installed Linux USB systems, run grub-install from the installed system/chroot." 14 70
      ;;
  esac
}

case "$REPAIR_ACTION" in
  mbr|gpt)
    if whiptail --yesno "Run partition-table repair before writing ISO?\n\nThis still erases $TARGET." 10 70; then
      repair_action
    fi
    ;;
esac

case "$OS_TYPE" in
  linux-dd)
    write_linux_dd
    ;;
  windows11)
    write_windows11
    ;;
esac

case "$REPAIR_ACTION" in
  grub)
    repair_action
    ;;
esac

sync

whiptail --title "$APP" --msgbox "Done.\n\nBootable USB created on:\n$TARGET" 10 70
