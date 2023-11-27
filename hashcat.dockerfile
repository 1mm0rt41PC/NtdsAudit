FROM debian:stable-slim
RUN apt-get update && apt-get install -y --no-install-recommends hashcat && rm -rf /var/lib/apt/lists/*
WORKDIR /root