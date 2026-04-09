# DDPlayer DAC - Volumio 4 Plugin

Volumio 4 plugin for DDPlayer I2S Slave DAC with external clock generator.

## Hardware

- **DAC**: AK4490 / PCM1794 (or compatible)
- **Clock generator**: AK4113 in hardware mode with dual crystal oscillators
  - 22.5792 MHz for 44.1kHz family
  - 24.576 MHz for 48kHz family
- **Raspberry Pi**: I2S Slave mode (clock provided by AK4113)

## GPIO Pin Assignment

| GPIO (BCM) | Pi Pin | AK4113 | Function |
|---|---|---|---|
| 6 | 31 | - | Clock grid select (LOW=44.1kHz, HIGH=48kHz) |
| 5 | 29 | OCKS1 | Clock multiplier bit 1 |
| 13 | 33 | OCKS0 | Clock multiplier bit 0 |
| 16 | 36 | - | Mute (active high) |
| 26 | 37 | - | Reset (active high) |

## Sample Rate / GPIO Table

| Sample Rate | GPIO 6 (grid) | GPIO 13 (OCKS0) | GPIO 5 (OCKS1) |
|---|---|---|---|
| 44100 Hz | LOW | 1 | 0 |
| 48000 Hz | HIGH | 1 | 0 |
| 88200 Hz | LOW | 0 | 0 |
| 96000 Hz | HIGH | 0 | 0 |
| 176400 Hz | LOW | 1 | 1 |
| 192000 Hz | HIGH | 1 | 1 |

## Installation

Connect to Volumio via SSH and run:

```bash
cd /home/volumio
git clone https://github.com/dtektoni-bit/ddplayer-volumio
cd ddplayer-volumio
chmod +x install.sh uninstall.sh
sudo ./install.sh
```

The install script will:
1. Check if the pre-built kernel module matches your kernel
2. If yes — install immediately (fast)
3. If no — compile from source automatically (~15 minutes)

After installation:
- Go to **Settings → Playback Options → I2S DAC**
- Select **DDPlayer DAC**
- Save and reboot

## Note on long installation

If SSH disconnects during compilation, use `screen`:

```bash
sudo apt-get install -y screen
screen -S install
sudo ./install.sh
# If disconnected: screen -r install
```

## Uninstall

```bash
cd /home/volumio/ddplayer-volumio
sudo ./uninstall.sh
sudo reboot
```

## Notes

- Pre-built kernel module is for Volumio kernel `6.12.74-v7l+`
- If Volumio updates to a new kernel, the script recompiles automatically

## Credits

- Kernel driver: [Dima Sivov](https://github.com/dsivov/dd_player_2026)
- Volumio plugin: dtektoni-bit
