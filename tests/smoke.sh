#!/usr/bin/env bash
#
# Smoke test for the ModbusTCP2MQTT app image.
#
# It builds the image the same way the Home Assistant Supervisor does: it
# passes only BUILD_VERSION and BUILD_ARCH, and it does not pass BUILD_FROM.
# Then it checks that the Python import chain and the config generator work
# inside the built image.
#
# Usage: tests/smoke.sh [addon_dir] [arch]
#
set -euo pipefail

# Stop Git Bash on Windows from rewriting in-container paths such as /sungather.py.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

ADDON_DIR="${1:-modbus_inverter}"
ARCH="${2:-amd64}"
IMAGE="modbustcp2mqtt-smoke:${ARCH}"

case "$ARCH" in
  amd64)   PLATFORM="linux/amd64" ;;
  aarch64) PLATFORM="linux/arm64" ;;
  *) echo "FAIL: unsupported arch '$ARCH'" >&2; exit 1 ;;
esac

if [ ! -d "$ADDON_DIR" ]; then
  echo "FAIL: app directory '$ADDON_DIR' does not exist" >&2
  exit 1
fi

CONFIG="$ADDON_DIR/config.yaml"
if [ ! -f "$CONFIG" ]; then
  echo "FAIL: '$CONFIG' does not exist" >&2
  exit 1
fi

VERSION="$(sed -n 's/^version:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$/\1/p' "$CONFIG" | head -1)"
if [ -z "$VERSION" ]; then
  echo "FAIL: no version found in '$CONFIG'" >&2
  exit 1
fi

# A relative path is used for the generated file, because Git Bash on Windows
# does not rewrite it into a Windows path for the local Python interpreter.
GENERATED_CONFIG="smoke-config.sg"
PY="$(command -v python3 || command -v python)"
[ -n "$PY" ] || { echo "FAIL: no python interpreter on PATH" >&2; exit 1; }
trap 'rm -f "$GENERATED_CONFIG"' EXIT

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

echo "== Building $IMAGE from $ADDON_DIR (version $VERSION, arch $ARCH) =="
docker buildx build \
  --load \
  --platform "$PLATFORM" \
  --build-arg "BUILD_VERSION=$VERSION" \
  --build-arg "BUILD_ARCH=$ARCH" \
  --file "$ADDON_DIR/Dockerfile" \
  --tag "$IMAGE" \
  "$ADDON_DIR" || fail "docker build"
pass "image builds without a BUILD_FROM build arg"

echo "== Checking the Python dependency chain =="
docker run --rm --entrypoint python3 "$IMAGE" -c '
import sys
import yaml
import paho.mqtt.client as mqtt
from pymodbus.client.sync import ModbusTcpClient
from SungrowModbusTcpClient import SungrowModbusTcpClient
from SungrowModbusWebClient import SungrowModbusWebClient
assert mqtt.CallbackAPIVersion.VERSION1, "paho-mqtt 2.x CallbackAPIVersion is required"
from importlib.metadata import version
print("python", sys.version.split()[0], "| pyyaml", version("PyYAML"), "| paho-mqtt", version("paho-mqtt"), "| pymodbus", version("pymodbus"))
' || fail "python dependency imports"
pass "python dependencies import (pymodbus 2.x sync API, paho-mqtt 2.x, SungrowModbusTcpClient)"

echo "== Checking that sungather.py loads =="
docker run --rm --entrypoint python3 "$IMAGE" /sungather.py -h > /dev/null \
  || fail "sungather.py failed to load"
pass "sungather.py loads and runs"

echo "== Checking that run.sh is present and executable =="
docker run --rm --entrypoint sh "$IMAGE" -c 'test -x /run.sh' \
  || fail "/run.sh is missing or not executable"
docker run --rm --entrypoint sh "$IMAGE" -c 'command -v bashio > /dev/null' \
  || fail "bashio is missing; the image must use a Home Assistant base image"
pass "run.sh is executable and bashio is present"

echo "== Checking the generated config and the MQTT discovery names =="
docker run --rm --entrypoint sh "$IMAGE" -c '
cd /tmp && python3 /config_generator.py \
  --host=192.168.1.23 --port=502 --model=SG5K-D \
  --mqtt_host=core-mosquitto --mqtt_port=1883 \
  --mqtt_user=addons --mqtt_pass=secret \
  --scan=30 --timeout=5 --connection=Sungrow --meter=true \
  --level=DETAIL --log_level=INFO > /dev/null && cat /tmp/config.sg
' > "$GENERATED_CONFIG" || fail "config_generator.py"
pass "config_generator.py produces config.sg"

"$PY" - "$GENERATED_CONFIG" <<'PYEOF' || fail "generated config.sg content"
import sys, yaml
cfg = yaml.safe_load(open(sys.argv[1]))
inv, exp = cfg["inverter"], cfg["exports"][0]
assert inv["host"] == "192.168.1.23", inv
assert inv["port"] == 502, inv
assert inv["model"] == "SG5K-D", inv
assert inv["connection"] == "sungrow", inv
assert inv["smart_meter"] is True, inv
assert inv["level"] == 2, inv
assert exp["name"] == "mqtt" and exp["homeassistant"] is True, exp

# These names decide the Home Assistant discovery unique_ids
# ("inverter_" + name.lower().replace(" ", "_")). Existing entities and
# automations depend on them, so they must not change.
required = {
    "Export to Grid": "export_to_grid",
    "Import from Grid": "import_from_grid",
    "Active Power": "total_active_power",
    "Daily Generation": "daily_power_yields",
    "Power State": "run_state",
}
by_name = {s["name"]: s["register"] for s in exp["ha_sensors"]}
for name, register in required.items():
    assert by_name.get(name) == register, f"{name!r} -> {by_name.get(name)!r}, want {register!r}"
print("checked", len(exp["ha_sensors"]), "discovery sensors")
PYEOF
pass "discovery sensor names and registers are unchanged"

echo
echo "SMOKE TEST PASSED ($IMAGE, version $VERSION)"
