#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="${1:-}"
[[ ${EUID} -eq 0 ]] || { printf 'Run this update with sudo.\n' >&2; exit 1; }
[[ -d "${PROJECT_DIR}/assets/maps/web" ]] || { printf 'Invalid project folder: %s\n' "${PROJECT_DIR}" >&2; exit 2; }

install -d -m 0755 \
  /etc/prepper-library \
  /srv/prepper-library/maps \
  /usr/share/prepper-portal \
  /var/lib/prepper-library \
  /var/log/prepper-library

install -m 0644 "${PROJECT_DIR}/content/north-america-region.geojson" \
  /etc/prepper-library/north-america-region.geojson
install -m 0755 "${PROJECT_DIR}/scripts/prepper-download-maps" \
  /usr/local/sbin/prepper-download-maps
install -m 0755 "${PROJECT_DIR}/scripts/prepper-healthcheck" \
  /usr/local/sbin/prepper-healthcheck
install -m 0644 "${PROJECT_DIR}/systemd/prepper-map-download.service" \
  /etc/systemd/system/prepper-map-download.service

install -m 0644 "${PROJECT_DIR}/assets/portal/index.html" /usr/share/prepper-portal/index.html
install -m 0644 "${PROJECT_DIR}/assets/portal/style.css" /usr/share/prepper-portal/style.css
install -m 0644 "${PROJECT_DIR}/assets/portal/app.js" /usr/share/prepper-portal/app.js
rm -rf /usr/share/prepper-portal/maps
cp -a "${PROJECT_DIR}/assets/maps/web" /usr/share/prepper-portal/maps
find /usr/share/prepper-portal/maps -type d -exec chmod 0755 {} +
find /usr/share/prepper-portal/maps -type f -exec chmod 0644 {} +

PMTILES_ARCHIVE="${PROJECT_DIR}/assets/maps/tools/pmtiles-linux-arm64.tar.gz"
printf '%s  %s\n' \
  'f8bd47e7ea866863489cad588fbaf2f31f42e5821f7a03f009b3769f05801cb1' \
  "${PMTILES_ARCHIVE}" | sha256sum --check --status
PMTILES_TMP="$(mktemp -d)"
trap 'rm -rf "${PMTILES_TMP}"' EXIT
tar -xzf "${PMTILES_ARCHIVE}" -C "${PMTILES_TMP}"
install -m 0755 "${PMTILES_TMP}/pmtiles" /usr/local/bin/pmtiles
rm -rf "${PMTILES_TMP}"
trap - EXIT

DEVA_FONT_DIR='/usr/share/prepper-portal/maps/vendor/fonts/Noto Sans Devanagari Regular v1'
REGULAR_FONT_DIR='/usr/share/prepper-portal/maps/vendor/fonts/Noto Sans Regular'
install -d -m 0755 "${DEVA_FONT_DIR}"
for glyph in "${REGULAR_FONT_DIR}"/*.pbf; do
  glyph_name="$(basename "${glyph}")"
  [[ -e "${DEVA_FONT_DIR}/${glyph_name}" ]] || \
    ln -s "../Noto Sans Regular/${glyph_name}" "${DEVA_FONT_DIR}/${glyph_name}"
done

install -m 0644 "${PROJECT_DIR}/nginx/prepper-library.conf" \
  /etc/nginx/sites-available/prepper-library
ln -sfn /etc/nginx/sites-available/prepper-library /etc/nginx/sites-enabled/prepper-library
nginx -t
systemctl daemon-reload
systemctl restart nginx
/usr/local/sbin/prepper-healthcheck
systemctl enable prepper-map-download.service
systemctl start --no-block prepper-map-download.service

printf 'Map update installed. Download continues under prepper-map-download.service.\n'
