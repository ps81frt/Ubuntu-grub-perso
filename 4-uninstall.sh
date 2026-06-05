#!/bin/bash

set -e # Arrête le script en cas d’erreur

THEME_NAME="UbuntuPerso"
THEME_DIR="/boot/grub/themes/$THEME_NAME"
GRUB_CONFIG="/etc/default/grub"
GRUB_CMD="grub-mkconfig"

if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root."
    exit 1
fi

if [[ -d "$THEME_DIR" ]]; then
    rm -rf "$THEME_DIR"
    echo "Le thème '$THEME_NAME' a été supprimé."
else
    echo "Le thème '$THEME_NAME' n’est pas installé."
fi

if grep -q "^GRUB_THEME=" "$GRUB_CONFIG"; then
    sed -i "/^GRUB_THEME=/d" "$GRUB_CONFIG"
    echo "Le paramètre du thème GRUB a été supprimé de la configuration."
fi

if command -v grub-mkconfig &>/dev/null; then
    $GRUB_CMD -o /boot/grub/grub.cfg
elif command -v update-grub &>/dev/null; then
    update-grub
else
    echo "Impossible de mettre à jour GRUB automatiquement. Veuillez le mettre à jour manuellement."
    exit 1
fi

echo "La désinstallation du thème '$THEME_NAME' s’est terminée avec succès !"
