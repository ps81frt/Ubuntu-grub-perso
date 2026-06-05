#!/bin/bash
set -euo pipefail

MEMTEST_SCRIPT="/etc/grub.d/20_memtest86+"
UEFI_SCRIPT="/etc/grub.d/30_uefi-firmware"

log() {
    echo "[BOOTCFG] $1"
}

[[ $EUID -ne 0 ]] && exit 1

# --------------------------------------------------
# MEMTEST (MOVE ONLY → ORDER CONTROL)
# --------------------------------------------------
log "Move Memtest to bottom"

if [[ -f "$MEMTEST_SCRIPT" ]]; then
    mv "$MEMTEST_SCRIPT" /etc/grub.d/80_memtest86+
fi

# --------------------------------------------------
# UEFI (MOVE ONLY → ORDER CONTROL)
# --------------------------------------------------
log "Move UEFI to bottom"

if [[ -f "$UEFI_SCRIPT" ]]; then
    mv "$UEFI_SCRIPT" /etc/grub.d/81_uefi-firmware
fi

# --------------------------------------------------
# UPDATE GRUB
# --------------------------------------------------
log "Regeneration GRUB"

if command -v update-grub >/dev/null 2>&1; then
    update-grub
else
    grub-mkconfig -o /boot/grub/grub.cfg
fi

log "DONE"
