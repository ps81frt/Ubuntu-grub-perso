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

MT_X64=""
MT_IA32=""
MT_GENERIC=""

for path in \
    /boot/mt86+x64 \
    /boot/mt86+x64.efi \
    /boot/memtest86+x64.efi \
    /boot/memtest86+x64 \
    /boot/efi/EFI/memtest86+/memtest86+x64.efi; do
    [[ -f "$path" ]] && { MT_X64="$path"; break; }
done

for path in \
    /boot/mt86+ia32 \
    /boot/mt86+ia32.efi \
    /boot/memtest86+ia32.efi \
    /boot/memtest86+ia32; do
    [[ -f "$path" ]] && { MT_IA32="$path"; break; }
done

if [[ -z "$MT_X64" && -z "$MT_IA32" ]]; then
    for path in \
        /boot/memtest86+.bin \
        /boot/memtest86+ \
        /boot/memtest86 \
        /boot/memtest; do
        [[ -f "$path" ]] && { MT_GENERIC="$path"; break; }
    done
fi

BLOCK="$MARKER_START\n"

if [[ -n "$MT_X64" || -n "$MT_IA32" ]]; then
    BLOCK+="submenu 'Memory Test (Memtest86+)' --class memtest {\n"
    if [[ -n "$MT_X64" ]]; then
        BLOCK+="    menuentry 'Memtest x64' {\n"
        BLOCK+="        linux16 $MT_X64\n"
        BLOCK+="    }\n"
        BLOCK+="    menuentry 'Memtest x64 serial' {\n"
        BLOCK+="        linux16 $MT_X64\n"
        BLOCK+="        set gfxpayload=text\n"
        BLOCK+="    }\n"
    fi
    if [[ -n "$MT_IA32" ]]; then
        BLOCK+="    menuentry 'Memtest ia32' {\n"
        BLOCK+="        linux16 $MT_IA32\n"
        BLOCK+="    }\n"
        BLOCK+="    menuentry 'Memtest ia32 serial' {\n"
        BLOCK+="        linux16 $MT_IA32\n"
        BLOCK+="        set gfxpayload=text\n"
        BLOCK+="    }\n"
    fi
    BLOCK+="}\n"
    log "Submenu Memtest86+ UEFI ajouté (x64=${MT_X64:-none} ia32=${MT_IA32:-none})"
elif [[ -n "$MT_GENERIC" ]]; then
    BLOCK+="menuentry 'Memory Test (Memtest86+)' --class memtest {\n"
    BLOCK+="    linux16 $MT_GENERIC\n"
    BLOCK+="}\n"
    log "Entrée Memtest86+ legacy ajoutée ($MT_GENERIC)"
else
    BLOCK+="# Memtest86+ non détecté sur ce système\n"
    log "AVERTISSEMENT : aucun binaire Memtest86+ trouvé, entrée commentée"
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
