#!/usr/bin/env python3
"""Renders docs/PRIVACY_POLICY.md and docs/delete-account.md into the GitHub Pages site.

Run from the repo root after editing either file:  python3 tool/build_site.py
Needs the `markdown` package. docs/index.html and docs/style.css are written by hand.
"""
import markdown

PAGE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} · Bluecoins</title><link rel="icon" href="icon.png"><link rel="stylesheet" href="style.css"></head>
<body><main class="doc"><p class="back"><a href="./">&larr; Bluecoins</a></p>{body}
<footer>Bluecoins is free and open source. <a href="https://github.com/tanim913/bluecoins">Source on GitHub</a></footer></main></body></html>
"""

for src, out, title in [
    ("docs/PRIVACY_POLICY.md", "docs/privacy.html", "Privacy policy"),
    ("docs/delete-account.md", "docs/delete-account.html", "Delete your account"),
]:
    body = markdown.markdown(open(src).read()).replace("PRIVACY_POLICY.md", "privacy.html").replace("delete-account.md", "delete-account.html")
    open(out, "w").write(PAGE.format(title=title, body=body))
print("site pages written")
