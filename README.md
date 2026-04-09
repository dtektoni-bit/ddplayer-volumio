# DDPlayer DAC - Volumio 4 Plugin

Volumio 4 plugin for DDPlayer I2S Slave DAC with external clock generator.

## Hardware

- **DAC**: AK4490 / PCM1794 (or compatible)
- **Clock generator**: AK4113 in hardware mode with dual crystal oscillators
  - 22.5792 MHz for 44.1kHz family
  - 24.576 MHz for 48kHz family
- **Raspberry Pi**: I2S Slave mode (clock provided by AK4113)

## GPIO Pin Assignment

| GPIO (BCM) | Pi Pin | Function |
|---|---|---|
| 6 | 31 | Clock grid select (LOW=44.1kHz, HIGH=48kHz) |
| 5 | 29 | OCKS0 - AK4113 clock multiplier bit 0 |
| 13 | 33 | OCKS1 - AK4113 clock multiplier bit 1 |
| 16 | 36 | Mute (active high) |
| 26 | 37 | Reset (active high) |

## Sample Rate / GPIO Table

| Sample Rate | GPIO6 | GPIO5 | GPIO13 |
|---|---|---|---|
| 44100 Hz | LOW | LOW | LOW |
| 48000 Hz | HIGH | HIGH | LOW |
| 88200 Hz | LOW | LOW | HIGH |
| 96000 Hz | HIGH | LOW | HIGH |
| 176400 Hz | LOW | HIGH | HIGH |
| 192000 Hz | HIGH | HIGH | HIGH |

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

## Uninstall

```bash
cd /home/volumio/ddplayer-volumio
sudo ./uninstall.sh
sudo reboot
```

## Notes

- The kernel module is pre-built for Volumio kernel `6.12.74-v7l+`
- If Volumio updates to a new kernel, the script will recompile automatically
- SSH timeout during installation: use `screen` to avoid disconnection:
  ```bash
  sudo apt-get install -y screen
  screen -S install
  sudo ./install.sh
  # If disconnected: screen -r install
  ```

## Credits

- Kernel driver: [Dima Sivov](https://github.com/dsivov/dd_player_2026)
- Volumio plugin: dtektoni-bit
