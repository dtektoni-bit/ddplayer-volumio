#!/bin/bash

PLUGIN_DIR="$(dirname "$0")"
DTS_FILE="$PLUGIN_DIR/device-tree/ddplayer.dts"
DTBO_FILE="/boot/overlays/ddplayer.dtbo"

echo "[DDPlayer] Compiling device tree overlay..."
dtc -@ -I dts -O dtb -o "$DTBO_FILE" "$DTS_FILE"

if [ $? -ne 0 ]; then
    echo "[DDPlayer] ERROR: DTS compilation failed!"
    exit 1
fi

echo "[DDPlayer] Overlay installed: $DTBO_FILE"

# Добавляем overlay в userconfig.txt если ещё не добавлен
CONFIG_FILE="/boot/userconfig.txt"

if ! grep -q "dtoverlay=ddplayer" "$CONFIG_FILE"; then
    echo "" >> "$CONFIG_FILE"
    echo "# DDPlayer I2S Slave DAC" >> "$CONFIG_FILE"
    echo "dtoverlay=ddplayer" >> "$CONFIG_FILE"
    echo "[DDPlayer] Added dtoverlay=ddplayer to $CONFIG_FILE"
else
    echo "[DDPlayer] dtoverlay=ddplayer already present in $CONFIG_FILE"
fi

# Устанавливаем зависимость onoff для GPIO
cd "$PLUGIN_DIR"
npm install onoff --save

echo "[DDPlayer] Installation complete. Reboot required."
