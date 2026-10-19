import RFB from "./core/rfb.js";

const desktop = document.getElementById("desktop");
const state = document.getElementById("connection-state");
const stateLabel = document.getElementById("state-label");
const connectionMessage = document.getElementById("connection-message");
const connectionOverlay = document.getElementById("connection-overlay");
const reconnectButton = document.getElementById("reconnect");
const overlayReconnectButton = document.getElementById("overlay-reconnect");
const fullscreenButton = document.getElementById("fullscreen");

let connection = null;

function setState(value, label, message = label, canRetry = false) {
  state.dataset.state = value;
  stateLabel.textContent = label;
  connectionMessage.textContent = message;
  connectionOverlay.hidden = value === "connected";
  reconnectButton.hidden = !canRetry;
  overlayReconnectButton.hidden = !canRetry;
}

function buildSocketUrl() {
  const url = new URL("/websockify", window.location.href);
  url.protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  return url.href;
}

function connect() {
  const previous = connection;
  connection = null;
  previous?.disconnect();

  setState("connecting", "Connecting…", "Starting your desktop…");

  try {
    const session = new RFB(desktop, buildSocketUrl(), { shared: true });
    session.scaleViewport = true;
    session.resizeSession = false;

    session.addEventListener("connect", () => {
      if (connection !== session) return;
      setState("connected", "Connected");
      session.focus({ preventScroll: true });
    });

    session.addEventListener("disconnect", () => {
      if (connection !== session) return;
      setState(
        "disconnected",
        "Connection closed",
        "Your Codespace may still be starting. Try reconnecting in a moment.",
        true,
      );
    });

    session.addEventListener("securityfailure", () => {
      if (connection !== session) return;
      setState(
        "error",
        "Connection failed",
        "The desktop connection could not be secured. Check that the forwarded port is open.",
        true,
      );
    });

    session.addEventListener("credentialsrequired", () => {
      if (connection !== session) return;
      setState(
        "error",
        "Connection unavailable",
        "The desktop service needs attention. Restart it from the Codespace terminal.",
        true,
      );
    });

    connection = session;
  } catch {
    setState(
      "error",
      "Connection failed",
      "The desktop page could not start. Reload the page or restart the service.",
      true,
    );
  }
}

function updateFullscreenLabel() {
  const isFullscreen = Boolean(document.fullscreenElement);
  fullscreenButton.setAttribute(
    "aria-label",
    isFullscreen ? "Exit full screen" : "Enter full screen",
  );
  fullscreenButton.querySelector("span").textContent = isFullscreen
    ? "Exit full screen"
    : "Full screen";
}

reconnectButton.addEventListener("click", connect);
overlayReconnectButton.addEventListener("click", connect);
fullscreenButton.addEventListener("click", async () => {
  try {
    if (document.fullscreenElement) {
      await document.exitFullscreen();
    } else {
      await document.documentElement.requestFullscreen();
    }
  } catch {
    // Full-screen access is optional; the desktop remains usable in the page.
  }
});
document.addEventListener("fullscreenchange", updateFullscreenLabel);

connect();

