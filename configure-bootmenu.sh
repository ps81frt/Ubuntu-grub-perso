#!/bin/bash

set -euo pipefail

GRUB_CUSTOM="/etc/grub.d/40_custom"
GRUB_CUSTOM_BAK="/etc/grub.d/40_custom.bak"
MEMTEST_SCRIPT="/etc/grub.d/20_memtest86+"

log() {
    echo "[BOOTCFG] $1"
}

if [[ $EUID -ne 0 ]]; then
    echo "Root requis"
    exit 1
fi

log "Backup 40_custom"
[ -f "$GRUB_CUSTOM" ] && cp "$GRUB_CUSTOM" "$GRUB_CUSTOM_BAK"

# --------------------------------------------------
# MEMTEST HANDLING (portable)
# --------------------------------------------------

log "Configuration Memtest"

if [ -f "$MEMTEST_SCRIPT" ]; then
    chmod -x "$MEMTEST_SCRIPT" 2>/dev/null || true
fi

# détecte si déjà ajouté
if ! grep -q "Memory Test (Memtest86+)" "$GRUB_CUSTOM" 2>/dev/null; then
cat <<'EOF' >> "$GRUB_CUSTOM"

menuentry "Memory Test (Memtest86+)" --class memtest {
    linux16 /boot/mt86+x64
}
EOF
fi

# --------------------------------------------------
# EFI ENTRY (safe multi-boot)
# --------------------------------------------------

if ! grep -q "UEFI Firmware Settings" "$GRUB_CUSTOM" 2>/dev/null; then
cat <<'EOF' >> "$GRUB_CUSTOM"

if [ "${grub_platform}" = "efi" ]; then
menuentry "UEFI Firmware Settings" --class efi {
    fwsetup
}
fi

EOF
fi

# --------------------------------------------------
# CLEAN DUPLICATES (safe)
# --------------------------------------------------

log "Nettoyage doublons memtest"
sed -i '/Memory Test (Memtest86+)/,/^}/d' "$GRUB_CUSTOM" 2>/dev/null || true

# --------------------------------------------------
# UPDATE GRUB (portable)
# --------------------------------------------------

log "Regénération GRUB"

if command -v update-grub >/dev/null 2>&1; then
    update-grub
else
    grub-mkconfig -o /boot/grub/grub.cfg
fi

log "OK bootmenu deployable terminé"
