#!/usr/bin/env python3
"""Normalize Quarto/Pandoc DOCX styles to the CV Word template styles."""

from __future__ import annotations

import argparse
import shutil
import tempfile
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile
from xml.etree import ElementTree as ET


W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
W_VAL = f"{{{W_NS}}}val"
W = f"{{{W_NS}}}"

ET.register_namespace("w", W_NS)
ET.register_namespace("r", "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
ET.register_namespace("wp", "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing")
ET.register_namespace("a", "http://schemas.openxmlformats.org/drawingml/2006/main")
ET.register_namespace("pic", "http://schemas.openxmlformats.org/drawingml/2006/picture")


def normalize_document_xml(document_xml: bytes) -> bytes:
    root = ET.fromstring(document_xml)
    parent = {child: node for node in root.iter() for child in node}
    first_content_heading = True

    for p_style in root.findall(f".//{{{W_NS}}}pStyle"):
        value = p_style.attrib.get(W_VAL)
        if value == "Compact" and is_inside_table(p_style, parent):
            p_style.set(W_VAL, "Normal")
            continue

        if value == "Heading1" and first_content_heading:
            p_style.set(W_VAL, "Subtitle")
            first_content_heading = False
        elif value == "Heading2":
            p_style.set(W_VAL, "Heading1")
        elif value in {"FirstParagraph", "BodyText"}:
            p_style.set(W_VAL, "Normal")
        elif value == "Compact":
            p_style.set(W_VAL, "ListParagraph")

    normalize_contact_table(root)
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def is_inside_table(node: ET.Element, parent: dict[ET.Element, ET.Element]) -> bool:
    while node in parent:
        node = parent[node]
        if node.tag == f"{W}tbl":
            return True
    return False


def normalize_contact_table(root: ET.Element) -> None:
    table = root.find(f".//{W}tbl")
    if table is None:
        return

    tbl_pr = table.find(f"{W}tblPr")
    if tbl_pr is None:
        tbl_pr = ET.Element(f"{W}tblPr")
        table.insert(0, tbl_pr)

    borders = tbl_pr.find(f"{W}tblBorders")
    if borders is None:
        borders = ET.SubElement(tbl_pr, f"{W}tblBorders")
    for name in ("top", "left", "bottom", "right", "insideH", "insideV"):
        border = borders.find(f"{W}{name}")
        if border is None:
            border = ET.SubElement(borders, f"{W}{name}")
        border.set(W_VAL, "nil")

    for row in table.findall(f"{W}tr"):
        cells = row.findall(f"{W}tc")
        for index, cell in enumerate(cells):
            for paragraph in cell.findall(f".//{W}p"):
                p_pr = paragraph.find(f"{W}pPr")
                if p_pr is None:
                    p_pr = ET.Element(f"{W}pPr")
                    paragraph.insert(0, p_pr)

                p_style = p_pr.find(f"{W}pStyle")
                if p_style is not None:
                    p_style.set(W_VAL, "Normal")

                jc = p_pr.find(f"{W}jc")
                if jc is None:
                    jc = ET.SubElement(p_pr, f"{W}jc")
                jc.set(W_VAL, "right" if index == 1 else "left")


def normalize_docx(path: Path) -> None:
    with tempfile.NamedTemporaryFile(delete=False, suffix=".docx") as tmp:
        tmp_path = Path(tmp.name)

    try:
        with ZipFile(path, "r") as src, ZipFile(tmp_path, "w", ZIP_DEFLATED) as dst:
            for item in src.infolist():
                data = src.read(item.filename)
                if item.filename == "word/document.xml":
                    data = normalize_document_xml(data)
                dst.writestr(item, data)

        shutil.move(str(tmp_path), path)
    finally:
        if tmp_path.exists():
            tmp_path.unlink()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("docx", type=Path)
    args = parser.parse_args()
    normalize_docx(args.docx)


if __name__ == "__main__":
    main()
