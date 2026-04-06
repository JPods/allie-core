# JPods New SD Card — Complete Setup Guide

How to build a JPods Pi Zero from a blank SD card to a running pod.

**If you're doing this after time away — ask Allie.** She has the full system context and can walk you through it. Fleet state files are at `/Volumes/Allie/allie/inbox/JPodsSM_RPi/fleet/`.

---

## What You Need

| Item | Notes |
|------|-------|
| SD card | 16GB minimum, Class 10 or faster |
| SD card reader | Built-in Mac slot or USB adapter |
| Raspberry Pi Imager | Free — download from raspberrypi.com/software |
| Mac on JPods WiFi (2.4GHz) | Pi Zero W is 2.4GHz only — do NOT use JPods_5G |
| JPods OS files | `/Volumes/Allie/allie/inbox/JPodsSM_RPi/jpod_OS/` |

---

## Step 1 — Flash the SD Card

Open Raspberry Pi Imager.

- **Device:** Raspberry Pi Zero / Zero W
- **OS:** Raspberry Pi OS Lite (32-bit)
- **Storage:** Select your SD card

**Before clicking Write — click the gear (Advanced Settings):**

| Setting | Value |
|---------|-------|
| Hostname | `raspberrypi` |
| Enable SSH | ✓ — password authentication |
| Username | `pi` |
| Password | `123456` |
| WiFi SSID | `JPods` |
| WiFi Password | `Pinkcoconut637` |
| WiFi Country | US |

Click **Save** then **Write**.

---

## Step 2 — Write the Provision File

After flashing, eject and reinsert. The `bootfs` partition mounts on Mac.

**Write jpods_provision.json:**
```bash
cat > /Volumes/bootfs/jpods_provision.json << 'EOF'
{
  "podNumber": 3,
  "MQTTHost":  "192.168.1.252",
  "podColor":  "YELLOW",
  "upgrade":   true
}
EOF
```

Colors: `RED=0, GREEN=1, BLUE=2, YELLOW=3, MAGENTA=4, CYAN=5, ORANGE=6`

**Copy upgrade files:**
```bash
mkdir -p /Volumes/bootfs/jpods_upgrade
cp /Volumes/Allie/allie/inbox/JPodsSM_RPi/jpod_OS/*.py /Volumes/bootfs/jpods_upgrade/
cp /Volumes/Allie/allie/inbox/JPodsSM_RPi/jpod_OS/*.json /Volumes/bootfs/jpods_upgrade/
```

**Eject and insert into pod.**

---

## Step 3 — First Boot

The Pi Imager WiFi config applies on first boot. When the pod joins the network:

```bash
# Scan for Pi devices (b8:27:eb MAC prefix)
for i in $(seq 1 254); do ping -c1 -W1 192.168.1.$i &>/dev/null & done
wait
arp -a | grep -i "b8:27:eb"
```

---

## Step 4 — Bootstrap jpod_OS

If the pod is a fresh flash, jpod_OS may not exist. Push it directly:

```bash
sshpass -p '123456' ssh pi@<IP> "mkdir -p /home/pi/JPodsSM_RPi/jpod_OS/hardware"
sshpass -p '123456' scp /Volumes/Allie/allie/inbox/JPodsSM_RPi/jpod_OS/*.py pi@<IP>:/home/pi/JPodsSM_RPi/jpod_OS/
sshpass -p '123456' scp /Volumes/Allie/allie/inbox/JPodsSM_RPi/jpod_OS/*.json pi@<IP>:/home/pi/JPodsSM_RPi/jpod_OS/
sshpass -p '123456' scp /Volumes/Allie/allie/inbox/JPodsSM_RPi/jpod_OS/hardware/*.json pi@<IP>:/home/pi/JPodsSM_RPi/jpod_OS/hardware/
```

Then run provision and configure rc.local:

```bash
sshpass -p '123456' ssh pi@<IP> "
  cd /home/pi/JPodsSM_RPi/jpod_OS && sudo python3 -c 'import sys; sys.path.insert(0,\".\"); import provision; print(provision.apply())'
  sudo sed -i '/launcher/d' /etc/rc.local
  sudo sed -i 's|^exit 0|cd /home/pi/JPodsSM_RPi/jpod_OS \&\& sudo python3 launcher.py N \"192.168.1.252\" \&\nexit 0|' /etc/rc.local
"
```

Replace `N` with the pod number.

---

## Step 5 — Identify the Pod

Blink the NeoPixels to confirm which physical pod you're talking to:

```bash
sshpass -p '123456' ssh pi@<IP> "
  sudo python3 -c \"
import board, neopixel
from time import sleep, time
px = neopixel.NeoPixel(board.D12, 8, brightness=0.5)
end = time() + 20
while time() < end:
    px.fill((255,255,255)); px.show(); sleep(0.4)
    px.fill((0,0,0)); px.show(); sleep(0.2)
px.fill((0,0,0)); px.show()
\" &
disown
"
```

---

## Step 6 — Issue Card Binding

Every pod must be bound to its hardware before it can run normally. The binding is an HMAC-SHA256 signature that ties the SD card to the Pi's MAC address. If the card is moved to a different Pi, the pod enters observer mode and cannot move.

**Run from Mac (after pod is on the network):**
```bash
python3 /Volumes/Allie/allie/inbox/JPodsSM_RPi/fleet/issue_binding.py <podNumber>
```

Example for POD_3:
```bash
python3 /Volumes/Allie/allie/inbox/JPodsSM_RPi/fleet/issue_binding.py 3
```

This:
1. Reads the fleet JSON (`fleet/pod_3.json`) — gets the MAC, podColor
2. Computes HMAC-SHA256 over `MAC:podNumber:podColor:timestamp` using the fleet secret
3. Writes `card_binding.json` locally and scps it to the pod
4. Pushes `.fleet_secret` to the pod (needed for binding verification on boot)
5. Records the issuance in `pod_3.json` under `agent_notes.Allie`

**Dry run (compute but don't push):**
```bash
python3 /Volumes/Allie/allie/inbox/JPodsSM_RPi/fleet/issue_binding.py 3 --dry-run
```

**What happens on the pod at boot:**
- `BOUND_OK` — MAC matches, HMAC valid → normal operation
- `BOUND_MISMATCH` — card moved to a different Pi → observer mode (MQTT only, no movement, RED flash 10×)
- `HMAC_INVALID` — binding file tampered → observer mode
- `UNBOUND` — no binding yet → runs normally, reports to Allie for issuance
- `ERROR` — cannot read MAC → observer mode

**Allie is the only authority that can issue a valid binding.** The fleet secret lives at `fleet/.fleet_secret` — never commit it to git.

---

## Hard-Won Lessons (2026-04-05)

These took significant time to discover. Do not skip them.

### WiFi on Previously-Used Cards

Cards that have been in a running pod already have `/etc/wpa_supplicant/wpa_supplicant.conf` on the rootfs. They will join WiFi without any extra steps. Just write provision.json and eject.

Cards that have NEVER connected need WiFi written to their rootfs. Two methods — use the one that works for the card's Pi OS version:

**Method A — wpa_supplicant.conf on /boot (most reliable):**
```bash
cat > /Volumes/bootfs/wpa_supplicant.conf << 'EOF'
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="JPods"
    psk="Pinkcoconut637"
    key_mgmt=WPA-PSK
}
EOF
```
dhcpcd picks this up on boot and copies it to `/etc/wpa_supplicant/`. **This is the method that actually worked on 2026-04-05.**

**Method B — firstrun.sh via systemd.run:**
Write `firstrun.sh` to `/boot` and add `systemd.run=/boot/firstrun.sh` to `cmdline.txt`. Works on Pi OS Bullseye with a sentinel file to prevent re-runs:
```bash
cat > /Volumes/bootfs/firstrun.sh << 'SCRIPT'
#!/bin/bash
set +e
[ -f /var/lib/jpods-firstrun.done ] && exit 0
touch /var/lib/jpods-firstrun.done
rfkill unblock wifi 2>/dev/null || true
cat > /etc/wpa_supplicant/wpa_supplicant.conf << 'WPAEOF'
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US
network={
    ssid="JPods"
    psk="Pinkcoconut637"
    key_mgmt=WPA-PSK
}
WPAEOF
chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
systemctl restart dhcpcd || true
wpa_cli -i wlan0 reconfigure || true
SCRIPT
chmod +x /Volumes/bootfs/firstrun.sh
```
**Do NOT use `systemd.run_success_action=reboot`** — causes infinite boot loop.

### PARTUUID is Unique Per Card

Never hardcode PARTUUID. Always read it from the card:
```bash
PARTUUID=$(grep -o 'PARTUUID=[^ ]*' /Volumes/bootfs/cmdline.txt)
```

### The Bootstrap Problem

`provision.py` runs inside `launcher.py` which runs from `rc.local`. But if jpod_OS doesn't exist on the Pi, none of that runs. Solution: always `scp provision.py` directly first if the pod is fresh.

### Fresh Pi OS Cards Need NeoPixel Libraries

Cards flashed with Raspberry Pi Imager do not have adafruit libraries pre-installed. After first boot, SSH in and run:
```bash
sudo apt-get install -y python3-pip
sudo pip3 install adafruit-circuitpython-neopixel rpi_ws281x adafruit-blinka
```

### Mac Must Be on JPods (2.4GHz), Not JPods_5G

Pi Zero W is 2.4GHz only. If your Mac is on the 5GHz network the Pi will connect fine but you may be on a different subnet or have routing issues. Stick to `JPods` (2.4GHz) at 192.168.1.x.

### Mosquitto 2.0 Defaults to Localhost Only

After any mosquitto restart on the Mac:
```bash
cat /opt/homebrew/etc/mosquitto/mosquitto.conf
# Must contain:
# listener 1883
# allow_anonymous true
```

### SSH Known Hosts Conflicts

Multiple pods share the same hostname (`raspberrypi`). Clear stale entries:
```bash
ssh-keygen -R <IP>
# or
sed -i '' '/<IP>/d' ~/.ssh/known_hosts
```

---

## Pod Fleet Reference

Fleet state files with history and notes: `/Volumes/Allie/allie/inbox/JPodsSM_RPi/fleet/`

| Pod | Color | MAC | Typical IP |
|-----|-------|-----|-----------|
| POD_1 | RED | b8:27:eb:cf:a4:2d | 192.168.1.155 |
| POD_2 | CYAN | b8:27:eb:ee:a4:64 | 192.168.1.25 |
| POD_3 | YELLOW | b8:27:eb:d6:93:62 | 192.168.1.44 |
| POD_4 | MAGENTA | b8:27:eb:e8:99:69 | 192.168.1.245 |
| POD_5 | ORANGE | b8:27:eb:a1:e0:c7 | 192.168.1.121 |
| POD_6 | BLUE | b8:27:eb:bd:fc:ba | 192.168.1.39 |

MQTT broker: **192.168.1.252** (Bill's Mac)

---

## Common Problems

| Symptom | Fix |
|---------|-----|
| Pi not on network after boot | Write wpa_supplicant.conf to /boot partition |
| systemd.run not triggering | Use wpa_supplicant.conf method instead |
| Boot loop | Remove `systemd.run_success_action=reboot` from cmdline.txt |
| provision.py not found | scp it directly before running launcher |
| NeoPixel import error on fresh card | apt install python3-pip + pip3 install adafruit-blinka |
| Multi-colored NeoPixels on boot | launcher.py running — kill it before blinking manually |
| SSH permission denied | Clear known_hosts entry for that IP |
| mosquitto connection refused | Add `listener 1883` + `allow_anonymous true` to mosquitto.conf |
| Pod visible in Presenter but won't move | Check card binding status — BOUND_MISMATCH or HMAC_INVALID means observer mode; re-run `issue_binding.py` |
| `issue_binding.py` says no lastSeenIP | Run `update_pod_ips.sh` first so the fleet JSON has the current IP |
| UNBOUND after binding was issued | Fleet secret not on pod — re-run `issue_binding.py` (it pushes the secret too) |
