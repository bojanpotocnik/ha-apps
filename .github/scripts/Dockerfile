FROM ubuntu:26.04

RUN apt-get update \
    && apt-get install --no-install-recommends --yes git shellcheck yamllint \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
