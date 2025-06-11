# Quick Start Guide - NanoPi Neo3 Invoice Ninja Builder

## One-Command Setup

For the ultimate one-click experience:

```bash
# Download and run the master builder
sudo ./nanopi-invoiceninja-builder.sh
```

This single command will:
1. ✅ Check your system
2. ✅ Install all dependencies  
3. ✅ Run system tests
4. ✅ Build the complete bootable image
5. ✅ Optionally flash to SD card

## Step-by-Step Usage

If you prefer more control:

### 1. Prepare System
```bash
chmod +x *.sh
sudo ./setup-dependencies.sh
```

### 2. Test System (Optional)
```bash
sudo ./test-build.sh
```

### 3. Build Image
```bash
sudo ./build-nanopi-invoiceninja.sh
```

### 4. Flash to SD Card
```bash
sudo ./flash-image.sh
```

## Configuration

Edit `config.conf` to customize:
- Image size
- Network settings  
- Security options
- Performance tuning

## Files Overview

| File | Purpose |
|------|---------|
| `nanopi-invoiceninja-builder.sh` | **Master one-click script** |
| `build-nanopi-invoiceninja.sh` | Core image builder |
| `setup-dependencies.sh` | Dependency installer |
| `flash-image.sh` | SD card flashing utility |
| `test-build.sh` | System validation tests |
| `config.conf` | Configuration settings |
| `config-parser.sh` | Configuration processor |
| `README.md` | Complete documentation |

## Quick Commands

```bash
# One-click build everything
sudo ./nanopi-invoiceninja-builder.sh

# Interactive mode (asks questions)
sudo ./nanopi-invoiceninja-builder.sh --interactive

# Automated mode (no prompts)
sudo ./nanopi-invoiceninja-builder.sh --automated

# Test system readiness
sudo ./test-build.sh

# Install dependencies only
sudo ./setup-dependencies.sh

# Flash existing image
sudo ./flash-image.sh
```

## After Flashing

1. Insert SD card into NanoPi Neo3
2. Connect ethernet cable
3. Power on device
4. Wait 2-3 minutes
5. Find device IP address
6. Open `http://[device-ip]` in browser
7. Complete Invoice Ninja setup

**Default SSH:** `root` / `invoiceninja123` ⚠️ Change this!

## Troubleshooting

**Build fails?**
```bash
sudo ./test-build.sh --full
```

**Can't find device?**
- Check ethernet connection
- Wait longer (first boot takes time)
- Check router's DHCP client list

**Need help?** See README.md for complete documentation.

---

**🎯 TL;DR: Run `sudo ./nanopi-invoiceninja-builder.sh` and follow the prompts!**
