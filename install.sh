#!/bin/bash

PLUGIN_DIR="$(dirname "$0")"
DTS_FILE="$PLUGIN_DIR/device-tree/ddplayer.dts"
DTBO_FILE="/boot/overlays/ddplayer.dtbo"

echo "Installing DDPlayer plugin..."

# Компилируем device tree overlay
echo "Compiling device tree overlay..."
dtc -@ -I dts -O dtb -o "$DTBO_FILE" "$DTS_FILE"

if [ $? -ne 0 ]; then
    echo "ERROR: DTS compilation failed!"
    exit 1
fi

echo "Overlay installed: $DTBO_FILE"

# Добавляем overlay в userconfig.txt если ещё не добавлен
CONFIG_FILE="/boot/userconfig.txt"

if ! grep -q "dtoverlay=ddplayer" "$CONFIG_FILE"; then
    echo "" >> "$CONFIG_FILE"
    echo "# DDPlayer I2S Slave DAC" >> "$CONFIG_FILE"
    echo "dtoverlay=ddplayer" >> "$CONFIG_FILE"
    echo "Added dtoverlay=ddplayer to $CONFIG_FILE"
else
    echo "dtoverlay=ddplayer already present in $CONFIG_FILE"
fi

# Устанавливаем npm зависимости
echo "Installing npm dependencies..."
cd "$PLUGIN_DIR"
npm install --no-install-recommends

echo "DDPlayer installation complete. Please reboot."

# ОБЯЗАТЕЛЬНО — сигнал Volumio что установка завершена
echo "plugininstallend"
