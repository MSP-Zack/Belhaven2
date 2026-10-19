FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG CLIENT_VERSION=1.7.0

RUN set -eux; \
    if [ "$(dpkg --print-architecture)" != "amd64" ]; then \
        echo "Belhaven Project requires an amd64 Codespaces machine for Google Chrome Stable." >&2; \
        exit 1; \
    fi; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        fluxbox \
        fonts-liberation \
        fonts-noto-color-emoji \
        gnupg \
        python3 \
        websockify \
        x11-utils \
        x11-xserver-utils \
        x11vnc \
        xfonts-base \
        xvfb; \
    install -d -m 0755 /usr/share/keyrings; \
    curl -fsSLo /tmp/google-linux-signing-key.pub https://dl.google.com/linux/linux_signing_key.pub; \
    gpg --dearmor --yes -o /usr/share/keyrings/google-linux-signing-keyring.gpg /tmp/google-linux-signing-key.pub; \
    printf '%s\n' 'deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux-signing-keyring.gpg] https://dl.google.com/linux/chrome/deb/ stable main' \
        > /etc/apt/sources.list.d/google-chrome.list; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends google-chrome-stable; \
    google-chrome-stable --version | grep -E '^Google Chrome '; \
    mkdir -p /tmp/client-source /usr/local/share/belhaven-project/client/core /usr/local/share/belhaven-project/client/vendor; \
    curl -fsSLo /tmp/client-assets.tar.gz "https://github.com/novnc/noVNC/archive/refs/tags/v${CLIENT_VERSION}.tar.gz"; \
    tar -xzf /tmp/client-assets.tar.gz --strip-components=1 -C /tmp/client-source; \
    test -f /tmp/client-source/core/rfb.js; \
    test -f /tmp/client-source/LICENSE.txt; \
    cp -a /tmp/client-source/core/. /usr/local/share/belhaven-project/client/core/; \
    cp -a /tmp/client-source/vendor/. /usr/local/share/belhaven-project/client/vendor/; \
    install -m 0644 /tmp/client-source/LICENSE.txt /usr/local/share/belhaven-project/LICENSE.txt; \
    rm -rf /tmp/client-source /tmp/client-assets.tar.gz /tmp/google-linux-signing-key.pub; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

EXPOSE 6080

USER vscode

