# Mac Application Inventory
**Audited:** 2026-08-13
**Machine:** MacBook Pro M1 Max, 1TB SSD

## Legend
- **KEEP** — actively used
- **KEEP-4D** — needed for WC2 data access (remove when migration complete)
- **REVIEW** — may not be needed; Bill to decide
- **JUNK** — safe to remove (old, redundant, or carried from previous Macs)

---

## Active Development & Design Tools

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| Visual Studio Code | 914M | KEEP | Primary code editor |
| Xcode | 4.0G | KEEP | iOS/macOS build tools, needed for command line tools |
| PyCharm CE | 2.1G | REVIEW | Python IDE — do you use it or just VS Code? |
| GitHub Desktop | 422M | REVIEW | Git GUI — you use command line git via Claude Code |
| Sourcetree | 146M | REVIEW | Another Git GUI — likely redundant |
| Processing | 718M | REVIEW | Creative coding — used for JPods visualizations? |
| CMake | 215M | REVIEW | C/C++ build system |
| Eclipse Installer | 129M | JUNK | Java IDE installer — never completed |
| Atom | 653M | JUNK | Dead code editor (GitHub sunset it in 2022) |

## 3D / CAD / Manufacturing

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| SketchUp 2026 (in plugin list) | — | KEEP | JPods 3D modeling — primary tool |
| SketchUp 2024 | 673M | REVIEW | Previous version — still needed? |
| SketchUp 2023 | 1.0G | REVIEW | Older version — still needed? |
| SketchUp 2021 | 767M | REVIEW | Even older — still needed? |
| Blender | 828M | REVIEW | 3D modeling/rendering — used? |
| FreeCAD | 2.5G | REVIEW | Open-source CAD — used alongside Fusion 360? |
| Meshmixer | 153M | REVIEW | 3D mesh editing (Autodesk, discontinued) |
| Autodesk Print Studio | 406M | JUNK | Discontinued Autodesk 3D print tool |
| KeyShot Network Configurator | 576M | REVIEW | Rendering network config |
| KeyShot Network Monitor | 471M | REVIEW | Rendering network monitor |
| KeyShot Network Worker Tray | 412M | REVIEW | Rendering network worker |
| SlicerForFusion360 | 132M | REVIEW | 3D print slicing for Fusion |

## CNC / Laser / Electronics

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| Inkscape | 624M | KEEP | SVG editor for laser cutting |
| LightBurn | 60M | KEEP | Laser cutter control software |
| gSender | 449M | KEEP | CNC controller (Genmitsu/Sienci) |
| Genmitsu | 75M | KEEP | CNC machine companion app |
| CraftWare Pro | 103M | REVIEW | 3D printer slicer (Craftunique) |
| LycheeSlicer | 409M | REVIEW | Resin 3D printer slicer |
| Arduino IDE2 | 472M | KEEP | Microcontroller programming (JPods hardware) |
| EasyEDA | 221M | REVIEW | PCB design — used? |
| OpenMV IDE | 402M | REVIEW | Machine vision camera IDE |
| pixymon2 | 54M | REVIEW | Pixy camera monitor |
| nScope | 13M | REVIEW | USB oscilloscope |
| PhaseRunnerSuite | 27M | REVIEW | Motor controller config (JPods motors?) |
| NodeMCU PyFlasher | 17M | REVIEW | ESP8266/ESP32 firmware flasher |
| CP210xVCPDriver | 1M | KEEP | USB-to-serial driver (Pi, Arduino) |

## Video & Media Production

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| Final Cut Pro Creator Studio | 6.6G | KEEP | Video editing (current version) |
| Final Cut Pro (old) | 6.5G | JUNK | Duplicate — needs `sudo rm` |
| Camtasia | 773M | KEEP | Screen recording + tutorials |
| Audiate | 585M | KEEP | Audio transcription (TechSmith, pairs with Camtasia) |
| Snagit | 430M | KEEP | Screenshot tool (TechSmith) |
| CapCut | 1.9G | REVIEW | TikTok video editor — used? |
| OBS | 398M | REVIEW | Streaming/recording — used? |
| Movavi Video Converter | 313M | REVIEW | Video format converter |
| HandBrake | 24M | REVIEW | Video transcoder (free) |
| FxFactory | 14M | REVIEW | Final Cut Pro plugin manager |
| MPEG Streamclip | 1.4M | JUNK | Ancient (2009) video tool |
| Movie Scores | 63M | JUNK | Stock music browser |
| 5KPlayer | 159M | JUNK | Media player — use VLC or built-in |

## Graphics & Design

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| Affinity Designer 2 Beta | 2.7G | KEEP | Vector design (Bill's SVG tool) |
| Affinity Photo 2 Beta | 2.7G | KEEP | Photo editing |
| Affinity Publisher 2 Beta | 2.7G | KEEP | Page layout / publishing |
| Pixelmator Pro Creator Studio | 677M | REVIEW | Image editor — redundant with Affinity? |
| OmniGraffle | 127M | KEEP | Diagramming |

## Productivity & Office

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| Microsoft Word | 2.7G | KEEP | Word processing |
| Microsoft Excel | 2.5G | KEEP | Spreadsheets |
| Microsoft PowerPoint | 2.2G | KEEP | Presentations |
| Microsoft Outlook | 2.7G | KEEP | Email (if used alongside Apple Mail) |
| Microsoft OneNote | 1.3G | REVIEW | Note-taking — do you use it? |
| Microsoft Teams | 1.1G | KEEP | Video calls / chat |
| Keynote Creator Studio | 646M | KEEP | Apple presentations |
| Pages | 454M | KEEP | Apple word processor |
| Numbers | 417M | KEEP | Apple spreadsheets |
| Evernote | 827M | REVIEW | Note-taking — still used? |
| Notion | (2.3G data) | REVIEW | Note-taking/wiki — still used? |
| OmniPlan | 61M | REVIEW | Project management — used? |
| ProjectLibre | 152M | JUNK | Open-source MS Project clone |
| VisualMind | 38M | REVIEW | Mind mapping |

## Communication

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| WhatsApp | 613M | KEEP | Messaging |
| WeChat | 1.3G | KEEP | China messaging (JPods Shenzhen) |
| 企业微信 (WeCom) | 2.6G | REVIEW | Enterprise WeChat — still needed? |
| Slack | 529M | KEEP | Team chat |
| Telegram | 261M | REVIEW | Messaging — used? |
| Zoom | 313M | REVIEW | Video calls — still used alongside Teams? |
| Microsoft Edge | 1.1G | REVIEW | Browser — redundant with Chrome? |
| Skype | 553M | JUNK | Microsoft deprecated it |
| Skype for Business | 123M | JUNK | Replaced by Teams |
| RingCentral | 756M | JUNK | Phone system — last modified Nov 2022 |
| Mikogo-host | 35M | JUNK | Screen sharing — obsolete |
| TeamViewer | 264M | REVIEW | Remote desktop — still used? |

## Browsers

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| Google Chrome | 1.4G | KEEP | Primary browser |
| Chrome Debug | 96K | KEEP | JPods development debugging |
| Safari | 0B | KEEP | System browser |
| Firefox | 488M | REVIEW | Secondary browser — used? |
| Brave Browser | 287M | JUNK | Last used April 2023 |
| DuckDuckGo | 350M | REVIEW | Privacy browser |
| Microsoft Edge | 1.1G | REVIEW | Yet another browser |

## Cloud & Sync

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| Google Drive | 343M | KEEP | Cloud storage |
| Dropbox | 652M | REVIEW | Cloud storage — still needed alongside Google Drive + iCloud? |
| OneDrive | 1.4G | REVIEW | Microsoft cloud — needed? |
| Backup and Sync | 98M | JUNK | Old Google Drive app (replaced by Google Drive) |
| Contacts Sync for Google Gmail | 15M | REVIEW | Syncs contacts |

## Database & Data Tools

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| 4D v19 R7 | 2.8G | KEEP-4D | WC2 data access |
| 4D 20.3 | 2.6G | KEEP-4D | WC2 data access |
| MongoDB Compass | 399M | REVIEW | MongoDB GUI — still used? |
| Postman | 310M | REVIEW | API testing — still used? |
| Postman Agent | 253M | REVIEW | Postman companion |

## Books & Publishing

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| Amazon Kindle | 275M | KEEP | E-book reader |
| Kindle Previewer 3 | 966M | REVIEW | E-book preview/testing for publishing |
| calibre | 836M | REVIEW | E-book management/conversion |
| Sigil | 407M | REVIEW | EPUB editor |
| FlowPaper Desktop Publisher | 348M | REVIEW | Digital flipbook maker |

## AI & LLM

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| Ollama | 319M | KEEP | Local LLM runtime (Allie) |
| Claude | 566M | KEEP | Claude desktop app |
| Chatbox | 219M | JUNK | Generic LLM chat UI — redundant |
| Perplexity | 441M | REVIEW | AI search — used? |

## Tax & Finance

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| TurboTax 2025 | 931M | KEEP | Current tax year |
| TurboTax 2024 | 910M | REVIEW | Keep 3 years for IRS? |
| TurboTax 2023 | 790M | REVIEW | Keep 3 years for IRS? |

## Security & VPN

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| Okta Verify | 97M | KEEP | 2FA authentication |
| Intego NetBarrier | 42M | REVIEW | Firewall — used? |
| OpenVPN Connect | 131M | REVIEW | VPN client |
| Kaspersky Anti-Virus | 23M | JUNK | Old AV from 2022 |
| RoboForm | 99M | JUNK | Password manager — likely replaced |
| LastPass | 13M | JUNK | Password manager — likely replaced |

## Utility

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| Pastebot | 13M | KEEP | Clipboard manager |
| Flycut | 1.3M | REVIEW | Another clipboard manager — redundant with Pastebot? |
| CopyClip | 5.4M | REVIEW | Yet another clipboard manager |
| Magnet | 3.4M | KEEP | Window manager |
| Amphetamine | 7.1M | KEEP | Prevent sleep |
| The Unarchiver | 25M | KEEP | File decompression |
| BBEdit | 64M | REVIEW | Text editor — used alongside VS Code? |
| Duplicate File Finder | 58M | KEEP | Useful for this cleanup project |
| balenaEtcher | 390M | KEEP | SD card flasher (Pi for JPods) |
| Thonny | 172M | REVIEW | Python IDE for beginners (Pi) |
| MQTTX | 232M | REVIEW | MQTT client (JPods IoT) |
| MQTT Explorer | 62M | REVIEW | Another MQTT client |
| Warp | 452M | KEEP | Terminal app |
| StuffIt Archive Manager | 91M | JUNK | Ancient archive tool |
| WiFi Strength Indicator | 596K | REVIEW | WiFi signal tool |

## Remote Access

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| Microsoft Remote Desktop | 101M | KEEP | RDP client |
| VNC Viewer (RealVNC) | 4.6M | REVIEW | VNC — redundant? |
| Chrome Remote Desktop Uninstaller | 2.5M | KEEP | Utility |

## Camera & IoT

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| IP Cam Viewer Lite | 40M | REVIEW | Security camera viewer |
| Danale IoT | 104M | REVIEW | IoT camera app |
| Quik (GoPro) | 412M | REVIEW | GoPro video editor — used? |

## Streaming

| App | Size | Status | What it does |
|-----|------|--------|-------------|
| Friendly Streaming | 151M | REVIEW | Multi-service streaming app |
| Vimeo | 75M | REVIEW | Video hosting |

## Ancient / Carried from Previous Macs (Sep 2022 = migration date)

| App | Size | What it was |
|-----|------|-------------|
| HP Photosmart Studio + suite | ~7M | Printer software from 2009 |
| WalkMe | 237M | Enterprise onboarding tool |
| App for WhatsApp | 6.3M | Third-party WhatsApp wrapper |
| Adobe AIR stuff | ~63M | Dead runtime |
| Grammarly | 174M | Writing assistant |
| SmallCubed MailSuite | 16M | Mail plugin |
| MiniPlay | 2.2M | Menu bar music player |
| EaseUS MobiMover | 214M | Phone data transfer tool |
| Postbox | 115M | Old email client |
| Thunderbird | 367M | Mozilla email client |
| AirPort Setup Assistant | 836K | Apple discontinued AirPort |
| OnyX | 6.3M | System maintenance |
| XQuartz | 5.4M | X11 for macOS |

---

## Quick-Win Removals (JUNK items)

**Total recoverable: ~5.8GB** (excluding Final Cut Pro old which needs sudo)

| App | Size |
|-----|------|
| Atom | 653M |
| Skype + Skype for Business | 676M |
| RingCentral | 756M |
| Brave Browser | 287M |
| Backup and Sync (old Google Drive) | 98M |
| Chatbox | 219M |
| Kaspersky | 23M |
| RoboForm | 99M |
| LastPass | 13M |
| StuffIt | 91M |
| MPEG Streamclip | 1.4M |
| Movie Scores | 63M |
| 5KPlayer | 159M |
| ProjectLibre | 152M |
| Mikogo-host | 35M |
| Eclipse Installer | 129M |
| Autodesk Print Studio | 406M |
| HP suite (all) | ~7M |
| WalkMe | 237M |
| App for WhatsApp | 6.3M |
| Adobe AIR | 63M |
| Grammarly | 174M |
| EaseUS MobiMover | 214M |
| Postbox | 115M |
| Thunderbird | 367M |
| SmallCubed MailSuite | 16M |
| MiniPlay | 2.2M |

Plus **Final Cut Pro old: 6.5GB** (needs `sudo rm -rf "/Applications/Final Cut Pro.app"`)

---

## Notes
- Many "Sep 2022" dates = carried over during Mac migration, not actual last-use date
- Three clipboard managers installed (Pastebot, Flycut, CopyClip) — pick one
- Two MQTT clients (MQTTX, MQTT Explorer) — pick one for JPods IoT
- Multiple SketchUp versions — check if old ones are needed for specific model compatibility
- 企业微信 (WeCom) at 2.6GB is very large for a messaging app
