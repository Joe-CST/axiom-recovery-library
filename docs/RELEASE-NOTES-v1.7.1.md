# Costa Axiom Recovery Library v1.7.1

This maintenance release keeps the same three zero-command editions as v1.7.0
and adds hotspot and offline-search reliability fixes discovered during a live
Raspberry Pi 5 installation.

## What changed

- The installer now verifies the portal through the actual `wlan0` hotspot
  interface before declaring setup successful.
- The recurring health check can recover a stopped hotspot or web server.
- The Axiom access point disables Wi-Fi power saving and uses explicit
  WPA2/RSN and CCMP settings for better phone compatibility.
- Kiwix content downloads are single-instance, preventing overlapping manual
  and automatic commands from creating duplicate `.1.zim` archives.
- The Kiwix index skips an incomplete or duplicate archive instead of taking
  the entire offline-search service down.
- Archives are added to search only after their verification marker exists.
- Kiwix no longer performs a potentially long full reindex on every service
  restart; verified downloads rebuild the index at the correct time.

## Editions

- **256 GB:** essential and practical library, about 196 GiB installed.
- **512 GB:** adds Wiktionary, Wikiversity, and Survivor Library, about 412 GiB.
- **1 TB:** complete collection with Khan Academy and Project Gutenberg, about
  786 GiB.

All editions support Raspberry Pi 3 Model B/B+, Pi 4 Model B, and Pi 5 Model B.
They include the Costa mobile portal, Axiom hotspot, SSH password access,
wired-internet sharing, practical manuals, illustrated Wikipedia, and offline
North America/Puerto Rico maps.

## Installation and verification

Flash the matching `.img.xz` directly with Raspberry Pi Imager using **Use
custom**. Do not apply Imager OS customisation. Connect wired Ethernet and
stable power for the first boot. Downloads resume automatically after an
interruption.

Matching `.sha256` files are supplied for every compressed image. Read the
[plain-English installation guide](https://github.com/Joe-CST/axiom-recovery-library/blob/main/docs/INSTALL.md)
before flashing.

Default credentials are public and documented in the README and release
credential files. Change both passwords after first setup.
