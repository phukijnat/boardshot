"""Adds one release to an appcast.xml (newest first). Used by release.sh.

usage: appcast.py APPCAST VERSION BUILD URL LENGTH ED_SIGNATURE NOTES_HTML_FILE APP_NAME
"""
import html, sys
from datetime import datetime, timezone
from pathlib import Path

appcast, version, build, url, length, sig, notes_file, name = sys.argv[1:9]
path = Path(appcast)
notes = Path(notes_file).read_text() if notes_file and Path(notes_file).exists() else ""

if not path.exists():
    path.write_text(f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>{html.escape(name)}</title>
    <!-- ITEMS -->
  </channel>
</rss>
""")

text = path.read_text()
if f"<sparkle:shortVersionString>{version}<" in text:
    sys.exit(f"appcast already has version {version}")

date = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
item = f"""<!-- ITEMS -->
    <item>
      <title>{html.escape(version)}</title>
      <pubDate>{date}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{html.escape(version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[{notes}]]></description>
      <enclosure url="{html.escape(url)}" length="{length}" type="application/octet-stream" sparkle:edSignature="{sig}"/>
    </item>"""
path.write_text(text.replace("<!-- ITEMS -->", item, 1))
print(f"Added {version} to {path}")
