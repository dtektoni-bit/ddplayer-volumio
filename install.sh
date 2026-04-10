#!/bin/bash
# DDPlayer DAC - Volumio 4 install script

set -e

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
DRIVER_DIR="$PLUGIN_DIR/driver"
KERNEL_VER="$(uname -r)"
KERNEL_SRC="/home/volumio/ddplayer-kernel-src"
MODULE_DEST="/lib/modules/$KERNEL_VER/kernel/sound/soc/bcm"
OVERLAY_DEST="/boot/overlays"
DACS_JSON="/volumio/app/plugins/system_controller/i2s_dacs/dacs.json"
USERCONFIG="/boot/userconfig.txt"
PREBUILT_KO="$DRIVER_DIR/snd-soc-ddplayer-dac.ko"

echo "================================================"
echo " DDPlayer DAC - Installing for kernel $KERNEL_VER"
echo "================================================"

# --- Check if pre-built module matches current kernel ---
need_compile=true

if [ -f "$PREBUILT_KO" ]; then
    KO_VER=$(strings "$PREBUILT_KO" | grep -o 'vermagic=[^ ]*' | cut -d= -f2 | head -1 | cut -d- -f1 | tr -d '+')
    RUN_VER=$(echo "$KERNEL_VER" | cut -d- -f1 | tr -d '+')
    echo "Pre-built module kernel: $KO_VER"
    echo "Running kernel:          $RUN_VER"
    if [ "$KO_VER" = "$RUN_VER" ]; then
        echo "Kernel matches - using pre-built module"
        need_compile=false
    else
        echo "Kernel mismatch - recompilation required"
    fi
fi

if [ "$need_compile" = true ]; then

    # --- Step 1: Install build dependencies ---
    echo ""
    echo "[1/5] Installing build dependencies..."
    apt-get update -qq
    apt-get install -y gcc make flex bison libssl-dev 2>/dev/null || true

    # --- Step 2: Get kernel source ---
    echo ""
    echo "[2/5] Setting up kernel source..."

    if [ ! -d "$KERNEL_SRC" ]; then
        if [ ! -f /usr/local/bin/rpi-source ]; then
            wget -q https://raw.githubusercontent.com/RPi-Distro/rpi-source/master/rpi-source \
                -O /usr/local/bin/rpi-source
            chmod +x /usr/local/bin/rpi-source
        fi
        echo "Downloading kernel source (this may take 10-15 minutes)..."
        rpi-source --dest /home/volumio 2>&1 | grep -E "Download|Unpack|Setup|ERROR|error" || true

        LINUX_SRC=$(find /home/volumio -maxdepth 1 -name "linux-*" -type d | head -1)
        if [ -z "$LINUX_SRC" ]; then
            echo "ERROR: Could not find kernel source directory"
            exit 1
        fi
        ln -sf "$LINUX_SRC" "$KERNEL_SRC"
    else
        echo "Kernel source already present at $KERNEL_SRC"
    fi

    ln -sf "$KERNEL_SRC" "/lib/modules/$KERNEL_VER/build" 2>/dev/null || true

    # --- Step 3: Prepare kernel source ---
    echo ""
    echo "[3/5] Preparing kernel source..."

    cd "$KERNEL_SRC"
    zcat /proc/config.gz | tee .config > /dev/null
    sed -i "s/CONFIG_LOCALVERSION=\".*\"/CONFIG_LOCALVERSION=\"-v7l+\"/" .config 2>/dev/null || true
    sed -i 's/^EXTRAVERSION =.*/EXTRAVERSION = +/' Makefile 2>/dev/null || true
    bash -c "echo '#define UTS_RELEASE \"$KERNEL_VER\"' > include/generated/utsrelease.h" 2>/dev/null || true
    make oldconfig < /dev/null 2>/dev/null || true
    make modules_prepare 2>&1 | tail -3

    # --- Step 4: Build Module.symvers ---
    echo ""
    echo "[4/5] Building Module.symvers from installed modules..."

    python3 << 'PYEOF'
import struct, glob, lzma, os

def extract_versions(data):
    if data[:4] != b'\x7fELF':
        return []
    try:
        e_shoff = struct.unpack_from('<I', data, 32)[0]
        e_shentsize = struct.unpack_from('<H', data, 46)[0]
        e_shnum = struct.unpack_from('<H', data, 48)[0]
        e_shstrndx = struct.unpack_from('<H', data, 50)[0]
        shstr_off = struct.unpack_from('<I', data, e_shoff + e_shstrndx * e_shentsize + 16)[0]
        results = []
        for i in range(e_shnum):
            sh_base = e_shoff + i * e_shentsize
            sh_name_off = struct.unpack_from('<I', data, sh_base)[0]
            name_end = data.index(b'\x00', shstr_off + sh_name_off)
            name = data[shstr_off + sh_name_off:name_end].decode()
            if name == '__versions':
                sh_offset = struct.unpack_from('<I', data, sh_base + 16)[0]
                sh_size = struct.unpack_from('<I', data, sh_base + 20)[0]
                section = data[sh_offset:sh_offset + sh_size]
                for j in range(0, len(section), 64):
                    entry = section[j:j+64]
                    if len(entry) < 8:
                        break
                    crc = struct.unpack_from('<I', entry, 0)[0]
                    sym = entry[4:].rstrip(b'\x00').decode('ascii', errors='ignore')
                    if sym:
                        results.append((crc, sym))
        return results
    except:
        return []

kernel_ver = os.popen('uname -r').read().strip()
found = {}

for pattern in [
    f'/usr/lib/modules/{kernel_ver}/kernel/**/*.ko.xz',
    f'/usr/lib/modules/{kernel_ver}/kernel/**/*.ko',
    f'/lib/modules/{kernel_ver}/kernel/**/*.ko.xz',
    f'/lib/modules/{kernel_ver}/kernel/**/*.ko',
]:
    for ko in glob.glob(pattern, recursive=True):
        try:
            if ko.endswith('.xz'):
                with lzma.open(ko) as f:
                    data = f.read()
            else:
                with open(ko, 'rb') as f:
                    data = f.read()
            for crc, sym in extract_versions(data):
                if sym not in found:
                    found[sym] = crc
        except:
            pass

symvers_path = '/home/volumio/ddplayer-kernel-src/Module.symvers'
with open(symvers_path, 'w') as f:
    for sym, crc in found.items():
        f.write(f'0x{crc:08x}\t{sym}\tvmlinux\tEXPORT_SYMBOL\t\n')

print(f"Module.symvers: {len(found)} symbols extracted")
PYEOF

    # --- Step 5: Compile driver ---
    echo ""
    echo "[5/5] Compiling DDPlayer DAC driver..."

    cd "$DRIVER_DIR"
    cp "$KERNEL_SRC/Module.symvers" ./Module.symvers
    KBUILD_MODPOST_WARN=1 make -C "$KERNEL_SRC" M=$(pwd) ARCH=arm CROSS_COMPILE= modules
    echo "Driver compiled successfully"

fi

# --- Build DT overlay ---
cd "$DRIVER_DIR"
dtc -@ -I dts -O dtb -W no-unit_address_vs_reg -o ddplayer-dac.dtbo ddplayer-dac.dts

# --- Install ---
echo ""
echo "Installing driver..."

cp "$DRIVER_DIR/snd-soc-ddplayer-dac.ko" "$MODULE_DEST/"
depmod -a
cp "$DRIVER_DIR/ddplayer-dac.dtbo" "$OVERLAY_DEST/"

if ! grep -q "dtoverlay=ddplayer-dac" "$USERCONFIG"; then
    echo "" >> "$USERCONFIG"
    echo "# DDPlayer DAC" >> "$USERCONFIG"
    echo "dtoverlay=ddplayer-dac" >> "$USERCONFIG"
fi

if [ -f "$DACS_JSON" ]; then
    if ! grep -q "ddplayer-dac" "$DACS_JSON"; then
        python3 -c "
import json
with open('$DACS_JSON', 'r') as f:
    data = json.load(f)
entry = {'id':'ddplayer-dac','name':'DDPlayer DAC','overlay':'ddplayer-dac','alsanum':'2','alsacard':'sndrpiddplayerd','mixer':'','modules':'snd-soc-ddplayer-dac','script':'','needsreboot':'yes'}
for device in data['devices']:
    if device['name'] == 'Raspberry PI':
        device['data'].insert(0, entry)
        break
with open('$DACS_JSON', 'w') as f:
    json.dump(data, f, indent=2)
print('dacs.json updated')
"
    fi
fi

echo ""
echo "================================================"
echo " DDPlayer DAC installed!"
echo " Please select DDPlayer DAC in Volumio settings"
echo " and reboot."
echo "================================================"
echo "plugininstallend"
