#!/bin/bash
set -euo pipefail

log() { echo "[UNINSTALL] $1"; }

[[ $EUID -ne 0 ]] && exit 1

log "Restore original order"

# restore memtest
if [[ -f /etc/grub.d/80_memtest86+ ]]; then
    mv /etc/grub.d/80_memtest86+ /etc/grub.d/20_memtest86+
fi

# restore uefi
if [[ -f /etc/grub.d/81_uefi-firmware ]]; then
    mv /etc/grub.d/81_uefi-firmware /etc/grub.d/30_uefi-firmware
fi

log "Update GRUB"

update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg

log "RESTORED ORIGINAL STATE"
