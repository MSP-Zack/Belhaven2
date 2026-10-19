import json
import re
import unittest
from html.parser import HTMLParser
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class PageMetadataParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.title_parts = []
        self.in_title = False
        self.application_names = []
        self.scripts = []
        self.stylesheets = []

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == "title":
            self.in_title = True
        elif tag == "meta" and attributes.get("name") == "application-name":
            self.application_names.append(attributes.get("content"))
        elif tag == "script" and attributes.get("src"):
            self.scripts.append(attributes["src"])
        elif tag == "link" and attributes.get("rel") == "stylesheet":
            self.stylesheets.append(attributes.get("href"))

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False

    def handle_data(self, data):
        if self.in_title:
            self.title_parts.append(data)


class CodespacesRuntimeTests(unittest.TestCase):
    def test_only_the_desktop_page_port_is_forwarded(self):
        config = json.loads(
            (ROOT / ".devcontainer" / "devcontainer.json").read_text(encoding="utf-8-sig")
        )

        self.assertEqual(config.get("forwardPorts"), [6080])
        self.assertEqual(
            config.get("portsAttributes", {}).get("6080", {}).get("label"),
            "Belhaven Project",
        )
        self.assertNotIn("visibility", config.get("portsAttributes", {}).get("6080", {}))

    def test_runtime_installs_chrome_stable_and_pins_client_assets(self):
        dockerfile = (ROOT / "Dockerfile").read_text(encoding="utf-8")

        self.assertRegex(
            dockerfile,
            r"(?m)^FROM mcr\.microsoft\.com/devcontainers/base:ubuntu-24\.04$",
        )
        self.assertIn("google-chrome-stable", dockerfile)
        self.assertIn("python3", dockerfile)
        self.assertRegex(dockerfile, r"CLIENT_VERSION\s*=\s*1\.7\.0")
        self.assertIn("novnc/noVNC/archive/refs/tags/v", dockerfile)
        self.assertNotRegex(dockerfile, r"(?i)\bchromium(?:-browser)?\b")
        self.assertNotRegex(dockerfile, r"(?i)--no-sandbox\b")


class ContainerExposureTests(unittest.TestCase):
    def test_image_exposes_only_the_page_port(self):
        dockerfile = (ROOT / "Dockerfile").read_text(encoding="utf-8")

        self.assertEqual(re.findall(r"(?m)^EXPOSE (.+)$", dockerfile), ["6080"])

class DesktopPageTests(unittest.TestCase):
    def test_page_sets_exact_title_and_application_name(self):
        page = (ROOT / "web" / "index.html").read_text(encoding="utf-8")
        parser = PageMetadataParser()
        parser.feed(page)

        self.assertEqual("".join(parser.title_parts).strip(), "Belhaven Project")
        self.assertEqual(parser.application_names, ["Belhaven Project"])
        self.assertEqual(parser.scripts, ["./desktop.js"])
        self.assertEqual(parser.stylesheets, ["./style.css"])

    def test_connection_targets_the_current_host_using_secure_scheme(self):
        script = (ROOT / "web" / "desktop.js").read_text(encoding="utf-8")

        self.assertIn('new URL("/websockify", window.location.href)', script)
        self.assertIn(
            'window.location.protocol === "https:" ? "wss:" : "ws:"',
            script,
        )

    def test_viewer_has_no_local_clipboard_or_file_transfer_hooks(self):
        page = (ROOT / "web" / "index.html").read_text(encoding="utf-8")
        script = (ROOT / "web" / "desktop.js").read_text(encoding="utf-8")
        source = page + script

        for forbidden in (
            "navigator.clipboard",
            "clipboardPasteFrom",
            'type="file"',
            "FileReader",
            "ondrop",
            'addEventListener("drop"',
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, source)

    def test_page_has_connection_feedback_and_loads_no_external_scripts(self):
        page = (ROOT / "web" / "index.html").read_text(encoding="utf-8")
        parser = PageMetadataParser()
        parser.feed(page)

        self.assertIn('id="connection-state"', page)
        self.assertIn('id="reconnect"', page)
        self.assertTrue(all(not re.match(r"^https?://", url) for url in parser.scripts))


class LauncherTests(unittest.TestCase):
    def test_setup_entrypoint_delegates_to_runtime_launcher(self):
        setup = (ROOT / "setup.sh").read_text(encoding="utf-8")

        self.assertIn("scripts/start.sh", setup)
        self.assertIn("exec bash", setup)
        self.assertNotRegex(setup, r"(?i)apt-get|pip install")

    def test_launcher_uses_stable_chrome_loopback_and_tracked_processes(self):
        launcher = (ROOT / "scripts" / "start.sh").read_text(encoding="utf-8")

        self.assertIn("/usr/bin/google-chrome-stable", launcher)
        self.assertNotRegex(launcher, r"(?i)\bchromium(?:-browser)?\b")
        self.assertNotRegex(launcher, r"(?i)--no-sandbox\b")
        self.assertIn("-listen 127.0.0.1", launcher)
        self.assertIn("-noclipboard", launcher)
        self.assertIn("-nosetclipboard", launcher)
        self.assertIn("-nosel", launcher)
        self.assertIn("--web", launcher)
        self.assertNotIn("--file-only", launcher)
        self.assertIn("0.0.0.0:${WEB_PORT}", launcher)
        self.assertIn("127.0.0.1:${VNC_PORT}", launcher)
        self.assertIn("CHILD_PIDS", launcher)
        self.assertIn("trap cleanup EXIT", launcher)
        self.assertNotRegex(launcher, r"(?i)\bpkill\b")

    def test_chrome_profile_and_download_directory_are_remote(self):
        launcher = (ROOT / "scripts" / "start.sh").read_text(encoding="utf-8")

        self.assertIn("$HOME/.local/share/belhaven-project/chrome-profile", launcher)
        self.assertIn("$HOME/BelhavenProject/Downloads", launcher)


class DocumentationTests(unittest.TestCase):
    def test_readme_documents_the_codespaces_start_and_remote_storage_flow(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8")

        for expected in (
            "GitHub Codespaces",
            "bash setup.sh",
            "6080",
            "Belhaven Project",
            "private",
            "Google Chrome Stable",
            "Downloads",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, readme)

    def test_python_cache_artifacts_are_ignored(self):
        gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")

        self.assertIn("__pycache__/", gitignore)
        self.assertIn("*.py[cod]", gitignore)
    def test_obsolete_setup_files_are_removed(self):
        self.assertFalse((ROOT / "requirements.txt").exists())
        self.assertFalse((ROOT / "scripts" / "Cashe.sh").exists())


if __name__ == "__main__":
    unittest.main()





