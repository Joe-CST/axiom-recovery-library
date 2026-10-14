# Hardware and off-grid shopping guide

This page offers a simple budget build and a more durable premium build. Prices
and product listings change, so the links open Amazon searches instead of
locking the guide to one seller.

> **Affiliate disclosure:** As an Amazon Associate I earn from qualifying
> purchases. Every Amazon link on this page is a paid link.

Verify the seller, electrical ratings, dimensions, and return policy before
buying.

## Budget build: useful and affordable

Recommended for the 256 GB edition.

| Part | What to look for | Amazon paid link |
|---|---|---|
| Computer | Raspberry Pi 4 Model B, 2 GB or more | [Search Amazon (paid link)](https://www.amazon.com/s?k=Raspberry+Pi+4+Model+B&tag=jcostamz-20) |
| Budget storage | 256 GB A2/U3 microSD card | [Search Amazon (paid link)](https://www.amazon.com/s?k=256GB+A2+U3+microSD+card&tag=jcostamz-20) |
| Premium storage | 256 GB high-endurance A2 microSD from a recognized manufacturer | [Search Amazon (paid link)](https://www.amazon.com/s?k=256GB+high+endurance+A2+microSD+card&tag=jcostamz-20) |
| Cooling | Pi 4 case with heatsinks and fan | [Search Amazon (paid link)](https://www.amazon.com/s?k=Raspberry+Pi+4+case+fan+heatsink&tag=jcostamz-20) |
| Power | 5.1 V, 3 A / 15 W USB-C supply intended for Pi 4 | [Search Amazon (paid link)](https://www.amazon.com/s?k=Raspberry+Pi+4+official+15W+USB-C+power+supply&tag=jcostamz-20) |
| Network | Cat6 Ethernet cable | [Search Amazon (paid link)](https://www.amazon.com/s?k=Cat6+Ethernet+cable&tag=jcostamz-20) |
| Storage box | Small IP67 hard case with pick-and-pluck foam | [Search Amazon (paid link)](https://www.amazon.com/s?k=IP67+waterproof+hard+case+foam&tag=jcostamz-20) |

## Premium build: maximum library

Recommended for the 1 TB edition.

| Part | What to look for | Amazon paid link |
|---|---|---|
| Computer | Raspberry Pi 5, 8 GB | [Search Amazon (paid link)](https://www.amazon.com/s?k=Raspberry+Pi+5+8GB&tag=jcostamz-20) |
| Cooling | Pi 5 active cooler or ventilated active-cooling case | [Search Amazon (paid link)](https://www.amazon.com/s?k=Raspberry+Pi+5+active+cooler+case&tag=jcostamz-20) |
| Power | Official 27 W, 5.1 V / 5 A Pi 5 supply | [Search Amazon (paid link)](https://www.amazon.com/s?k=Raspberry+Pi+5+official+27W+power+supply&tag=jcostamz-20) |
| Budget storage | 1 TB A2/U3 microSD card | [Search Amazon (paid link)](https://www.amazon.com/s?k=1TB+A2+U3+microSD+card&tag=jcostamz-20) |
| Premium storage | 1 TB A2/V30 microSD from a recognized manufacturer | [Search Amazon (paid link)](https://www.amazon.com/s?k=1TB+A2+V30+microSD+card+SanDisk+Lexar+Kingston&tag=jcostamz-20) |
| Network | Cat6 Ethernet cable | [Search Amazon (paid link)](https://www.amazon.com/s?k=Cat6+Ethernet+cable&tag=jcostamz-20) |
| Storage box | Pelican-style IP67 case with foam | [Search Amazon (paid link)](https://www.amazon.com/s?k=Pelican+waterproof+case+foam&tag=jcostamz-20) |

Pi 5 should use the proper 27 W supply during sustained downloads and indexing.
Raspberry Pi's official guidance specifies 5 V at 5 A for Pi 5, 5 V at 3 A for
Pi 4, and 5 V at 2.5 A for Pi 3. A weak supply can cause crashes or storage
corruption.

## Solar and battery options

Do **not** connect a raw solar panel directly to a Raspberry Pi. Solar voltage
changes with clouds and load. Use this chain:

```text
solar panel → solar-compatible battery/power station → regulated Pi power supply → Pi
```

### Lower-cost emergency power for Pi 4

- [60 W folding USB-C PD solar panel (paid link)](https://www.amazon.com/s?k=60W+foldable+USB-C+PD+solar+panel&tag=jcostamz-20)
- [20,000 mAh USB-C PD power bank with 5 V / 3 A output (paid link)](https://www.amazon.com/s?k=20000mAh+USB-C+PD+power+bank+5V+3A&tag=jcostamz-20)
- [Short, heavy-gauge USB-C cable (paid link)](https://www.amazon.com/s?k=short+USB-C+5A+cable&tag=jcostamz-20)

Check the power bank manual before using pass-through charging. Many banks
briefly interrupt output when solar input changes, which can crash the Pi.

### Premium off-grid power

- [100 W folding solar panel (paid link)](https://www.amazon.com/s?k=100W+foldable+solar+panel+power+station&tag=jcostamz-20)
- [300 W or larger LiFePO4 portable power station (paid link)](https://www.amazon.com/s?k=LiFePO4+portable+power+station+300W&tag=jcostamz-20)
- Use the Pi's official AC power supply from the power station.

This approach is especially helpful for Pi 5 because many ordinary USB-C PD
banks do not provide Pi 5's unusual 5 V / 5 A profile.

## Weather-resistant storage

A sealed case is for **transport and storage**, not for running the Pi. A
working Pi produces heat, and a sealed box traps both heat and condensation.

For a field kit:

- place the powered-off Pi, card/SSD, cables, and printed credentials in foam;
- add reusable silica-gel packets;
- keep a spare card in an anti-static bag;
- store one copy in a separate location;
- inspect and recharge batteries every three months.

If the Pi must operate outdoors, use a purpose-built ventilated weatherproof
electronics enclosure with cable glands, sun shielding, and condensation
control. Do not improvise mains wiring inside a wet enclosure.

## Before buying

- Confirm the card or SSD is genuine. Counterfeit storage often reports a false
  capacity and fails during the first large download.
- Buy the power supply for the exact Pi model.
- Avoid unpowered USB hubs for SSD boot.
- A short shielded USB 3 cable reduces interference with 2.4 GHz Wi-Fi.
- Test the entire setup offline before storing it.
