# Security

## Public default credentials

The downloadable images have public defaults so first boot remains simple:

- hotspot: `Axiom`
- hotspot password: `AllWay$Preeped`
- Linux/SSH user: `prepper`
- Linux/SSH password: `Axiom-Prepper-2026`

Anyone who can reach the device knows these defaults. Change them after the
first successful setup.

Change the Linux password:

```bash
passwd
```

Change the hotspot password:

```bash
sudo nmcli connection modify prepper-hotspot wifi-sec.psk 'YOUR-NEW-PASSWORD'
sudo nmcli connection down prepper-hotspot
sudo nmcli connection up prepper-hotspot ifname wlan0
```

Use at least 12 characters. Record the new passwords offline.

## SSH design

SSH password login is enabled for the `prepper` user so the headless system can
be maintained. Direct root login is disabled. If you do not need SSH, disable
it after installation:

```bash
sudo systemctl disable --now ssh
```

Do not expose port 22 or the web portal directly to the public internet. The
system is designed for a trusted local network or its own isolated hotspot.

## Reporting a vulnerability

Do not publish an exploitable security problem in a public issue. Contact the
repository owner through the GitHub profile and provide a concise description,
affected version, reproduction steps, and likely impact. Avoid including real
passwords or private network information.

## Content safety

Offline references can become outdated. Historical sources are preserved for
research and are not automatically current medical, engineering, electrical,
food-safety, or radiation-safety advice.
