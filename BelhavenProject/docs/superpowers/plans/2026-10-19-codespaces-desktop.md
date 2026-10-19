# Belhaven Project Codespaces Desktop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Replace the failed scaffold with a Codespaces-ready remote Linux desktop running Google Chrome Stable, reached through one forwarded port, with all Chrome windows staying in the remote desktop.

**Architecture:** A devcontainer image installs Chrome Stable and the virtual display stack. Chrome, its profile, and downloads run as the non-root Codespaces user. A custom full-window page serves through the same websockify listener as the display connection. The desktop service listens only on loopback; Codespaces forwards only port 6080.

**Tech Stack:** GitHub Codespaces devcontainer, Ubuntu, Google Chrome Stable, Xvfb, Fluxbox, x11vnc, websockify, pinned upstream noVNC client core, HTML/CSS/JavaScript, Python standard-library checks.

**Spec:** `docs/superpowers/specs/2026-10-19-codespaces-desktop-design.md`

## Global Constraints

- Keep the HTML title, application-name metadata, and Codespaces port label exactly `Belhaven Project`.
- Forward only port 6080. Serve the page and its WebSocket connection from that one port; bind the internal desktop service to `127.0.0.1`.
- Install official Google Chrome Stable and fail clearly if it is missing. Do not fall back to Chromium or disable Chrome's sandbox.
- Run Chrome, its profile, and downloads inside the Codespace. Do not enable local clipboard integration, file transfer, or uploads.
- Ensure remote links, tabs, and pop-up windows open in the remote Chrome desktop; the viewing tab remains on the desktop page.
- Keep filenames and visible metadata clear of the restricted terms. Keep technical identifiers where the code requires them.
- Install dependencies during devcontainer image build; document one launch command: `bash setup.sh`.
- Do not initialize Git or perform GitHub actions; the user is handling GitHub.

## Review Focus

1. **Remote pop-up containment:** acceptance check opens a `target=_blank` link and a new Chrome window; both must appear inside the displayed desktop while the viewer URL stays unchanged.
2. **Wrong Chrome binary:** automated config check and container smoke check confirm Google Chrome Stable is installed and startup fails instead of selecting Chromium.
3. **Local clipboard or file leakage:** source/config checks verify there is no clipboard bridge, upload control, or file transfer; acceptance check confirms local clipboard contents are not pasted remotely.
4. **Port exposure and routing:** automated configuration check confirms only port 6080 is forwarded and the internal service binds loopback; container smoke check reaches the page and WebSocket through the same port.
5. **Startup and cleanup:** launcher smoke check confirms readiness checks, clear failure behavior, and cleanup of only its own child processes on stop/restart.

## Tasks

### 1. Build the Codespaces runtime

**Files:** `.devcontainer/devcontainer.json`, `Dockerfile`, `tests/test_project.py`

- [x] Write standard-library checks for valid devcontainer JSON, exactly one forwarded port, its exact label, official Chrome Stable installation, and absence of a Chromium fallback.
- [x] Replace the current devcontainer and image setup with a non-root Ubuntu Codespaces environment containing Google Chrome Stable, Xvfb, Fluxbox, x11vnc, websockify, required fonts/utilities, and the pinned upstream client assets.
- [x] Keep the desktop service unforwarded and loopback-bound; configure the Codespaces port for the intended private access and exact label. Codespaces visibility must be kept private in the Ports panel.
- [x] Run python3 -m unittest discover -s tests -v (13 tests pass). Docker is unavailable here, so image build and in-container Chrome version verification remain unverified.

### 2. Implement the custom desktop page

**Files:** `web/index.html`, `web/desktop.js`, `web/style.css`, `tests/test_project.py`

- [x] Add checks for exact page title and application-name metadata, same-origin secure WebSocket URL derivation, and absence of clipboard/file-transfer controls or APIs.
- [x] Build a full-window responsive viewer around the pinned client core, with connection status, useful failure feedback, scaling, and reconnect behavior.
- [x] Serve only the custom page and required client assets; do not expose the upstream default page.
- [x] Run the unit checks and inspect HTML/asset paths in source. Served behavior remains unverified without a Codespaces runtime.

### 3. Implement the one-command runtime launcher

**Files:** `setup.sh`, `scripts/start.sh`, `tests/test_project.py`

- [x] Add checks that startup requires the exact Chrome Stable executable and binds the desktop service to loopback.
- [x] Make setup.sh the documented entry point and have it start the virtual display, window manager, Chrome, and internal desktop service before the single websockify listener.
- [x] Use a remote-only Chrome profile and download directory. Check readiness before serving, print actionable errors, and trap shutdown to stop only child processes started by this launcher.
- [x] Run bash -n setup.sh scripts/start.sh and the unit checks. Container startup and shutdown remain unverified.

### 4. Replace scaffold documentation and remove obsolete setup

**Files:** `README.md`, `requirements.txt`, `scripts/Cashe.sh`

- [x] Replace the README with image-build, one-command start, port-opening, Codespaces privacy, and remote-download instructions.
- [x] Remove obsolete dependency and launcher files after confirming the new flow replaces them.
- [x] Scan filenames and visible metadata against the agreed wording constraints; no restricted filenames or incorrect page title were found. README contains the current port and launch instructions.

### 5. Verify the complete Codespaces experience

**Files:** `tests/test_project.py` (if additional checks are needed)

- [x] Run all standard-library checks (13 pass), shell syntax checks, and JavaScript syntax checks.
- [ ] In a built Codespaces container, verify Chrome Stable, page metadata, one-port HTTP and WebSocket access, and loopback-only internal service binding.
- [ ] Complete the remote pop-up, local clipboard, download-location, and restart/cleanup acceptance checks from Review Focus.
- [x] Record the environment-specific limitation below; end-to-end Codespaces behavior is not claimed.

