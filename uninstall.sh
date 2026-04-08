#!/bin/bash
# DDPlayer DAC - Volumio 4 uninstall script

KERNEL_VER="$(uname -r)"
DACS_JSON="/volumio/app/plugins/system_controller/i2s_dacs/dacs.json"
USERCONFIG="/boot/userconfig.txt"

echo "Uninstalling DDPlayer DAC..."

# Unload module if loaded
rmmod snd_soc_ddplayer_dac 2>/dev/null || true

# Remove kernel module
rm -f "/lib/modules/$KERNEL_VER/kernel/sound/soc/bcm/snd-soc-ddplayer-dac.ko"
rm -f "/usr/lib/modules/$KERNEL_VER/kernel/sound/soc/bcm/snd-soc-ddplayer-dac.ko"
depmod -a

# Remove overlay
rm -f /boot/overlays/ddplayer-dac.dtbo

# Remove from userconfig.txt
sed -i '/# DDPlayer DAC/d' "$USERCONFIG"
sed -i '/dtoverlay=ddplayer-dac/d' "$USERCONFIG"

# Remove from dacs.json
if [ -f "$DACS_JSON" ]; then
    python3 -c "
import json
with open('$DACS_JSON', 'r') as f:
    data = json.load(f)
for device in data['devices']:
    device['data'] = [d for d in device['data'] if d.get('id') != 'ddplayer-dac']
with open('$DACS_JSON', 'w') as f:
    json.dump(data, f, indent=2)
print('dacs.json updated')
" 2>/dev/null || true
fi

echo "DDPlayer DAC uninstalled. Please reboot."
