# Belhaven Project

A remote Linux desktop that runs Google Chrome Stable inside GitHub Codespaces. The local tab displays that desktop; Chrome itself stays in the Codespace.

## Start

1. Create a Codespace for this repository. Codespaces builds the container image with Chrome and the desktop services.
2. After the container finishes building, run:

   ```bash
   bash setup.sh
   ```

3. Open the **Ports** panel, find port **6080** labeled **Belhaven Project**, and choose **Open in Browser**.

When using an existing Codespace after changing the container files, rebuild the container first. The launch command starts the desktop and keeps running in the terminal. Press **Ctrl+C** there to stop the services.

## Where your session lives

Chrome, its profile, opened tabs and windows, and downloaded files are in the Codespace. Downloads go to `~/BelhavenProject/Downloads`. Opening a link in a new tab or window inside Chrome opens it in the remote desktop, while the local page continues showing the desktop.

The page does not connect the laptop clipboard or laptop files to the session. Keyboard and pointer actions you make in the displayed desktop are sent to the remote Chrome session.

Keep port 6080 **private** in the Codespaces Ports panel. The container configuration sets its label and forwarding, but Codespaces visibility is managed in that panel.

## Notes

Chrome runs in a virtual display. Video smoothness depends on the Codespaces machine and network, and protected streaming playback is not guaranteed. Audio forwarding is not configured.

