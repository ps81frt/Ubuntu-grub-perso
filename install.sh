#!/bin/bash

set -e # Arrête le script en cas d’erreurs

THEME_NAME="UbuntuPerso"
THEME_ARCHIVE="Ubuntu.tar"
THEME_DIR="/boot/grub/themes/$THEME_NAME"
GRUB_CONFIG="/etc/default/grub"
GRUB_CMD="grub-mkconfig"

if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root."
    exit 1
fi

mkdir -p /boot/grub/themes

rm -rf "$THEME_DIR"

mkdir "$THEME_DIR"
tar -xf "$THEME_ARCHIVE" -C "$THEME_DIR"

if grep -q "^GRUB_THEME=" "$GRUB_CONFIG"; then
    sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$THEME_DIR/theme.txt\"|" "$GRUB_CONFIG"
else
    echo "GRUB_THEME=\"$THEME_DIR/theme.txt\"" >>"$GRUB_CONFIG"
fi

if command -v grub-mkconfig &>/dev/null; then
    $GRUB_CMD -o /boot/grub/grub.cfg
elif command -v update-grub &>/dev/null; then
    update-grub
else
    echo "Impossible de mettre à jour GRUB automatiquement. Veuillez le mettre à jour manuellement."
    exit 1
fi

echo "Thème '$THEME_NAME' installé avec succès !"
