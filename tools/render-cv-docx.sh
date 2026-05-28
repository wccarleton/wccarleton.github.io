#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET="${1:-all}"
REFERENCE_DOC="assets/cv_onepage_word_template.docx"

render_onepage() {
  quarto render about.qmd \
    --to docx \
    --reference-doc "$REFERENCE_DOC" \
    --output cv-onepage.docx \
    --shift-heading-level-by -1
  python3 tools/normalize-cv-docx-styles.py _site/cv-onepage.docx
}

render_full() {
  quarto render cv.qmd \
    --to docx \
    --reference-doc "$REFERENCE_DOC" \
    --output cv-full.docx \
    --shift-heading-level-by -1
  python3 tools/normalize-cv-docx-styles.py _site/cv-full.docx
}

case "$TARGET" in
  onepage)
    render_onepage
    ;;
  full)
    render_full
    ;;
  all)
    render_onepage
    render_full
    ;;
  *)
    echo "Usage: tools/render-cv-docx.sh [onepage|full|all]" >&2
    exit 2
    ;;
esac
