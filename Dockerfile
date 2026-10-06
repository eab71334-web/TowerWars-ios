FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip ca-certificates libfontconfig1 libx11-6 libxcursor1 \
    libxinerama1 libxrandr1 libxi6 libgl1 && rm -rf /var/lib/apt/lists/*
RUN wget -q https://github.com/godotengine/godot/releases/download/4.5-stable/Godot_v4.5-stable_linux.x86_64.zip \
    && unzip -q Godot_v4.5-stable_linux.x86_64.zip \
    && mv Godot_v4.5-stable_linux.x86_64 /usr/local/bin/godot \
    && rm Godot_v4.5-stable_linux.x86_64.zip
COPY server/ /app/
CMD ["godot", "--headless", "--path", "/app", "-s", "server.gd"]
