# ModbusTCP2MQTT (bdog720 fork)

A fork of [MatterVN/ModbusTCP2MQTT](https://github.com/MatterVN/ModbusTCP2MQTT). It reads a Sungrow
or SMA solar inverter over Modbus TCP and publishes the readings to MQTT, with Home Assistant
discovery.

## Why this fork exists

Upstream no longer installs. Supervisor 2026.04.0 stopped supplying a default `BUILD_FROM` build
argument, and the upstream Dockerfile has nothing else to build `FROM`, so the install fails before
it does anything:

```
ERROR: failed to build: failed to solve: base name ($BUILD_FROM) should not be blank
```

This fork names its base image explicitly and ships a pre-built image on GHCR. Home Assistant pulls
that image instead of building one on your machine.

## Install

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**.
2. Open the three-dot menu at the top right, choose **Repositories**, and add
   `https://github.com/bdog720/ModbusTCP2MQTT`.
3. Install **ModbusTCP2MQTT**, configure it, and start it.

Install the Mosquitto broker add-on first. This app declares `mqtt:need` and refuses to start
without a broker.

If you used MatterVN's `HassioAddon` repository before, remove it. Otherwise the store lists the
app twice.

## What changed

| | Upstream 0.3.9.1 | This fork 0.4.1 |
|---|---|---|
| Base image | `$BUILD_FROM`, unset since Supervisor 2026.04.0 | `ghcr.io/home-assistant/base-python:3.12-alpine3.22` |
| Install method | built on the Home Assistant host | pulled from `ghcr.io/bdog720/modbustcp2mqtt` |
| Config files | `config.yaml` and `config.json` disagreed on the version and the schema | `config.json` deleted |
| Architectures | armhf, armv7, aarch64, amd64, i386 | aarch64, amd64 |
| PyYAML | `5.3.1`, which does not build on Python 3.12 | `>=6.0,<7` |
| paho-mqtt | `>=1.5.1`, though the code needs the 2.x callback API | `>=2.0,<3` |
| pycryptodomex | `~=3.11.0` | `>=3.19` |
| `readsettings` | listed but never imported | removed |
| Repository layout | app at the repository root | `repository.yaml` plus a `modbus_inverter/` folder |
| Docker label | `io.hass.type="addon"` | `io.hass.type="app"` |
| CI | none | GitHub Actions builds and pushes both architectures |

pymodbus stays on 2.5.x. `SungrowModbusTcpClient` uses the pymodbus 2.x API, and `Connection:
Sungrow` needs that client for the encrypted Sungrow protocol. Moving to pymodbus 3.x would break
it.

Nothing in `SunGather/` changed. MQTT topics and Home Assistant discovery IDs come from the sensor
name and the inverter model only, never from the app slug, so existing entities such as
`sensor.inverter_export_to_grid` survive the move to a store install.

## Test

`tests/smoke.sh` builds the image the way the Supervisor does, passing only `BUILD_VERSION` and
`BUILD_ARCH`, then checks the Python import chain and the generated config inside the image. It
needs Docker with buildx.

```bash
tests/smoke.sh modbus_inverter amd64
tests/smoke.sh modbus_inverter aarch64
```

The same script runs in CI against both architectures.

## Release

The workflow publishes on every push to `main` that touches `modbus_inverter/`, `tests/` or the
workflow itself.

Bump `version:` in `modbus_inverter/config.yaml` for every release. The workflow passes
`skip-existing: <version>`, so an existing tag is never re-pushed. Forget the bump and the build
still goes green, but nothing reaches GHCR. The run logs a warning instead.

The `image:` value in `config.yaml` must match what the workflow publishes. The `init` job checks
this and fails the build if the two disagree.

---

## Upstream reference

Sungrow and SMA solar inverter app for Home Assistant. It connects directly to the inverter using
Modbus TCP or Modbus Web TCP.

<img src="images/diagram.gif"/>

## Support models
**The Inverter must be accessible on the network using TCP.**

### PV Grid-Connected String Inverters
SG30KTL, SG10KTL, SG12KTL, SG15KTL, SG20KTL, SG30KU, SG36KTL, SG36KU, SG40KTL, SG40KTL-M, SG50KTL-M, SG60KTL-M, SG60KU, SG30KTL-M, SG30KTL-M-V31, SG33KTL-M, SG36KTL-M, SG33K3J, SG49K5J, SG34KJ, LP_P34KSG, SG50KTL-M-20, SG60KTL, SG80KTL, SG80KTL-20, SG60KU-M, SG5KTL-MT, SG6KTL-MT, SG8KTL-M, SG10KTL-M, SG10KTL-MT, SG12KTL-M, SG15KTL-M, SG17KTL-M, SG20KTL-M, SG80KTL-M, SG111HV, SG125HV, SG125HV-20, SG30CX, SG33CX, SG36CX-US, SG40CX, SG50CX, SG60CX-US, SG110CX, SG250HX, SG250HX-US, SG100CX, SG100CX-JP, SG250HX-IN, SG25CX-SA, SG75CX, SG3.0RT, SG4.0RT, SG5.0RT, SG6.0RT, SG7.0RT, SG8.0RT, SG10RT, SG12RT, SG15RT, SG17RT, SG20RT

### PV Grid-Connected String Inverters Gen 2
SG5K-D, SG8K-D

### Residential Hybrid Inverters
SH5K-20, SH3K6, SH4K6, SH5K-V13, SH5K-30, SH3K6-30, SH4K6-30, SH5.0RS, SH3.6RS, SH4.6RS, SH6.0RS, SH10RT, SH8.0RT, SH6.0RT, SH5.0RT


## smart_meter: True - (Only needed for SG* Models) 
Set to true if you have a smart meter installed, this will return power usage at the meter box, without it you can not calculate house power usage. Hybrid inverters will provide this by default (load_power_hybrid)

## Registers
This tool should be able to access most registers exposed. Some registers only exposed to MQTT, you must create sensor manually. (Sorry i don't have time):

level: 1 - This is the most useful data for day to day

Level: 2 - This should be everything your inverter supports

Level: 3 - This will try every register, you will get lots of 0/65535 responses for registers not supported.

### Useful Registers:
This is just a brief list of registers I have found useful

daily_power_yields - Total Power in kWh generated today
total_power_yields - Total Power in kWh generated since inverter install
total_running_time - Total Hours inverter has been powered on since install
internal_temperature - Internal temperature of the Inverter
total_active_power - Current power being generated by the inverter in Watts
meter_power - (SG* Models)Power usage at the meter box, needs a smart meter installed. +ve means consuming from the grid, -ve means exporting to the grid
load_power - Power being consumed in total
load_power_hybrid - (SH* Models only) Power being consumed in total
export_to_grid - How much being currently exported to the grid. For SG* Models this is calculated from meter_power if -ve value, returned as a positive value. (For Hybrid models export_power_hybrid is used)
import_from_grid - How much being currently imported from grid. This is calculated from meter_power if +ve value (_for hybrid models export_power_hybrid [will be negative when importing from grid] is used)
timestamp - Last time data was collected, based on Inverters clock by default

## Meta
  
This add-on is based on [SunGather](https://github.com/bohdan-s/SunGather)
