# The Supervisor no longer supplies a default BUILD_FROM build argument, so the
# base image must be named here. The tag pins the Python version, because
# SungrowModbusTcpClient and pymodbus 2.5 need Python 3.12.
FROM ghcr.io/home-assistant/base-python:3.12-alpine3.22

ENV LANG=C.UTF-8

# The Supervisor and the builder action supply these two build arguments.
ARG BUILD_VERSION="dev"
ARG BUILD_ARCH="amd64"

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY SunGather/ /
COPY SunGather/exports/ /exports
COPY run.sh /
COPY config_generator.py /

VOLUME /logs
VOLUME /config

RUN chmod a+x /run.sh

CMD ["/run.sh"]

LABEL \
    io.hass.name="ModbusTCP2MQTT" \
    io.hass.description="Sungrow-SMA solar inverter communication app" \
    io.hass.type="app" \
    io.hass.version=${BUILD_VERSION} \
    io.hass.arch=${BUILD_ARCH} \
    org.opencontainers.image.source="https://github.com/bdog720/ModbusTCP2MQTT" \
    org.opencontainers.image.licenses="MIT"
