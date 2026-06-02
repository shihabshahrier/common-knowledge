#!/usr/bin/env bash
# ck-ingest.sh <file> — Extract plain text / Markdown from a document to stdout
# so the agent can DISTILL it into the knowledge store. Extract-only: this script
# stores nothing and never writes to $CK_HOME. It prints the extracted text
# (capped) followed by a source pointer (path, sha256, bytes) the agent records
# in meta.json `sources[]`.
#
# Strategy: deterministic extraction here; the LLM summarises the output into
# decisions.md / learnings.md / codebase-map.md via /ck save or /ck learn.
#
# Usage: ck-ingest.sh <file>
# Env:   CK_INGEST_MAX_LINES (default 2000) — cap on emitted text lines.
#
# Format support (best available tool; degrades gracefully):
#   .md .txt .markdown .json .yaml .yml .sql .log .tsv  → as-is
#   .csv                                                → Markdown table (python3)
#   .pdf                                                → pdftotext, else note (agent reads PDF natively)
#   .docx                                               → textutil, else zip+XML (python3)
#   .pptx                                               → zip+XML slides (python3)
#   .xlsx                                               → zip+XML cells (python3)
#   .rtf .odt .html .htm .doc                           → textutil, else pandoc
#   (anything else)                                     → pandoc -t markdown, else raw

set -uo pipefail

FILE="${1:-}"
MAX_LINES="${CK_INGEST_MAX_LINES:-2000}"

if [[ -z "$FILE" ]]; then
  echo "Usage: ck-ingest.sh <file>" >&2
  exit 1
fi
if [[ ! -f "$FILE" ]]; then
  echo "❌ File not found: $FILE" >&2
  exit 1
fi

EXT="${FILE##*.}"
EXT="$(printf '%s' "$EXT" | tr '[:upper:]' '[:lower:]')"

emit() { head -n "$MAX_LINES"; }

echo "=== ingested: $FILE ==="
echo ""

case "$EXT" in
  md|markdown|txt|text|json|yaml|yml|sql|log|tsv)
    cat "$FILE" | emit
    ;;

  csv)
    python3 - "$FILE" <<'PY' | emit
import csv, sys
rows = list(csv.reader(open(sys.argv[1], newline='', encoding='utf-8', errors='replace')))
if not rows:
    sys.exit(0)
def esc(c): return str(c).replace('|', '\\|').strip()
hdr = rows[0]
print('| ' + ' | '.join(esc(c) for c in hdr) + ' |')
print('|' + '|'.join('---' for _ in hdr) + '|')
for r in rows[1:1001]:
    r = (r + [''] * len(hdr))[:len(hdr)]
    print('| ' + ' | '.join(esc(c) for c in r) + ' |')
if len(rows) > 1001:
    print(f'\n_({len(rows)-1} data rows; showing first 1000)_')
PY
    ;;

  pdf)
    if command -v pdftotext >/dev/null 2>&1; then
      pdftotext -layout "$FILE" - 2>/dev/null | emit
    else
      echo "ℹ️  No pdftotext. Claude Code can read this PDF natively — use the Read tool on:"
      echo "    $FILE"
    fi
    ;;

  docx)
    if command -v textutil >/dev/null 2>&1; then
      textutil -convert txt -stdout "$FILE" 2>/dev/null | emit
    else
      python3 - "$FILE" docx <<'PY' | emit
import sys, zipfile, re
f, kind = sys.argv[1], sys.argv[2]
tag = {'docx': 'w:t', 'pptx': 'a:t'}[kind]
with zipfile.ZipFile(f) as z:
    names = [n for n in z.namelist() if n.startswith('word/document')]
    text = []
    for n in names:
        xml = z.read(n).decode('utf-8', 'replace')
        text += re.findall(r'<%s[^>]*>(.*?)</%s>' % (tag, tag), xml, re.S)
print('\n'.join(re.sub(r'<[^>]+>', '', t) for t in text))
PY
    fi
    ;;

  pptx)
    python3 - "$FILE" <<'PY' | emit
import sys, zipfile, re
f = sys.argv[1]
with zipfile.ZipFile(f) as z:
    slides = sorted(n for n in z.namelist()
                    if re.match(r'ppt/slides/slide\d+\.xml$', n))
    for i, n in enumerate(slides, 1):
        xml = z.read(n).decode('utf-8', 'replace')
        runs = re.findall(r'<a:t[^>]*>(.*?)</a:t>', xml, re.S)
        runs = [re.sub(r'<[^>]+>', '', t) for t in runs]
        if runs:
            print(f'## Slide {i}')
            print('\n'.join(runs))
            print()
PY
    ;;

  xlsx)
    python3 - "$FILE" <<'PY' | emit
import sys, zipfile, re
f = sys.argv[1]
with zipfile.ZipFile(f) as z:
    shared = []
    if 'xl/sharedStrings.xml' in z.namelist():
        xml = z.read('xl/sharedStrings.xml').decode('utf-8', 'replace')
        shared = [re.sub(r'<[^>]+>', '', t)
                  for t in re.findall(r'<t[^>]*>(.*?)</t>', xml, re.S)]
    sheets = sorted(n for n in z.namelist()
                    if re.match(r'xl/worksheets/sheet\d+\.xml$', n))
    for n in sheets:
        xml = z.read(n).decode('utf-8', 'replace')
        print(f'### {n.split("/")[-1]}')
        for row in re.findall(r'<row[^>]*>(.*?)</row>', xml, re.S)[:1000]:
            cells = []
            for c in re.findall(r'<c[^>]*?(?:\st="(\w+)")?[^>]*>(.*?)</c>', row, re.S):
                typ, body = c
                v = re.findall(r'<v[^>]*>(.*?)</v>', body, re.S)
                val = v[0] if v else ''
                if typ == 's' and val.isdigit() and int(val) < len(shared):
                    val = shared[int(val)]
                cells.append(re.sub(r'<[^>]+>', '', val))
            if any(x.strip() for x in cells):
                print(' | '.join(cells))
        print()
PY
    ;;

  rtf|odt|html|htm|doc)
    if command -v textutil >/dev/null 2>&1; then
      textutil -convert txt -stdout "$FILE" 2>/dev/null | emit
    elif command -v pandoc >/dev/null 2>&1; then
      pandoc "$FILE" -t markdown 2>/dev/null | emit
    else
      echo "⚠️  No textutil/pandoc to extract .$EXT — install pandoc."
    fi
    ;;

  *)
    if command -v pandoc >/dev/null 2>&1; then
      pandoc "$FILE" -t markdown 2>/dev/null | emit || cat "$FILE" | emit
    else
      echo "⚠️  Unknown format .$EXT and no pandoc. Emitting raw (may be binary):"
      cat "$FILE" | emit
    fi
    ;;
esac

# ─── Source pointer (for meta.json sources[]) ────────────────────────────────────
if command -v sha256sum >/dev/null 2>&1; then
  SHA="$(sha256sum "$FILE" | cut -d' ' -f1)"
else
  SHA="$(shasum -a 256 "$FILE" 2>/dev/null | cut -d' ' -f1)"
fi
BYTES="$(wc -c < "$FILE" | tr -d ' ')"

echo ""
echo "=== source pointer ==="
echo "path:    $FILE"
echo "sha256:  ${SHA:-unknown}"
echo "bytes:   $BYTES"
echo "(record this in the project's meta.json \"sources\" array; do NOT commit the raw file)"
