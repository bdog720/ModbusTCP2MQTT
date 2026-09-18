# Changelog

## 0.4.1

Fork of MatterVN/ModbusTCP2MQTT, so the app installs on current Home Assistant again.

- Name the base image in the Dockerfile. Supervisor 2026.04.0 stopped supplying a default
  `BUILD_FROM`, which broke every install with `base name ($BUILD_FROM) should not be blank`.
  The base is now `ghcr.io/home-assistant/base-python:3.12-alpine3.22`.
- Publish a pre-built multi-arch image to `ghcr.io/bdog720/modbustcp2mqtt`. Home Assistant pulls
  it instead of building on the host.
- Restructure the repository as an app store: `repository.yaml` at the root, app files under
  `modbus_inverter/`.
- Delete `config.json`. It disagreed with `config.yaml` on both the version and the schema.
- Update the Python dependencies for Python 3.12: PyYAML 6, paho-mqtt 2.x, pycryptodomex 3.19 or
  later. Drop `readsettings`, which was never imported. pymodbus stays on 2.5.x because
  `SungrowModbusTcpClient` needs that API.
- Drop armhf, armv7 and i386. The Supervisor no longer supports them.
- Change the Docker label `io.hass.type` from `addon` to `app`.

No change to MQTT topics, sensor names or Home Assistant discovery IDs.

## 0.3.3.1
- Update to Sungather July-8 commit

## 0.3.3
- Create only necessary sensors according to Scan_level

## 0.3.2
- Add option model to force detect
- Add internal temperature sensor

## 0.3.1
- Remove conflict config.json file

## 0.3
- Use new source SunGather
- Auto detect Inverter model

## 0.2.2
- Add Sungrow-SG7RT
- ModbusWebClient (port 8082) support WiNet-S dongle
- Fix metric name

## 0.2.1.1
- Fix energy unit of measurement

## 0.2.1 
- Support SH10RT


## 0.2 
- MQTT Auto Discovery

## 0.1

- release first version