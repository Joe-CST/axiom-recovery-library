# Troubleshooting

## The Pi does not boot

1. Disconnect power.
2. Flash the image again and allow Raspberry Pi Imager to verify it.
3. Confirm you selected the correct storage device.
4. Use the correct power supply for the Pi model.
5. Try a different genuine SD card or USB enclosure.

Pi 3B/B+ should be tested from microSD first. Older firmware and some USB
adapters may not boot reliably from SSD.

## It stops at `PARTUUID ... does not exist`

The card was incompletely written, corrupted, or removed before verification.
Re-download the image, verify its SHA-256 value, and flash it again.

## `prepper-autoinstall.service` failed

Leave Ethernet connected and reboot. The installer is resumable and reuses
completed files.

For details:

```bash
sudo systemctl status prepper-autoinstall.service
sudo journalctl -u prepper-autoinstall.service --no-pager -n 100
sudo tail -n 100 /boot/firmware/PREPPER-INSTALL.log
```

On older layouts the log may be at `/boot/PREPPER-INSTALL.log`.

## Status code 4 or Ethernet interface error

Version 1.7 uses the active Ethernet interface rather than assuming it is named
`eth0`. Confirm the Ethernet cable is connected and the router assigned an
address:

```bash
ip -brief address
nmcli device status
```

Then reboot with Ethernet connected.

## I cannot see the Axiom hotspot

```bash
sudo systemctl status NetworkManager
sudo nmcli connection show prepper-hotspot
sudo rfkill unblock wifi
sudo nmcli connection up prepper-hotspot ifname wlan0
```

Pi 3 uses 2.4 GHz Wi-Fi. Keep USB 3 enclosures and long unshielded cables away
from the Pi antenna because they can cause interference.

## The phone says “No internet”

That is normal when Ethernet is disconnected. Choose **Stay connected** and
open `http://10.10.10.1` directly.

## Safari works but Chrome does not

1. Type the full address: `http://10.10.10.1`.
2. Make sure Chrome did not change it to `https://`.
3. Disable mobile data temporarily so Chrome cannot abandon the hotspot.
4. Close the tab, reconnect to Axiom, and open a new private/incognito tab.
5. Clear Chrome's site data for `10.10.10.1` if an older map is cached.

The local portal intentionally uses HTTP because it must work completely
offline and cannot renew a public TLS certificate.

## How do I see download progress?

Use the home page, or run:

```bash
sudo journalctl -fu prepper-content-download.service
```

Press `Ctrl+C` when finished watching. To see a summary:

```bash
sudo prepper-healthcheck
```

## A download failed

Keep Ethernet connected and restart the service:

```bash
sudo systemctl reset-failed prepper-content-download.service
sudo systemctl restart prepper-content-download.service
```

Successful and partial downloads are reused. Do not erase them manually unless
the log specifically identifies a corrupt file.

## The map is blank

Check that the map archive is ready:

```bash
sudo prepper-healthcheck
ls -lh /srv/prepper-library/maps/
```

Then open `http://10.10.10.1/maps/` in a private browser tab. If the map is
still downloading, wait for that stage to complete.

## Asking for help

Open a GitHub issue and include:

- Pi model;
- 256 GB, 512 GB, or 1 TB edition;
- SD card or SSD model;
- power-supply rating;
- whether Ethernet has internet;
- a photo of the final screen;
- the last 30–100 lines of the relevant log.

Do not post a replacement password or other private credentials.
