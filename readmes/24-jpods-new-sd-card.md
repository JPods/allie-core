# JPods New SD Card — Complete Setup Guide

How to build a JPods Pi Zero from a blank SD card to a running pod.

**If you're doing this after time away — ask Allie.** She has the full system context and can walk you through it.

---

## What You Need

| Item | Notes |
|------|-------|
| SD card | 16GB minimum, Class 10 or faster |
| SD card reader | Built-in Mac slot or USB adapter |
| Raspberry Pi Imager | Free — download from raspberrypi.com/software |
| Mac on 192.168.1.x WiFi | Same network as the MQTT broker |
| JPods OS files | `/Users/williamjames/Documents/08_JPods/03_Technology/JPodsSM_RPi/jpod_OS/` |

---

## Step 1 — Flash the SD Card

**Download and open Raspberry Pi Imager.**

- **Device:** Raspberry Pi Zero / Zero W (use Zero 2W if that's the model)
- **OS:** Raspberry Pi OS Lite (32-bit) — no desktop needed, saves memory
  - Choose OS → Raspberry Pi OS (other) → Raspberry Pi OS Lite (32-bit)
- **Storage:** Select your SD card

**Before clicking Write — click the gear icon (Advanced Settings):**

| Setting | Value |
|---------|-------|
| Hostname | `jpods-pod1` (or pod2, pod3...) |
| Enable SSH | ✓ — Use password authentication |
| Username | `pi` |
| Password | `1111pass` — standard demo password for all JPods pods |
| WiFi SSID | your network name |
| WiFi Password | your network password |
| WiFi Country | US |
| Timezone | America/New_York (or your zone) |

Click **Save** then **Write**. Takes 3-5 minutes.

---

## Step 2 — Configure USB Gadget Mode

After flashing, eject and reinsert the SD card. The `boot` partition will mount on your Mac.

The partition mounts as `/Volumes/bootfs` on Mac.

**Add USB gadget overlay to config.txt:**
```bash
echo "dtoverlay=dwc2" >> /Volumes/bootfs/config.txt
```

**Add gadget module to cmdline.txt** (appends to the single line):
```bash
sed -i '' 's/$/ modules-load=dwc2,g_ether/' /Volumes/bootfs/cmdline.txt
```

**Enable SSH:**
```bash
touch /Volumes/bootfs/ssh
```

**Verify before ejecting:**
```bash
tail -3 /Volumes/bootfs/config.txt        # should show dtoverlay=dwc2
cat /Volumes/bootfs/cmdline.txt           # should end with modules-load=dwc2,g_ether
ls /Volumes/bootfs/ssh                    # should exist
```

**Eject both partitions** before removing the SD card.

---

## Step 3 — First Boot

1. Insert SD card into Pi Zero
2. Plug USB data cable into Pi Zero **USB port** (center port — not PWR IN)
3. Plug other end into Mac
4. Wait **60 seconds** — Pi Zero boots slowly

**Find the Pi:**
```bash
arp -a | grep "192.168.1"
# or
ping -c1 jpods-pod1.local
```

**SSH in:**
```bash
ssh pi@jpods-pod1.local
# or
ssh pi@192.168.1.XXX
```

---

## Step 4 — Install Dependencies

On the Pi, run the JPods setup script. First, copy it or run directly:

```bash
# Update system first
sudo apt update && sudo apt upgrade -y

# Run JPods setup
cd /home/pi
bash EasySetup.sh
```

Or install manually:
```bash
sudo apt install python3 python3-pip i2c-tools python3-smbus -y
sudo pip install rpi_ws281x adafruit-circuitpython-neopixel
sudo pip install adafruit-blinka
sudo pip install adafruit-circuitpython-vl6180x
sudo pip install pyserial pypng
sudo pip install paho-mqtt==1.6.1
```

**Enable I2C:**
```bash
sudo raspi-config
# Interface Options → I2C → Enable
```

---

## Step 5 — Copy JPods OS Files

From your Mac, copy the jpod_OS folder to the Pi:

```bash
scp -r /Users/williamjames/Documents/08_JPods/03_Technology/JPodsSM_RPi/jpod_OS/ pi@jpods-pod1.local:/home/pi/jpod_OS/
```

---

## Step 6 — Configure the Pod

On the Pi, edit the hardware spec file for this pod:

```bash
nano /home/pi/jpod_OS/hardware/1.json
```

Key fields to verify:

```json
{
  "podName": "POD_1",
  "MQTTHost": "192.168.1.252",
  ...
}
```

Update `podName` to match this pod (POD_1, POD_2, etc.).
`MQTTHost` is Bill's Mac — `192.168.1.252`.

---

## Step 7 — Verify Hardware

**Check I2C bus:**
```bash
i2cdetect -y 1
```

Expected:
- `0x0A` — Romeo BLE motor controller
- `0x32` — HuskyLens camera

If missing — check ribbon cables before going further.

---

## Step 8 — First Run

```bash
cd /home/pi/jpod_OS
sudo python launcher.py 1 "192.168.1.252"
```

You should see:
```
MQTT Connected
>>BOOT: POD_1 | DIST: 100 | LINE: 1
```

On the Mac with mosquitto running:
```bash
mosquitto_sub -h 192.168.1.252 -t "#" -v
```
You should see TELEMETRY messages arriving.

---

## Step 9 — Auto-start on Boot (optional)

To have the pod start automatically when powered on:

```bash
sudo nano /etc/rc.local
```

Add before `exit 0`:
```bash
cd /home/pi/jpod_OS && sudo python launcher.py 1 "192.168.1.252" &
```

---

## Pod Naming Convention

| Pod | Hostname | Hardware file | podName |
|-----|----------|--------------|---------|
| 1 | jpods-pod1 | hardware/1.json | POD_1 |
| 2 | jpods-pod2 | hardware/2.json | POD_2 |
| 3 | jpods-pod3 | hardware/3.json | POD_3 |
| 4 | jpods-pod4 | hardware/4.json | POD_4 |
| 5 | jpods-pod5 | hardware/5.json | POD_5 |
| 6 | jpods-pod6 | hardware/6.json | POD_6 |

---

## Common Problems

| Symptom | Fix |
|---------|-----|
| Pi doesn't appear on network | Check WiFi credentials in Imager advanced settings; re-flash |
| USB gadget not working | Verify `dtoverlay=dwc2` in config.txt and `modules-load=dwc2,g_ether` in cmdline.txt |
| SSH refused | Create empty `ssh` file in boot partition and reboot |
| I2C devices missing | Enable I2C via `sudo raspi-config`; check ribbon cables |
| paho-mqtt import error | `sudo pip install paho-mqtt==1.6.1` — version matters |
| Permission denied running launcher | Use `sudo python launcher.py ...` |
