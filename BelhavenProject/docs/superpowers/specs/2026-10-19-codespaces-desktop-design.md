# Belhaven Project

## Goal

Provide a Codespaces-ready remote Linux desktop that runs Google Chrome Stable. The user opens one forwarded port in a local tab; that tab renders the remote desktop and sends keyboard and pointer input to it.

## Requirements

- Install and run the official Google Chrome Stable package. Do not accept Chromium as a fallback.
- Expose one Codespaces-forwarded port for the page and its interactive display connection.
- Set the HTML document title, application-name metadata, and Codespaces port label to exactly `Belhaven Project`.
- Keep navigation, tabs, and pop-up windows created by remote Chrome inside the remote desktop. The local tab remains the viewer.
- Keep the desktop service bound to the Codespace loopback interface; do not forward its internal port.
- Do not connect local clipboard contents or local file transfer to the remote desktop. Downloads remain in the Codespace.
- Keep project filenames free of the restricted terms. Technical package and protocol identifiers may appear where required in source and configuration.
- Include a one-command start flow after Codespaces builds the container.

## Recommended architecture

The devcontainer image installs Google Chrome Stable, Xvfb, Fluxbox, x11vnc, websockify, and the noVNC client core. Chrome runs as the non-root Codespaces user with its normal sandbox enabled, using a remote profile and downloads directory under the Codespace home directory.

Xvfb provides the remote display and Fluxbox manages Chrome windows. x11vnc serves that display on `127.0.0.1:5900`. A single websockify listener on `0.0.0.0:6080` serves the project page and carries its WebSocket connection to the loopback-only desktop service. Only port 6080 is listed in `forwardPorts`. It uses the private default visibility in Codespaces and is not configured as public.

The project supplies a small full-window HTML/JavaScript viewer using the upstream noVNC RFB client library. The page sets its own title to `Belhaven Project`, connects to a WebSocket path on the same origin, scales the remote screen to the page, and presents clear connection errors. It does not invoke clipboard read/write APIs, expose file-transfer controls, or request device access. The client core and vendor assets are fetched from the official upstream `v1.7.0` release during the image build, and the corresponding upstream license is retained. The upstream default page is not used.

## User flow

1. Codespaces builds the container and installs system dependencies from the image definition.
2. The user runs `bash setup.sh`.
3. The script starts Xvfb, Fluxbox, the remote display service, Google Chrome, and the single-port web listener. It supervises its child processes and reports startup failures.
4. The user opens the forwarded port. The top-level page title and port label both read `Belhaven Project`.
5. Clicking links or choosing to open a new tab/window inside remote Chrome acts on the remote Chrome process. The local viewing tab continues to show the remote desktop.

## Containment boundary

The Codespace owns the Chrome process, profile, downloads, display, and all opened remote windows. The local browser only displays rendered desktop output and forwards deliberate keyboard/pointer input. The implementation does not mount local files, synchronize the local clipboard, or expose the internal desktop port through Codespaces forwarding. This isolates ordinary browsing and downloads to the Codespace; it does not prevent a remote website from receiving information the user deliberately types into the remote session.

## Error handling and lifecycle

Startup validates that Google Chrome Stable and required system tools exist, waits for the X display to become ready, and fails with a focused message if a dependency or service is unavailable. The foreground launcher tracks only the processes it starts, stops them on exit, and logs startup diagnostics to the terminal. No broad process-name kills are used.


## Verification

- Build the Codespaces image from a clean checkout.
- Confirm `google-chrome-stable --version` reports Google Chrome Stable.
- Start the app using the documented single command and confirm the page title and port label.
- Confirm only port 6080 is forwarded; HTTP assets and the interactive WebSocket connection use that port, while port 5900 is loopback-only.
- Exercise remote navigation, opening links in tabs, and opening pop-up windows; confirm they remain visible inside the Codespace desktop and the local viewer URL does not change.
- Confirm no clipboard read/write path or file-transfer control exists and remote downloads stay in the Codespace.


## Runtime limitations

Google Chrome Stable runs in a virtual Codespaces display, so rendering and video performance depend on the selected Codespaces machine and network. Hardware-accelerated graphics and protected streaming playback are not guaranteed. Audio streaming is excluded from this version.

## References

- [Upstream release v1.7.0](https://github.com/novnc/noVNC/releases/tag/v1.7.0)
- [Codespaces port forwarding and labels](https://docs.github.com/en/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace)
- [Google Chrome for Linux requirements](https://support.google.com/chrome/answer/95346)

