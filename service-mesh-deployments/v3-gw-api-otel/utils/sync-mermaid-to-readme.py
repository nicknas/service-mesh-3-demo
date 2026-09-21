#!/usr/bin/env python3
"""Embed .mmd sources into README.adoc using GitHub-compatible [source,mermaid] blocks."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.adoc"
IMAGES = ROOT / "images"

# marker_name -> mmd filename (relative to images/)
DIAGRAMS = {
    "service-mesh-gw-api": "service-mesh-gw-api.mmd",
    "sm3-otel-tempo": "sm3-otel-tempo.mmd",
}

START = "<!-- mermaid:{name}:start -->"
END = "<!-- mermaid:{name}:end -->"


def block(name: str, content: str) -> str:
    body = content.strip("\n")
    return (
        f"{START.format(name=name)}\n"
        "[source,mermaid]\n"
        "----\n"
        f"{body}\n"
        "----\n"
        f"{END.format(name=name)}"
    )


def main() -> None:
    text = README.read_text(encoding="utf-8")

    for name, mmd_file in DIAGRAMS.items():
        content = (IMAGES / mmd_file).read_text(encoding="utf-8")
        replacement = block(name, content)
        start = START.format(name=name)
        end = END.format(name=name)

        if start in text and end in text:
            before, rest = text.split(start, 1)
            _, after = rest.split(end, 1)
            text = before + replacement + after
        else:
            raise SystemExit(f"Markers not found for {name}. Add {start} / {end} to README.adoc")

    README.write_text(text, encoding="utf-8")
    print(f"Updated {README} ({len(DIAGRAMS)} diagrams)")


if __name__ == "__main__":
    main()
