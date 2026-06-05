#!/bin/bash
set -euo pipefail

CUSTOM_SCRIPT="/etc/grub.d/40_custom"
BACKUP_DIR="/var/backups/grub-order"

MARKER_START="# BEGIN BOOTCFG CUSTOM ENTRIES"
MARKER_END="# END BOOTCFG CUSTOM ENTRIES"

log() { echo "[REVERT] $1"; }

[[ $EUID -ne 0 ]] && { echo "Ce script doit être exécuté en tant que root."; exit 1; }

log "Restore original GRUB order"

# -----------------------------
# RESTORE MEMTEST
# -----------------------------
if [[ -f /etc/grub.d/80_memtest86+ ]]; then
    mv /etc/grub.d/80_memtest86+ /etc/grub.d/20_memtest86+
    log "Memtest86+ restauré en 20_memtest86+"
elif [[ -f "$BACKUP_DIR/20_memtest86+" ]]; then
    cp "$BACKUP_DIR/20_memtest86+" /etc/grub.d/20_memtest86+
    log "Memtest86+ restauré depuis le backup"
else
    log "AVERTISSEMENT : 20_memtest86+ introuvable (ni déplacé ni backup)"
fi

# -----------------------------
# RESTORE UEFI
# -----------------------------
if [[ -f /etc/grub.d/81_uefi-firmware ]]; then
    mv /etc/grub.d/81_uefi-firmware /etc/grub.d/30_uefi-firmware
    log "UEFI Firmware restauré en 30_uefi-firmware"
elif [[ -f "$BACKUP_DIR/30_uefi-firmware" ]]; then
    cp "$BACKUP_DIR/30_uefi-firmware" /etc/grub.d/30_uefi-firmware
    log "UEFI Firmware restauré depuis le backup"
else
    log "AVERTISSEMENT : 30_uefi-firmware introuvable (ni déplacé ni backup)"
fi

# -----------------------------
# REMOVE CUSTOM ENTRIES FROM 40_custom
# -----------------------------
if [[ -f "$CUSTOM_SCRIPT" ]] && grep -q "$MARKER_START" "$CUSTOM_SCRIPT"; then
    sed -i "/$MARKER_START/,/$MARKER_END/d" "$CUSTOM_SCRIPT"
    # Nettoyer les lignes vides en fin de fichier
    sed -i -e '/^[[:space:]]*$/{ /./!d }' "$CUSTOM_SCRIPT"
    log "Entrées custom supprimées de $CUSTOM_SCRIPT"
else
    log "Aucun bloc custom trouvé dans $CUSTOM_SCRIPT (déjà propre)"
fi

# -----------------------------
# REGENERATE GRUB
# -----------------------------
log "Regenerate GRUB"
update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg

log "RESTORED CLEAN STATE"
