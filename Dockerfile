FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip ca-certificates \
    libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 \
    libgl1 libasound2 libpulse0 libudev1 \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q -O /tmp/godot.zip \
      https://github.com/godotengine/godot/releases/download/4.5-stable/Godot_v4.5-stable_linux.x86_64.zip \
    && unzip -q /tmp/godot.zip -d /tmp/godot \
    && mv /tmp/godot/Godot_v4.5-stable_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm -rf /tmp/godot /tmp/godot.zip

WORKDIR /app
COPY server/ /app/

RUN godot --headless --path /app --import || true

CMD ["godot", "--headless", "--path", "/app", "-s", "server.gd"]
