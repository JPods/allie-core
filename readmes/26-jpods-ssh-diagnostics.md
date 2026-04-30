# JPods SSH Diagnostics Cheat Sheet

Quick-reference commands for when you're SSHed into a Pi pod.
Connect: `ssh pi@192.168.1.44`  (password: `1111pass`)

---

## Hardware Check

```bash
# Confirm I2C devices are present
i2cdetect -y 1
# Expect: 0x0A (Romeo BLE motor driver), 0x32 (HuskyLens)

# Read all 21 bytes from motor driver — raw hardware state
python3 -c "
import smbus
bus = smbus.SMBus(1)
data = bus.read_i2c_block_data(0x0A, 0, 21)
print('firmware:    ', data[0])
print('direction:   ', data[1])
print('pwrL:        ', int.from_bytes([data[2],  data[3]],  'big'))
print('pwrR:        ', int.from_bytes([data[4],  data[5]],  'big'))
print('encoderL:    ', int.from_bytes([data[6],  data[7],  data[8],  data[9]],  'big'))
print('encoderR:    ', int.from_bytes([data[10], data[11], data[12], data[13]], 'big'))
print('speedLAvg:   ', int.from_bytes([data[14], data[15]], 'big'))
print('speedRAvg:   ', int.from_bytes([data[16], data[17]], 'big'))
print('speedAvg:    ', int.from_bytes([data[18], data[19]], 'big'))
print('batt (raw):  ', data[20])
print('all bytes:   ', list(data))
"
```

**Battery note:** `batt (raw)` byte 20 is 0 if the battery feeds the Pi only and not the Romeo BLE VIN terminal directly. Romeo BLE measures voltage on its own power input. A 2S LiPo (~8.4V charged) should return a raw byte around 84 if `batteryAdj=0.1`, or the actual voltage as an integer if `batteryAdj=1.0`. Confirm by comparing raw byte to measured voltage with a multimeter.

---

## Pod Config

```bash
# View full pod spec
cat ~/jpod_OS/hardware/4.json

# View just battery and speed settings
cat ~/jpod_OS/hardware/4.json | python3 -c "
import json,sys; d=json.load(sys.stdin)
for k in ['batteryAdj','speedDefault','mmStep','motorDriverVersion','MQTTHost','podName','podIP']:
    print(f'{k}: {d.get(k, \"missing\")}')
"

# View the path sequence
cat ~/jpod_OS/hardware/4.json | python3 -c "
import json,sys; d=json.load(sys.stdin)
print('myPath:', d['myPath'])
"

# Check software version
cat ~/jpod_OS/VERSION
```

---

## Process and Network

```bash
# Is the pod software running?
ps aux | grep python

# What is this Pi's IP?
hostname -I

# Is the broker reachable from the Pi?
ping -c3 192.168.1.189     # replace with current Mac IP

# Test MQTT connectivity from Pi
mosquitto_pub -h 192.168.1.189 -t "TEST" -m "hello from Pi"
```

---

## MQTT — Watch Live Traffic (run on Mac)

```bash
# All topics
mosquitto_sub -h 192.168.1.189 -t "#" -v

# Just telemetry
mosquitto_sub -h 192.168.1.189 -t "SERVER" -v

# Send RUN command to Pod 4
mosquitto_pub -h 192.168.1.189 -t "POD_4" -m "ACTION,RUN,POD_4,1,"

# Send STOP
mosquitto_pub -h 192.168.1.189 -t "POD_4" -m "ACTION,RUN,POD_4,0,"

# Trigger servo toggle
mosquitto_pub -h 192.168.1.189 -t "POD_4" -m "ACTION,SERVO,POD_4,1,"

# Run LED + servo test sequence
mosquitto_pub -h 192.168.1.189 -t "POD_4" -m "ACTION,TEST,POD_4,1,"

# Set speed (RPM)
mosquitto_pub -h 192.168.1.189 -t "POD_4" -m "ACTION,SPEED,POD_4,120,"
```

---

## Telemetry Format

```
TELEMETRY, podName, line, mmDist, speed, servo, podFront, podBack,
           ezoneId, ezState, pathId,
           pwrL, pwrR, encL, encR, spdLAvg, spdRAvg,
           distL, distR, battVolt, mmDistTotal, encTotalL, encTotalR
```

**Servo field:** `0` = engaged (servoState True), `1` = disengaged

**Example parse:**
```
TELEMETRY,POD_4,1,100,0,0,NUL,NUL,1,0,0,0,0,14,14,0,0,0,0,0.0,0,0,0
          name  L mm  spd sv fnt bk ez es pi pL pR eL eR sL sR dL dR bV tot tL tR
```

---

## Start / Restart Pod

```bash
# Kill running pod (if needed)
sudo pkill -f launcher.py

# Start pod (pass broker IP on command line — no JSON edit needed)
cd ~/jpod_OS
sudo python launcher.py 4 "192.168.1.189"

# Start from last saved position
sudo python launcher.py 4 "192.168.1.189" last-location

# Run hardware unit test (neopixel sweep, TOF read, Husky tag scan)
sudo python launcher.py 4 "192.168.1.189" unit-test
```

---

## Common Problems

| Symptom | Check | Fix |
|---------|-------|-----|
| `battVolt` always 0.0 | `data[20]` raw byte | Battery must feed Romeo BLE VIN directly, not just Pi |
| MQTT not connecting | `MQTTHost` in JSON | Use IP not hostname at demos; or pass on command line |
| Pod pings but won't move | `runFlag=False` on boot | Send `ACTION,RUN,POD_4,1,` via MQTT |
| `0x0A` missing on i2cdetect | Romeo BLE power | Check I2C ribbon and 5V to Romeo BLE |
| `0x32` missing | HuskyLens | Check cable; default address 0x32 |
| Encoder counts frozen | Motor driver issue | Power cycle Romeo BLE |

---

## Files and Paths (on Pi)

```
~/jpod_OS/              main pod software
~/jpod_OS/hardware/     pod spec JSONs (1.json, 2.json, 4.json …)
~/jpod_OS/mapSM.json    guideway map
~/jpod_OS/VERSION       software version string
~/jpod_OS/last_location.txt   last saved position (if any)
```
