#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${PROJECT_DIR}/config.env"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ ${EUID} -eq 0 ]] || die "Run this installer with sudo."
[[ -f "${CONFIG_FILE}" ]] || die "Copy config.env.example to config.env and edit it first."

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

for required in HOTSPOT_SSID HOTSPOT_PASSWORD WIFI_COUNTRY BOX_HOSTNAME HOTSPOT_ADDRESS CONTENT_PROFILE UNIQUE_CLONE_IDENTITY; do
  [[ -n "${!required:-}" ]] || die "${required} is missing from config.env"
done

[[ "${HOTSPOT_PASSWORD}" != "REPLACE-WITH-A-LONG-PASSWORD" ]] || die "Replace the example hotspot password."
(( ${#HOTSPOT_PASSWORD} >= 12 )) || die "The hotspot password must be at least 12 characters."
[[ "${HOTSPOT_SSID}" =~ ^[A-Za-z0-9._-]{1,28}$ ]] || die "HOTSPOT_SSID may use letters, numbers, dot, underscore, and dash only (max 28)."
[[ "${BOX_HOSTNAME}" =~ ^[a-z0-9][a-z0-9-]{0,30}$ ]] || die "BOX_HOSTNAME is invalid."
[[ "${WIFI_COUNTRY}" =~ ^[A-Z]{2}$ ]] || die "WIFI_COUNTRY must be a two-letter uppercase country code."
[[ "${CONTENT_PROFILE}" == "core" || "${CONTENT_PROFILE}" == "sd256" || "${CONTENT_PROFILE}" == "sd512" || "${CONTENT_PROFILE}" == "full" ]] || die "CONTENT_PROFILE must be core, sd256, sd512, or full."
[[ "${UNIQUE_CLONE_IDENTITY}" == "true" || "${UNIQUE_CLONE_IDENTITY}" == "false" ]] || die "UNIQUE_CLONE_IDENTITY must be true or false."
[[ "${HOTSPOT_ADDRESS}" == "10.10.10.1/24" ]] || die "HOTSPOT_ADDRESS must remain 10.10.10.1/24 because the offline portal uses it as its recovery address."

if [[ -r /proc/device-tree/model ]]; then
  MODEL="$(tr -d '\0' </proc/device-tree/model)"
  printf 'Detected hardware: %s\n' "${MODEL}"
  case "${MODEL}" in
    *"Raspberry Pi 3 Model B"*|*"Raspberry Pi 4 Model B"*|*"Raspberry Pi 5 Model B"*) ;;
    *) die "This build supports Raspberry Pi 3 Model B/B+, Raspberry Pi 4 Model B, and Raspberry Pi 5 Model B." ;;
  esac
else
  die "No Raspberry Pi device tree detected. Run this on the target Pi."
fi

ARCH="$(dpkg --print-architecture)"
[[ "${ARCH}" == "arm64" ]] || die "Install the 64-bit Raspberry Pi OS image (detected ${ARCH})."

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  aria2 avahi-daemon ca-certificates curl dnsutils jq kiwix-tools \
  network-manager nginx openssh-server python3 qrencode rfkill rsync smartmontools

install -d -m 0755 /etc/prepper-library /opt/prepper-library /usr/share/prepper-portal /usr/share/prepper-no-content
install -d -m 0755 /srv/prepper-library/kiwix /srv/prepper-library/manuals /srv/prepper-library/maps
install -d -m 0755 /var/lib/prepper-library /var/log/prepper-library

install -m 0600 "${CONFIG_FILE}" /etc/prepper-library/config.env
install -m 0644 "${PROJECT_DIR}/VERSION" /etc/prepper-library/version
install -m 0644 "${PROJECT_DIR}/content/kiwix-manifest.csv" /etc/prepper-library/kiwix-manifest.csv
install -m 0644 "${PROJECT_DIR}/content/documents-manifest.csv" /etc/prepper-library/documents-manifest.csv
install -m 0644 "${PROJECT_DIR}/content/north-america-region.geojson" /etc/prepper-library/north-america-region.geojson
for portal_asset in index.html guide.html library.html style.css app.js library.js costa-logo.png; do
  install -m 0644 \
    "${PROJECT_DIR}/assets/portal/${portal_asset}" \
    "/usr/share/prepper-portal/${portal_asset}"
done
install -m 0644 "${PROJECT_DIR}/assets/portal/no-content.html" /usr/share/prepper-no-content/index.html
rm -rf /usr/share/prepper-portal/maps
cp -a "${PROJECT_DIR}/assets/maps/web" /usr/share/prepper-portal/maps
find /usr/share/prepper-portal/maps -type d -exec chmod 0755 {} +
find /usr/share/prepper-portal/maps -type f -exec chmod 0644 {} +

PMTILES_ARCHIVE="${PROJECT_DIR}/assets/maps/tools/pmtiles-linux-arm64.tar.gz"
printf '%s  %s\n' \
  'f8bd47e7ea866863489cad588fbaf2f31f42e5821f7a03f009b3769f05801cb1' \
  "${PMTILES_ARCHIVE}" | sha256sum --check --status || die "Bundled pmtiles CLI checksum failed."
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

for script in \
  prepper-download-kiwix prepper-download-documents prepper-download-all \
  prepper-build-catalog prepper-reindex \
  prepper-download-maps prepper-kiwix-start prepper-healthcheck \
  prepper-firstboot prepper-prepare-image; do
  install -m 0755 "${PROJECT_DIR}/scripts/${script}" "/usr/local/sbin/${script}"
done

install -m 0644 "${PROJECT_DIR}/nginx/prepper-library.conf" /etc/nginx/sites-available/prepper-library
ln -sfn /etc/nginx/sites-available/prepper-library /etc/nginx/sites-enabled/prepper-library
rm -f /etc/nginx/sites-enabled/default

for unit in "${PROJECT_DIR}"/systemd/*; do
  install -m 0644 "${unit}" "/etc/systemd/system/$(basename "${unit}")"
done

install -d -m 0755 /etc/cloud/cloud.cfg.d
printf 'manage_etc_hosts: false\n' >/etc/cloud/cloud.cfg.d/99-prepper-hosts.cfg
hostnamectl set-hostname "${BOX_HOSTNAME}"
if grep -qE '^127\.0\.1\.1\s+' /etc/hosts; then
  sed -i -E "s/^127\.0\.1\.1\s+.*/127.0.1.1\t${BOX_HOSTNAME}/" /etc/hosts
else
  printf '127.0.1.1\t%s\n' "${BOX_HOSTNAME}" >>/etc/hosts
fi

rfkill unblock wifi || true
if command -v raspi-config >/dev/null; then
  raspi-config nonint do_wifi_country "${WIFI_COUNTRY}"
fi
nmcli radio wifi on
nmcli connection delete prepper-hotspot >/dev/null 2>&1 || true
nmcli connection add type wifi ifname wlan0 con-name prepper-hotspot ssid "${HOTSPOT_SSID}"
nmcli connection modify prepper-hotspot \
  connection.autoconnect yes \
  connection.autoconnect-priority 100 \
  802-11-wireless.mode ap \
  802-11-wireless.band bg \
  wifi-sec.key-mgmt wpa-psk \
  wifi-sec.psk "${HOTSPOT_PASSWORD}" \
  ipv4.method shared \
  ipv4.addresses "${HOTSPOT_ADDRESS}" \
  ipv4.never-default yes \
  ipv6.method disabled

systemctl daemon-reload
systemctl enable NetworkManager nginx avahi-daemon ssh
systemctl enable prepper-firstboot.service prepper-kiwix.service
systemctl enable prepper-healthcheck.timer
systemctl enable prepper-content-download.service
systemctl restart NetworkManager nginx avahi-daemon ssh

hotspot_ready=false
for _attempt in $(seq 1 30); do
  if nmcli connection up prepper-hotspot ifname wlan0; then
    hotspot_ready=true
    break
  fi
  sleep 2
done
[[ "${hotspot_ready}" == true ]] || die "The Wi-Fi hotspot could not be activated on wlan0."

qrencode -o /usr/share/prepper-portal/wifi-qr.png \
  "WIFI:T:WPA;S:${HOTSPOT_SSID};P:${HOTSPOT_PASSWORD};;"

/usr/local/sbin/prepper-reindex
/usr/local/sbin/prepper-build-catalog
systemctl restart prepper-kiwix.service || true
systemctl start prepper-healthcheck.timer
/usr/local/sbin/prepper-healthcheck || true

printf '\nInstallation complete.\n'
printf 'Hotspot: %s\n' "${HOTSPOT_SSID}"
printf 'Portal:  http://%s or http://%s.local\n' "${HOTSPOT_ADDRESS%/*}" "${BOX_HOSTNAME}"
printf 'Content downloads resume automatically after reboot.\n'
printf 'To start now: sudo systemctl start --no-block prepper-content-download.service\n'
printf 'Progress: http://%s or sudo prepper-healthcheck\n' "${HOTSPOT_ADDRESS%/*}"
