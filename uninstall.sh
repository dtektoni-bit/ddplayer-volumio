#!/bin/bash

echo "[DDPlayer] Uninstalling DDPlayer..."

# Удаляем overlay файл
rm -f /boot/overlays/ddplayer.dtbo

# Убираем строки из userconfig.txt
CONFIG_FILE="/boot/userconfig.txt"
sed -i '/# DDPlayer I2S Slave DAC/d' "$CONFIG_FILE"
sed -i '/dtoverlay=ddplayer/d' "$CONFIG_FILE"

echo "[DDPlayer] Uninstall complete. Reboot required."
