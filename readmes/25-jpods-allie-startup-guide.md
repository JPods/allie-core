# JPods — Allie's Robot Startup Routine

When Bill says "help me start the robots" or "let's set up for a demo" — follow this sequence.
Run each diagnostic step yourself, report what you find, and tell Bill exactly what to do next.

**Pi password: `123456`** (all pods)
**Pi username: `pi`**
**Fleet files:** `/Volumes/Allie/allie/inbox/JPodsSM_RPi/fleet/`

---

## Phase 1 — Check the Network

Run these and report what you find:

```bash
# What is the Mac's IP? This is the MQTT broker address.
ifconfig | grep "192.168"

# What devices are on the network?
arp -a | grep "192.168"

# Is mosquitto running?
brew services list | grep mosquitto
```

**Tell Bill:**
- The Mac's current IP (broker address for launcher.py)
- Whether the Pi is already on the network (look for `raspberrypi` or `jpods-pod` in arp output)
- Whether mosquitto is running (start it if not: `brew services start mosquitto`)

**If Pi already appears in arp -a:** skip to Phase 3.

**Run the IP updater** — always do this before launching podPresenter:
```bash
bash /Volumes/Allie/allie/inbox/JPodsSM_RPi/fleet/update_pod_ips.sh
```
This scans the network, matches Pi MACs to known pods, updates `lastSeenIP` in each fleet JSON, and rewrites `podIP.json` in podPresenter with the current IPs. Works on any network.

---

## Phase 2 — SD Card Setup

**Say to Bill:** "Please insert the Pi's SD card into your Mac."

Wait, then check:

```bash
ls /Volumes/bootfs/ 2>/dev/null && echo "SD card mounted" || echo "SD card not found"
```

If mounted, run the full diagnostic:

```bash
# USB gadget configured?
grep -c "dwc2" /Volumes/bootfs/config.txt 2>/dev/null

# Gadget module in cmdline?
grep -c "g_ether" /Volumes/bootfs/cmdline.txt 2>/dev/null

# SSH enabled?
ls /Volumes/bootfs/ssh 2>/dev/null && echo "SSH enabled" || echo "SSH missing"
```

**Fix anything missing:**

```bash
# Add USB gadget if not present
grep -q "dwc2" /Volumes/bootfs/config.txt || echo "dtoverlay=dwc2" >> /Volumes/bootfs/config.txt

# Add gadget module to cmdline if not present
grep -q "g_ether" /Volumes/bootfs/cmdline.txt || sed -i '' 's/$/ modules-load=dwc2,g_ether/' /Volumes/bootfs/cmdline.txt

# Enable SSH if missing
[ -f /Volumes/bootfs/ssh ] || touch /Volumes/bootfs/ssh
```

**Check WiFi — does the current network match what's on the card?**

The bootfs can't show the WiFi config (that's on rootfs). Ask Bill:
"Is this SD card from a Pi that has connected to this network before?"

- **Yes** → eject and try connecting
- **No / unsure** → need to update WiFi. Ask for the network name and password, then add via SSH after connecting (Phase 2B) or add wpa_supplicant.conf to bootfs now

**Add WiFi to bootfs (if needed):**

```bash
# Replace with current network credentials
cat > /Volumes/bootfs/wpa_supplicant.conf << 'EOF'
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="NETWORK_NAME"
    psk="NETWORK_PASSWORD"
    priority=10
}
EOF
```

**Verify then eject:**
```bash
tail -3 /Volumes/bootfs/config.txt
cat /Volumes/bootfs/cmdline.txt
ls /Volumes/bootfs/ssh
diskutil eject /Volumes/bootfs
```

**Say to Bill:** "Eject done. Insert SD card into the Pi Zero's center USB port, connect the USB cable to the Mac's center port, and wait 60 seconds. Accept the network device prompt if macOS asks."

---

## Phase 3 — Connect to the Pi

After 60 seconds, run:

```bash
ping -c2 raspberrypi.local 2>&1
ifconfig | grep "169.254"
arp -a | grep "192.168"
```

**If Pi responds at raspberrypi.local or 169.254.x.x:**
```bash
ssh pi@raspberrypi.local
# password: 1111pass
```

**If Pi appears on 192.168.x.x:**
```bash
ssh pi@<ip-address>
# password: 1111pass
```

---

## Phase 4 — On the Pi

Once SSH'd in, verify hardware:

```bash
hostname -I
i2cdetect -y 1
```

Report the IP and whether `0x0A` (Romeo BLE) and `0x32` (HuskyLens) are present.

**Start the pod** (replace IP with Mac's current IP from Phase 1):
```bash
cd /home/pi/jpod_OS
sudo python launcher.py 1 "192.168.1.252"
```

**Confirm on Mac** — should see TELEMETRY messages:
```bash
mosquitto_sub -h 192.168.1.252 -t "#" -v
```

---

## Phase 5 — New Venue WiFi (demo only)

If at a new venue and Pi isn't connecting to WiFi, while USB cable is still connected:

```bash
./demo_setup.sh "VenueWiFiName" "wifipassword" "192.168.x.x"
```

Script is at:
`/Users/williamjames/Documents/08_JPods/03_Technology/JPodsSM_RPi/jpod_OS/demo_setup.sh`

---

## Quick Reference

| What | Command |
|------|---------|
| Mac's broker IP | `ifconfig \| grep "192.168"` |
| Devices on network | `arp -a \| grep "192.168"` |
| Pi via USB gadget | `ping -c1 raspberrypi.local` |
| Mosquitto status | `brew services list \| grep mosquitto` |
| Start mosquitto | `brew services start mosquitto` |
| Watch MQTT traffic | `mosquitto_sub -h 192.168.1.252 -t "#" -v` |
| SSH to Pi | `ssh pi@raspberrypi.local` (password: 1111pass) |
| Start pod | `sudo python launcher.py 1 "<broker_ip>"` |
| Pi hardware check | `i2cdetect -y 1` |
