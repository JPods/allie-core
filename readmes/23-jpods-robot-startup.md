# JPods Robot Startup — Connection and Operations Guide

How to connect to the Pi robots, start the MQTT broker, and get the pods running after time away.

**If you're reading this after time away — ask Allie.** She has this guide and the full system context. Start a Claude Code session on `/Volumes/Allie` and say "help me start the JPods robots." She will walk you through it step by step and update this guide with anything new learned during the session.

---

## Known Configuration (as of 2026-04-04)

| Item | Value |
|------|-------|
| Bill's Mac IP | 192.168.1.252 |
| MQTT broker | Mosquitto on Mac, port 1883 |
| Old broker IP (stale) | 10.206.1.79 — do not use |
| Pod spec files | `jpod_OS/hardware/1.json`, `2.json` |
| Pi expected subnet | 192.168.1.x |
| I2C: Romeo BLE | 0x0A |
| I2C: HuskyLens | 0x32 |

---

## Pod Identity Table

Each pod has a permanent static IP and identity color. On boot, it flashes its color 3× so the team knows which pod is which.

| Pod | IP (home net) | Color | NeoPixel index |
|-----|--------------|-------|----------------|
| POD_1 | 192.168.1.141 | RED | 0 |
| POD_2 | 192.168.1.142 | GREEN | 1 |
| POD_3 | 192.168.1.143 | BLUE | 2 |
| POD_4 | 192.168.1.144 | YELLOW | 3 |
| POD_5 | 192.168.1.145 | MAGENTA | 4 |
| POD_6 | 192.168.1.146 | CYAN | 5 |

**Subnet adapts to venue.** The last octet (.141–.146) is always the pod number + 140. At a demo on a different network (say 10.0.1.x), Pod 1 gets 10.0.1.141, etc.

**Router DHCP range** — set your router's DHCP end to .140 so it never hands out .141–.146 dynamically. On the ASUS RT-AC86U: LAN → DHCP Server → IP Pool End → 192.168.1.140.

**To assign a pod its static IP and color** (Pi connected via USB or WiFi):
```bash
cd /Users/williamjames/Documents/08_JPods/03_Technology/JPodsSM_RPi/jpod_OS
./configure_pod.sh 1    # POD_1, RED, 192.168.x.141
./configure_pod.sh 2    # POD_2, GREEN, 192.168.x.142
```
Script auto-detects the current subnet from the Mac — no editing needed at a new venue. Reboot the Pi after running it.

---

## Step 1 — Find the Pi's IP Address

### Terminal commands (try these first)

```bash
# Devices your Mac has recently seen (fast — always try this first)
arp -a | grep "192.168.1"

# Actively scan the whole subnet (more complete, needs nmap)
nmap -sn 192.168.1.0/24

# Try Pi mDNS hostname
ping -c1 raspberrypi.local

# Check all network interfaces — Pi Zero USB gadget appears as a new en* interface
ifconfig | grep -E "^en|inet "
```

`arp -a` is the fastest diagnostic. Run it any time you need to see what's on the network — routers, Pis, phones, everything your Mac has talked to recently. If a device doesn't appear, it's either off, not on the same subnet, or hasn't been seen since the ARP cache was last cleared.

### Router login (most reliable)

Sign into `http://192.168.1.1` — Bill's home router is an **ASUS RT-AC86U**.
Look under: **Network Map** or **LAN → DHCP Server → Currently Leased**
The Pi will appear as `raspberrypi` in the hostname column.

### If the Pi doesn't appear

It's either not powered on, or WiFi credentials are stale (common after 2+ years).
Connect via USB cable (Step 1B below) to update WiFi config before anything else.

---

## Step 1 — Find the Pi

### Option A: USB cable (no network needed)

**Pi Zero has two micro-USB ports — use the correct one:**
```
[ PWR IN ]  [ USB ]
               ↑
          Use this one — the center/data port (OTG)
          PWR IN is power only, no data
```

Plug a **data** cable (not charge-only) from the Pi Zero's **USB** port to the Mac.

```bash
ls /dev/cu.*
```

Look for `cu.usbserial-XXXX` or `cu.usbmodem-XXXX`. Then connect:

```bash
screen /dev/cu.usbserial-XXXX 115200
```

**If nothing appears:**
- Try a different cable — most USB-C cables are charge-only
- Pi needs its own power supply; Mac USB may not be enough
- CH340/CP2102 chips may need a driver on newer macOS

### Option B: Pull the SD card

If the Pi won't connect over USB or WiFi, pull the SD card and insert it into your Mac.
Two partitions will mount — `bootfs` (FAT32) is readable by Mac. `rootfs` (ext4) is not. `bootfs` is enough to fix most problems.

**Check what needs fixing:**
```bash
# USB gadget mode configured?
grep "dwc2" /Volumes/bootfs/config.txt /Volumes/bootfs/cmdline.txt

# SSH enabled?
ls /Volumes/bootfs/ssh
```

**Fix USB gadget mode** (if not configured):
```bash
echo "dtoverlay=dwc2" >> /Volumes/bootfs/config.txt
sed -i '' 's/$/ modules-load=dwc2,g_ether/' /Volumes/bootfs/cmdline.txt
```

**Enable SSH** (if absent):
```bash
touch /Volumes/bootfs/ssh
```

**Fix WiFi credentials** — create this file on the boot partition:
```bash
nano /Volumes/bootfs/wpa_supplicant.conf
```
```
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="YourNetworkName"
    psk="YourPassword"
}
```
Pi copies it to the correct location automatically on next boot.

**Verify all three before ejecting:**
```bash
tail -3 /Volumes/bootfs/config.txt        # should show dtoverlay=dwc2
cat /Volumes/bootfs/cmdline.txt           # should end with modules-load=dwc2,g_ether
ls /Volumes/bootfs/ssh                    # should exist
```

Eject both partitions, reinsert SD card into Pi, plug USB data cable into Pi's **center USB port**, wait 60 seconds.

**macOS will show a prompt asking to accept the new network device — click Accept.**
Without this the Pi won't appear. It only asks once per device.

Then check:
```bash
ifconfig | grep "169.254"   # Pi gadget appears as link-local address
ping -c2 raspberrypi.local  # confirm it responds
```

---

### Option C: SSH over WiFi

If the Pi has already connected to WiFi:

```bash
# Try hostname first
ssh pi@raspberrypi.local   # password: 1111pass

# Or scan for it
arp -a | grep -v incomplete
ping -c1 raspberrypi.local
```

Once you have the terminal, get the IP:
```bash
hostname -I
```

---

## Step 2 — Check I2C bus

Before running anything, confirm hardware is wired up:

```bash
i2cdetect -y 1
```

**Expected:**
- `0x0A` — Romeo BLE motor controller
- `0x32` — HuskyLens camera

If either is missing — check ribbon cables and power before going further.

---

## Step 3 — Start MQTT broker on Mac

First check if it's already running as a service:
```bash
brew services list
```

If mosquitto shows `started` — it's already running, nothing to do.

If stopped:
```bash
brew services start mosquitto
```

If not installed:
```bash
brew install mosquitto
brew services start mosquitto
```

**If Mosquitto refuses remote connections** (macOS mosquitto 2.0+ defaults to localhost only):
```bash
echo "listener 1883\nallow_anonymous true" | sudo tee /usr/local/etc/mosquitto/mosquitto.conf
brew services restart mosquitto
```

**Monitor all MQTT traffic:**
```bash
mosquitto_sub -h 192.168.1.252 -t "#" -v
```
Leave this running — pod START and TELEMETRY messages will appear here when the Pi connects.

---

## Step 4 — Start a pod

From `jpod_OS/` on the Pi. Pass the broker IP on the command line — no need to edit `hardware/1.json`:

```bash
# Normal start
sudo python launcher.py 1 "192.168.1.252"

# Resume from last saved position
sudo python launcher.py 1 "192.168.1.252" last-location

# Run hardware unit test
sudo python launcher.py 1 "192.168.1.252" unit-test
```

**Argument pattern:**
```
sudo python launcher.py <pod_number> "<broker_ip>" [option]
```
Pod number matches the file in `hardware/` — `1` = `hardware/1.json` = POD_1.

---

## Step 5 — Confirm connection

On the Pi terminal you should see:
```
MQTT Connected
>>BOOT: POD_1 | DIST: 100 | LINE: 1
```

On the Mac with `mosquitto -v` running you should see the pod subscribe and publish TELEMETRY messages.

---

## Step 6 — Start podPresenter (optional)

podPresenter is the Processing sketch that shows the live map and receives MQTT telemetry. Run from the Mac in the Processing IDE:

```
/Users/williamjames/Documents/08_JPods/03_Technology/JPodsSM_RPi/podPresenter/podPresenter.pde
```

---

## Demo Setup — New Venue, Different Network

**Finding your Mac's broker IP at a demo:**
```bash
ifconfig | grep "192.168"
```

**Broker IP never needs to be in the JSON** — always pass it on the command line:
```bash
sudo python launcher.py 1 "192.168.x.x"
```

**WiFi credentials changed** — use the demo setup script from your Mac.
Pi must be connected via USB cable (works before WiFi):
```bash
cd /Users/williamjames/Documents/08_JPods/03_Technology/JPodsSM_RPi/jpod_OS
./demo_setup.sh "VenueWiFiName" "wifipassword" "192.168.x.x"
```

This SSHes into `raspberrypi.local`, adds the new network to `wpa_supplicant.conf` (keeping all previous networks), and reloads WiFi without a reboot.

**Store networks as you encounter them** — edit `/etc/wpa_supplicant/wpa_supplicant.conf` directly on the Pi to keep a permanent list of known venues. Pi connects to whichever is in range.

---

## Common Problems

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| No `/dev/cu.usb*` | Charge-only cable or driver missing | Try different cable; check CH340 driver |
| `0x0A` missing on i2cdetect | Romeo BLE not powered or ribbon loose | Check I2C ribbon cable and 5V supply |
| `0x32` missing on i2cdetect | HuskyLens not powered or address wrong | Check HuskyLens cable; default address is 0x32 |
| MQTT not connecting | Mosquitto not running or localhost-only | Start mosquitto with config above |
| Pod connects but doesn't move | `runFlag = False` on boot — normal | Send `ACTION,RUN,POD_1,1,` via MQTT or use podPresenter |
| Wrong IP in hardware JSON | Stale `MQTTHost` | Pass IP on command line — no need to edit JSON |
| WiFi not connecting | Pi not on 192.168.1.x subnet | Check Pi WiFi config in `/etc/wpa_supplicant/wpa_supplicant.conf` |

---

## Pi WiFi Configuration

If the Pi isn't connecting to WiFi after two years, the network credentials may be stale.

```bash
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
```

```
network={
    ssid="YourNetworkName"
    psk="YourPassword"
}
```

Then:
```bash
sudo wpa_cli -i wlan0 reconfigure
hostname -I
```

---

## 4WD Floor Robots (JPods_4WD)

Same startup procedure. Pod spec files in:
```
/Users/williamjames/Documents/08_JPods/03_Technology/JPods_4WD/jpod_OS/hardware/1.json
```

Map file: `map4WD.json` (waypoint graph, not line/segment format).

```bash
sudo python launcher.py 1 "192.168.1.252"
```

---

## Design Notes

- **Pi is sovereign** — it thinks, talks, and decides. Romeo BLE executes motor commands only.
- **MQTT over WiFi** — Romeo BLE's Bluetooth radio is unused. All coordination is MQTT.
- **Blind termites** — encoders are primary navigation. HuskyLens and TOF reinforce.
- If time has passed and IP addresses have changed, the broker IP is always the one variable — pass it on the command line rather than editing JSON files.
