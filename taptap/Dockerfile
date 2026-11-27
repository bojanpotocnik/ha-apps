# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-dockerfile

# Define build arguments with defaults (from build.yaml)
ARG BUILD_ARCH="amd64"
# renovate: datasource=github-releases depName=taptap packageName=litinoveweedle/taptap versioning=semver
ARG TAPTAP_VERSION="0.2.6"
# renovate: datasource=github-releases depName=taptap-mqtt packageName=litinoveweedle/taptap-mqtt versioning=semver
ARG TAPTAP_MQTT_VERSION="0.2.6"

# Use multi-arch base image
# renovate: datasource=github-releases depName=hassio-addon-base packageName=hassio-addons/addon-base versioning=semver
FROM ghcr.io/hassio-addons/base/${BUILD_ARCH}:20.1.0

# Bring build arguments into the build context
ARG BUILD_ARCH
ARG TAPTAP_VERSION
ARG TAPTAP_MQTT_VERSION

WORKDIR /tmp

# Install python/pip
RUN apk upgrade --no-cache && apk add --no-cache python3 py3-pip

# Get taptap binary
RUN \
    if [ "${BUILD_ARCH}" = "aarch64" ]; then \
        TAPTAP_ARCH="musl-arm64"; \
    elif [ "${BUILD_ARCH}" = "amd64" ]; then \
        TAPTAP_ARCH="musl-x86_64"; \
    else \
        exit 1; \
    fi \
    && mkdir /usr/bin/taptap \
    && chmod 755 /usr/bin/taptap \
    && curl -sSLf -o /tmp/taptap.tgz \
    "https://github.com/litinoveweedle/taptap/releases/download/v${TAPTAP_VERSION}/taptap-Linux-${TAPTAP_ARCH}.tar.gz" \
    && tar -xzvf taptap.tgz \
    && cp taptap /usr/bin/taptap/ \
    && chmod 755 /usr/bin/taptap/taptap \
    && rm -Rf /tmp/*

# Get taptap-mqtt bridge
RUN \
    mkdir /etc/taptap \
    && chmod 755 /etc/taptap \
    && curl -sSLf -o /tmp/taptap-mqtt.tgz \
    "https://github.com/litinoveweedle/taptap-mqtt/archive/refs/tags/v${TAPTAP_MQTT_VERSION}.tar.gz" \
    && tar -xzvf taptap-mqtt.tgz \
    && cp taptap-mqtt-*/taptap-mqtt.py /usr/bin/taptap/ \
    && chmod 755 /usr/bin/taptap/taptap-mqtt.py \
    && pip install -r taptap-mqtt-*/requirements.txt \
    && rm -Rf /tmp/*

# Copy root filesystem
COPY rootfs /
RUN chmod 775 /etc

# Labels
LABEL \
    org.opencontainers.image.title="Home Assistant App: TapTap" \
    org.opencontainers.image.description="Tigo CCA to HomeAssistant MQTT bridge" \
    org.opencontainers.image.source="https://github.com/bojanpotocnik/ha-apps" \
    org.opencontainers.image.licenses="Apache 2.0" \
    org.opencontainers.image.authors="Dominik Strnad <litinoveweedle@gmail.com>, Bojan Potocnik <info@bojanpotocnik.com>" \
    org.opencontainers.image.url="https://github.com/bojanpotocnik/ha-apps" \
    org.opencontainers.image.documentation="https://github.com/bojanpotocnik/ha-apps/blob/main/taptap/DOCS.md" \
    org.opencontainers.image.vendor="Home Assistant apps by Bojan Potocnik" \
    maintainer="Bojan Potocnik <info@bojanpotocnik.com>"
