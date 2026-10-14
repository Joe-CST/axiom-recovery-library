# Complete installation guide

This guide assumes you are starting with a blank SD card or SSD. You do not
need Linux experience and you do not need to type commands during installation.

## Before you begin

You need:

- Raspberry Pi 3 Model B/B+, Pi 4 Model B, or Pi 5 Model B;
- a card or SSD large enough for the chosen edition;
- wired Ethernet with internet access for the first installation;
- reliable power and cooling;
- a Windows, macOS, or Linux computer with Raspberry Pi Imager.

Pi 3 Model A+ is not supported by the automatic workflow because it has no
onboard Ethernet. Pi 3 works, but downloads and searches are much slower than
on Pi 4 or Pi 5.

## Step 1: choose an edition

| Your storage | Use this edition | Do not use |
|---|---|---|
| 256 GB | 256 GB | 512 GB or 1 TB image |
| 512 GB | 256 GB or 512 GB | 1 TB image |
| 1 TB or larger | Any edition | — |

Using a smaller edition on a larger drive is safe. The unused space remains
available for personal documents.

Download from the [v1.7.1 release page](https://github.com/Joe-CST/axiom-recovery-library/releases/tag/v1.7.1).

## Step 2: verify the download

Verification is optional but strongly recommended. Download the matching
`.sha256` file from the release.

### Windows PowerShell

```powershell
Get-FileHash .\Costa-Axiom-Pi3-Pi4-Pi5-256GB-v1.7.1.img.xz -Algorithm SHA256
```

Compare the printed hash with the value inside the matching `.sha256` file.

### macOS or Linux

```bash
shasum -a 256 Costa-Axiom-Pi3-Pi4-Pi5-256GB-v1.7.1.img.xz
```

If the values differ, delete the file and download it again.

## Step 3: flash the card or SSD

1. Install [Raspberry Pi Imager](https://www.raspberrypi.com/software/).
2. Insert the SD card or connect the SSD.
3. Open Imager and select the correct Pi model.
4. Select **Choose OS → Use custom**.
5. Select the `.img.xz` file. Imager can read it directly.
6. Select the destination card or SSD.
7. Choose **No** when asked to apply OS customisation. The image already has
   its user, SSH, and installer configuration.
8. Confirm the erase.
9. Wait for both writing and verification to finish.
10. Eject the device safely.

> **Warning:** Flashing permanently erases the selected storage device. Check
> its name and capacity before clicking Yes.

## Step 4: first boot

1. Insert the card or connect the SSD to the Pi.
2. Connect Ethernet from the Pi to the internet router.
3. Connect a monitor if you want to watch progress. A monitor is not required.
4. Connect power.
5. Leave Ethernet and power connected.

The first boot installs the web server, hotspot, offline maps, manuals, and
knowledge archives. Partial downloads resume automatically after a reboot.

Approximate final data sizes are:

- 256 GB edition: about 196 GiB;
- 512 GB edition: about 412 GiB;
- 1 TB edition: about 786 GiB.

Actual archive sizes can change. The installer protects free space and stops
before filling the device.

## Step 5: watch progress

From a phone:

1. Join the `Axiom` Wi-Fi network.
2. Enter password `AllWay$Preeped`.
3. Open `http://10.10.10.1`.

From the Pi keyboard or SSH:

```bash
sudo systemctl status prepper-content-download.service
sudo journalctl -fu prepper-content-download.service
sudo prepper-healthcheck
```

Press `Ctrl+C` to leave the live journal view. This does not stop the download.

The boot partition also contains `PREPPER-INSTALL.log`. After the entire setup
finishes, it contains `PREPPER_READY.txt`.

## Step 6: test without internet

When the portal says the library is ready:

1. Shut down cleanly with `sudo shutdown -h now`.
2. Disconnect Ethernet.
3. Power the Pi back on.
4. Put the phone in airplane mode, then turn Wi-Fi back on.
5. Join `Axiom` and open `http://10.10.10.1`.
6. Open several articles, one PDF, and the map.
7. Search the library and test both Safari and Chrome if available.

The phone may report that Axiom has no internet. Choose **Stay connected**.
That message is expected during offline use.

## Step 7: change the public defaults

Change the Linux password:

```bash
passwd
```

Change the hotspot password to a new 12-character-or-longer password:

```bash
sudo nmcli connection modify prepper-hotspot wifi-sec.psk 'YOUR-NEW-PASSWORD'
sudo nmcli connection down prepper-hotspot
sudo nmcli connection up prepper-hotspot ifname wlan0
```

The phone disconnects when the hotspot restarts. Reconnect with the new
password. Keep the new credentials in a safe offline location.

## Installing several devices

Complete one full installation and offline test first. Then flash and install
the remaining cards. This catches card, power, storage-adapter, and router
problems before you spend time on multiple devices.

For failures, continue with [Troubleshooting](TROUBLESHOOTING.md).
