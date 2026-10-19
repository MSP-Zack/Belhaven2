# SDD ledger — plan: docs/superpowers/plans/2026-10-19-codespaces-desktop.md

Ruling: This project folder has no Git repository. Work directly in the user-designated folder, which the user explicitly asked us to populate; do not initialize Git or create commits because the user is handling GitHub. Cost if wrong: there is no worktree isolation or commit history for this implementation.

Ruling: Codespaces port visibility is not a supported devcontainer `portsAttributes` setting. Use the documented private default and tell the user to keep the forwarded port private; do not add an unsupported configuration key. Sources: https://github.com/devcontainers/spec/blob/main/docs/specs/devcontainerjson-reference.md and https://docs.github.com/en/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace.

Ruling: The user explicitly asked for the author to review the final product. Perform an independent self-review pass without delegating a subagent.

Pre-flight: Task 1 provides the image and port configuration consumed by Task 3; Task 2 provides the project page combined with image-provided client assets by Task 3; Task 4 documents the settled launcher and port contract; Task 5 validates the integrated container/runtime. Execute in planned order.


Ruling: Ubuntu Noble provides websockify 0.10, whose interface does not include the --file-only option; serve the custom viewer root with its documented --web mode and keep the Codespaces port private. Cost if wrong: a user who makes the port public exposes viewer assets and an unauthenticated remote desktop session to anyone with the URL.

Final author review: Chrome Stable is required with no fallback or sandbox bypass; the desktop listener binds to loopback; only the web viewer port is forwarded; the viewer opens a same-origin secure socket, has no clipboard/file-transfer APIs, and uses the exact requested title/application name. Chrome profile and downloads are remote. The launcher tracks and terminates only its child processes.

Local verification: 13 standard-library checks passed; shell syntax checks passed; JavaScript syntax check passed; filename scan found no restricted filename matches; visible page title and application-name metadata both read Belhaven Project.

Remaining runtime verification: Docker is unavailable in this environment. The image has not been built here, and the actual Codespaces startup, remote popup behavior, forwarded WebSocket, download location, and shutdown cleanup still need the user's Codespaces run. Do not claim end-to-end runtime success. Startup command is bash setup.sh; keep port 6080 private in the Codespaces Ports panel.