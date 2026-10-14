# Changelog

## 1.7.1 — 2026-10-14

- Added automatic hotspot and portal recovery checks that test the actual
  `wlan0` access point path instead of only checking whether services exist.
- Disabled Wi-Fi power saving and pinned the hotspot to WPA2/RSN with CCMP for
  more reliable phone connections.
- Prevented overlapping Kiwix downloads from creating duplicate `.1.zim`
  archives.
- Made the Kiwix index resilient to an incomplete or duplicate archive so one
  bad file cannot take the whole search service offline.
- Kept archives out of the live Kiwix index until their download verification
  marker exists.
- Removed the full reindex from every Kiwix service start; downloads still
  rebuild the index after verification, without making boot wait on huge files.
- Added image-build verification for the hotspot, portal, downloader lock, and
  resilient Kiwix indexer fixes.

## 1.7.0 — 2026-10-13

- Added separate 256 GB, 512 GB, and 1 TB image editions.
- Added Raspberry Pi 3 Model B/B+ support alongside Pi 4B and Pi 5B.
- Reduced Kiwix worker threads automatically on Pi 3.
- Added capacity-specific content selections and protected free-space reserves.
- Ensured interrupted downloads resume using the image's original capacity tier.
- Added professional installation, hardware, security, and troubleshooting docs.
- Added North America maps, expanded practical content, and Costa branding from
  the earlier 1.6 work.

## 1.6.0 — 2026-10-12

- Added North America and Puerto Rico offline maps.
- Expanded first aid, agriculture, food, power, machinery, repair, shelter, and
  community-recovery content.
- Added the Costa mobile design and phone-first recovery guide.
- Added full 1 TB content profile and resumable progress reporting.
