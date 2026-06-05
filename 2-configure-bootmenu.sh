#!/bin/bash
set -euo pipefail

MEMTEST_SCRIPT="/etc/grub.d/20_memtest86+"
UEFI_SCRIPT="/etc/grub.d/30_uefi-firmware"
CUSTOM_SCRIPT="/etc/grub.d/40_custom"
BACKUP_DIR="/var/backups/grub-order"

MARKER_START="# BEGIN BOOTCFG CUSTOM ENTRIES"
MARKER_END="# END BOOTCFG CUSTOM ENTRIES"

log() { echo "[BOOTCFG] $1"; }

[[ $EUID -ne 0 ]] && { echo "Ce script doit être exécuté en tant que root."; exit 1; }

log "Move Memtest + UEFI to bottom (safe ordering)"

mkdir -p "$BACKUP_DIR"

# -----------------------------
# MEMTEST MOVE
# -----------------------------
if [[ -f "$MEMTEST_SCRIPT" ]]; then
    cp "$MEMTEST_SCRIPT" "$BACKUP_DIR/20_memtest86+"
    mv "$MEMTEST_SCRIPT" /etc/grub.d/80_memtest86+
    log "Memtest86+ déplacé en 80_memtest86+"
fi

# -----------------------------
# UEFI MOVE
# -----------------------------
if [[ -f "$UEFI_SCRIPT" ]]; then
    cp "$UEFI_SCRIPT" "$BACKUP_DIR/30_uefi-firmware"
    mv "$UEFI_SCRIPT" /etc/grub.d/81_uefi-firmware
    log "UEFI Firmware déplacé en 81_uefi-firmware"
fi

# -----------------------------
# INJECT CUSTOM ENTRIES IN 40_custom
# -----------------------------
log "Inject custom entries with icons into $CUSTOM_SCRIPT"

if grep -q "$MARKER_START" "$CUSTOM_SCRIPT" 2>/dev/null; then
    sed -i "/$MARKER_START/,/$MARKER_END/d" "$CUSTOM_SCRIPT"
    log "Ancien bloc custom supprimé (remplacement)"
fi

MEMTEST_EFI=""
for path in \
    /boot/memtest86+x64.efi \
    /boot/memtest86+.efi \
    /boot/efi/EFI/memtest86+/memtest86+x64.efi; do
    if [[ -f "$path" ]]; then
        MEMTEST_EFI="$path"
        break
    fi
done

MEMTEST_BIN=""
for path in /boot/memtest86+.bin /boot/memtest86+; do
    if [[ -f "$path" ]]; then
        MEMTEST_BIN="$path"
        break
    fi
done

BLOCK="$MARKER_START\n"

if [[ -n "$MEMTEST_EFI" ]]; then
    BLOCK+="menuentry 'Memory Test (Memtest86+)' --class memtest {\n"
    BLOCK+="    insmod part_gpt\n"
    BLOCK+="    insmod fat\n"
    BLOCK+="    insmod chain\n"
    BLOCK+="    search --no-floppy --set=root --file '$MEMTEST_EFI'\n"
    BLOCK+="    chainloader '$MEMTEST_EFI'\n"
    BLOCK+="}\n"
    log "Entrée Memtest86+ EFI ajoutée ($MEMTEST_EFI)"
elif [[ -n "$MEMTEST_BIN" ]]; then
    BLOCK+="menuentry 'Memory Test (Memtest86+)' --class memtest {\n"
    BLOCK+="    insmod part_msdos\n"
    BLOCK+="    insmod ext2\n"
    BLOCK+="    linux16 '$MEMTEST_BIN'\n"
    BLOCK+="}\n"
    log "Entrée Memtest86+ legacy ajoutée ($MEMTEST_BIN)"
else
    BLOCK+="# Memtest86+ non détecté sur ce système\n"
    log "AVERTISSEMENT : binaire Memtest86+ introuvable, entrée commentée"
fi

BLOCK+="menuentry 'Paramètres du firmware UEFI' --class efi {\n"
BLOCK+="    fwsetup\n"
BLOCK+="}\n"
BLOCK+="$MARKER_END"

if [[ ! -f "$CUSTOM_SCRIPT" ]]; then
    printf '#!/bin/sh\nexec tail -n +3 $0\n' > "$CUSTOM_SCRIPT"
    chmod +x "$CUSTOM_SCRIPT"
fi

printf "\n%b\n" "$BLOCK" >> "$CUSTOM_SCRIPT"
log "Entrées injectées dans $CUSTOM_SCRIPT"

# -----------------------------
# REGENERATE GRUB
# -----------------------------
log "Regenerate GRUB"
update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg

log "DONE"
