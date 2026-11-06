#!/usr/bin/env python3
"""Build and validate a single-column, ATS-readable CV PDF."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List
from xml.sax.saxutils import escape, quoteattr

try:
    import reportlab
    from pypdf import PdfReader
    from reportlab.lib.colors import HexColor
    from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.lib.units import mm
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.pdfgen import canvas
    from reportlab.platypus import (
        Flowable,
        KeepTogether,
        PageBreak,
        Paragraph,
        SimpleDocTemplate,
        Spacer,
    )
except ImportError as exc:
    print(f"Dependency error: {exc}", file=sys.stderr)
    sys.exit(1)


THEMES = {
    "navy_teal": {
        "title": HexColor("#0D2137"),
        "accent": HexColor("#0E8585"),
        "ink": HexColor("#111827"),
        "body": HexColor("#374151"),
        "subtle": HexColor("#6B7280"),
        "faint": HexColor("#9CA3AF"),
        "pill_bg": HexColor("#F0FDFA"),
        "pill_border": HexColor("#99F6E4"),
        "rule": HexColor("#E5E7EB"),
    },
    "charcoal_gold": {
        "title": HexColor("#1F2937"),
        "accent": HexColor("#D97706"),
        "ink": HexColor("#111827"),
        "body": HexColor("#374151"),
        "subtle": HexColor("#4B5563"),
        "faint": HexColor("#9CA3AF"),
        "pill_bg": HexColor("#FFFBEB"),
        "pill_border": HexColor("#FDE68A"),
        "rule": HexColor("#E5E7EB"),
    },
    "tech_slate": {
        "title": HexColor("#0F172A"),
        "accent": HexColor("#2563EB"),
        "ink": HexColor("#1E293B"),
        "body": HexColor("#334155"),
        "subtle": HexColor("#64748B"),
        "faint": HexColor("#94A3B8"),
        "pill_bg": HexColor("#EFF6FF"),
        "pill_border": HexColor("#BFDBFE"),
        "rule": HexColor("#E2E8F0"),
    },
    "minimal_monochrome": {
        "title": HexColor("#000000"),
        "accent": HexColor("#111111"),
        "ink": HexColor("#111111"),
        "body": HexColor("#202020"),
        "subtle": HexColor("#3D3D3D"),
        "faint": HexColor("#707070"),
        "pill_bg": HexColor("#F5F5F5"),
        "pill_border": HexColor("#D9D9D9"),
        "rule": HexColor("#404040"),
    },
    "clean_blue": {
        "title": HexColor("#000000"),
        "accent": HexColor("#1F4E79"),
        "ink": HexColor("#111111"),
        "body": HexColor("#202020"),
        "subtle": HexColor("#4B5563"),
        "faint": HexColor("#6B7280"),
        "pill_bg": HexColor("#F4F7FA"),
        "pill_border": HexColor("#C8D7E6"),
        "rule": HexColor("#1F4E79"),
    },
}

EVIDENCE_STATUSES = {"user-confirmed", "source-backed", "legacy-unverified"}
BANNED_WORDS = ("synergize", "leverage", "utilize", "results-driven")
UNICODE_REPLACEMENTS = {
    "\u2010": "-",
    "\u2011": "-",
    "\u2012": "-",
    "\u2013": "-",
    "\u2014": "-",
    "\u2015": "-",
    "\u2212": "-",
    "\u2192": "->",
    "\u2022": "-",
    "\u00b7": "|",
    "\u00a0": " ",
    "\u2018": "'",
    "\u2019": "'",
    "\u201c": '"',
    "\u201d": '"',
}


def register_fonts() -> None:
    font_dir = Path(reportlab.__file__).resolve().parent / "fonts"
    font_files = {
        "CVSans": "Vera.ttf",
        "CVSans-Bold": "VeraBd.ttf",
        "CVSans-Italic": "VeraIt.ttf",
        "CVSans-BoldItalic": "VeraBI.ttf",
    }
    for font_name, file_name in font_files.items():
        path = font_dir / file_name
        if not path.exists():
            raise RuntimeError(f"Bundled Unicode font is missing: {path}")
        if font_name not in pdfmetrics.getRegisteredFontNames():
            pdfmetrics.registerFont(TTFont(font_name, str(path)))


def normalize_text(value: Any) -> str:
    text = "" if value is None else str(value)
    for source, replacement in UNICODE_REPLACEMENTS.items():
        text = text.replace(source, replacement)
    text = "".join(
        char for char in text
        if ord(char) >= 32 or char in "\n\t"
    )
    return re.sub(r"[ \t]+", " ", text).strip()


def safe_text(value: Any) -> str:
    return escape(normalize_text(value))


def safe_contact_item(value: Any) -> str:
    text = normalize_text(value)
    display = escape(text)
    if re.fullmatch(r"https?://\S+", text, flags=re.IGNORECASE):
        return f"<link href={quoteattr(text)}>{display}</link>"
    if re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", text):
        return f"<link href={quoteattr('mailto:' + text)}>{display}</link>"
    if re.fullmatch(r"\+?[\d\s().-]{7,}", text):
        destination = re.sub(r"[^\d+]", "", text)
        return f"<link href={quoteattr('tel:' + destination)}>{display}</link>"
    return display


def safe_contact_line(items: Iterable[Any]) -> str:
    return " | ".join(safe_contact_item(item) for item in items)


def iter_strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from iter_strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from iter_strings(child)


def require_string(
    data: Dict[str, Any],
    key: str,
    errors: List[str],
    *,
    allow_empty: bool = False,
) -> None:
    value = data.get(key)
    if not isinstance(value, str):
        errors.append(f"{key} must be a string")
    elif not allow_empty and not value.strip():
        errors.append(f"{key} must not be empty")


def require_string_list(
    data: Dict[str, Any],
    key: str,
    errors: List[str],
    *,
    minimum: int = 0,
) -> None:
    value = data.get(key)
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        errors.append(f"{key} must be an array of strings")
    elif len(value) < minimum:
        errors.append(f"{key} must contain at least {minimum} item(s)")


def validate_data(data: Dict[str, Any], allow_unverified: bool) -> Dict[str, Any]:
    errors: List[str] = []
    warnings: List[str] = []

    if data.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    if data.get("page_budget") not in (1, 2):
        errors.append("page_budget must be 1 or 2")
    if data.get("theme") not in THEMES:
        errors.append(f"theme must be one of: {', '.join(sorted(THEMES))}")
    if data.get("layout_density", "standard") not in ("compact", "standard", "relaxed"):
        errors.append("layout_density must be compact, standard, or relaxed")

    require_string(data, "name", errors)
    require_string_list(data, "titles", errors, minimum=1)
    require_string_list(data, "contact", errors, minimum=1)
    require_string(data, "summary", errors)

    evidence = data.get("evidence")
    if not isinstance(evidence, dict):
        errors.append("evidence must be an object")
        evidence_status = None
    else:
        evidence_status = evidence.get("status")
        if evidence_status not in EVIDENCE_STATUSES:
            errors.append(
                "evidence.status must be user-confirmed, source-backed, or legacy-unverified"
            )
        if evidence_status == "legacy-unverified":
            if not allow_unverified:
                errors.append(
                    "legacy-unverified data requires --allow-unverified and may only produce a draft"
                )
            else:
                warnings.append("The claim sheet is legacy-unverified; the PDF is marked DRAFT.")

    experience = data.get("experience")
    if not isinstance(experience, list) or not experience:
        errors.append("experience must be a non-empty array")
    else:
        for index, role in enumerate(experience):
            prefix = f"experience[{index}]"
            if not isinstance(role, dict):
                errors.append(f"{prefix} must be an object")
                continue
            for field in ("role", "company", "dates"):
                if not isinstance(role.get(field), str) or not role[field].strip():
                    errors.append(f"{prefix}.{field} must be a non-empty string")
            for field in ("key_metrics", "execution"):
                value = role.get(field, [])
                if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
                    errors.append(f"{prefix}.{field} must be an array of strings")

    pills = data.get("metric_pills", [])
    if not isinstance(pills, list):
        errors.append("metric_pills must be an array")
    elif len(pills) > 4:
        errors.append("metric_pills may contain at most four items")
    else:
        for index, pill in enumerate(pills):
            if not isinstance(pill, dict):
                errors.append(f"metric_pills[{index}] must be an object")
                continue
            for field in ("metric", "label"):
                if not isinstance(pill.get(field), str) or not pill[field].strip():
                    errors.append(f"metric_pills[{index}].{field} must be a non-empty string")

    for field in ("systems", "methodologies", "education", "languages"):
        value = data.get(field, [])
        if not isinstance(value, list):
            errors.append(f"{field} must be an array")
    if not isinstance(data.get("tech_stack", {}), dict):
        errors.append("tech_stack must be an object")
    require_string_list(data, "competencies", errors)

    banned_pattern = re.compile(
        r"\b(" + "|".join(re.escape(word) for word in BANNED_WORDS) + r")\w*\b",
        re.IGNORECASE,
    )
    banned_hits = sorted(
        {match.group(0) for text in iter_strings(data) for match in banned_pattern.finditer(text)}
    )
    if banned_hits:
        errors.append("banned language found: " + ", ".join(banned_hits))

    if errors:
        raise ValueError("Claim-sheet validation failed:\n- " + "\n- ".join(errors))
    return {
        "evidence_status": evidence_status,
        "draft": evidence_status == "legacy-unverified",
        "warnings": warnings,
    }


class SectionHeaderFlowable(Flowable):
    def __init__(self, title: str, theme: Dict[str, Any], width: float, compact: bool = False):
        super().__init__()
        self.title = normalize_text(title).upper()
        self.theme = theme
        self.width = width
        self.compact = compact
        self.height = 18 if compact else 19

    def wrap(self, avail_width: float, avail_height: float):
        return min(self.width, avail_width), self.height

    def draw(self) -> None:
        self.canv.saveState()
        self.canv.setFont("CVSans-Bold", 9.7 if self.compact else 10)
        self.canv.setFillColor(self.theme["accent"])
        self.canv.drawString(0, 4.9 if self.compact else 5.2, self.title)
        self.canv.setStrokeColor(self.theme["accent"])
        self.canv.setLineWidth(0.45)
        self.canv.line(0, 0, self.width, 0)
        self.canv.restoreState()


def fitted_font_size(text: str, max_width: float, font_name: str, start: float, minimum: float) -> float:
    size = start
    while size > minimum and pdfmetrics.stringWidth(text, font_name, size) > max_width:
        size -= 0.25
    return size


class JobHeaderFlowable(Flowable):
    def __init__(
        self,
        role: str,
        dates: str,
        theme: Dict[str, Any],
        width: float,
        compact: bool = False,
    ):
        super().__init__()
        self.role = normalize_text(role)
        self.dates = normalize_text(dates)
        self.theme = theme
        self.width = width
        self.compact = compact
        self.height = 14 if compact else 15

    def wrap(self, avail_width: float, avail_height: float):
        return min(self.width, avail_width), self.height

    def draw(self) -> None:
        self.canv.saveState()
        role_size = fitted_font_size(
            self.role,
            self.width * 0.72,
            "CVSans-Bold",
            9.9 if self.compact else 10.2,
            8 if self.compact else 8.2,
        )
        date_size = fitted_font_size(
            self.dates,
            self.width * 0.25,
            "CVSans",
            8.5 if self.compact else 8.8,
            7.4 if self.compact else 7.6,
        )
        self.canv.setFillColor(self.theme["ink"])
        self.canv.setFont("CVSans-Bold", role_size)
        self.canv.drawString(0, 1.9 if self.compact else 2, self.role)
        self.canv.setFillColor(self.theme["faint"])
        self.canv.setFont("CVSans", date_size)
        self.canv.drawRightString(self.width, 1.9 if self.compact else 2, self.dates)
        self.canv.restoreState()


class MetricBannerFlowable(Flowable):
    def __init__(self, pills: List[Dict[str, str]], theme: Dict[str, Any], width: float):
        super().__init__()
        self.pills = pills[:4]
        self.theme = theme
        self.width = width
        self.height = 38

    def wrap(self, avail_width: float, avail_height: float):
        return min(self.width, avail_width), self.height

    def draw(self) -> None:
        if not self.pills:
            return
        self.canv.saveState()
        cell_width = self.width / len(self.pills)
        for index, pill in enumerate(self.pills):
            x = index * cell_width
            self.canv.setFillColor(self.theme["pill_bg"])
            self.canv.setStrokeColor(self.theme["pill_border"])
            self.canv.roundRect(x + 1.5, 1.5, cell_width - 3, self.height - 3, 3, fill=1, stroke=1)
            metric = normalize_text(pill.get("metric", ""))
            label = normalize_text(pill.get("label", ""))
            metric_size = fitted_font_size(metric, cell_width - 10, "CVSans-Bold", 11.7, 8.5)
            label_size = fitted_font_size(label, cell_width - 10, "CVSans", 7, 5.8)
            self.canv.setFillColor(self.theme["accent"])
            self.canv.setFont("CVSans-Bold", metric_size)
            self.canv.drawCentredString(x + cell_width / 2, 21, metric)
            self.canv.setFillColor(self.theme["subtle"])
            self.canv.setFont("CVSans", label_size)
            self.canv.drawCentredString(x + cell_width / 2, 8, label)
        self.canv.restoreState()


class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, footer_name: str, draft: bool, **kwargs):
        kwargs.setdefault("initialFontName", "CVSans")
        kwargs.setdefault("initialFontSize", 10)
        kwargs.setdefault("initialLeading", 12)
        super().__init__(*args, **kwargs)
        self.footer_name = normalize_text(footer_name)
        self.draft = draft
        self._saved_page_states: List[Dict[str, Any]] = []

    def showPage(self) -> None:
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self) -> None:
        page_count = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_footer(page_count)
            super().showPage()
        super().save()

    def draw_footer(self, page_count: int) -> None:
        self.saveState()
        self.setFont("CVSans", 7.2)
        self.setFillColor(HexColor("#555555"))
        page_width, _ = A4
        footer = f"{self.footer_name} | Page {self._pageNumber} of {page_count}"
        if self.draft:
            footer = "DRAFT - UNVERIFIED CLAIMS | " + footer
        self.drawRightString(page_width - 15 * mm, 7 * mm, footer)
        self.restoreState()


def canvas_factory(name: str, draft: bool):
    class CVCanvas(NumberedCanvas):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, footer_name=name, draft=draft, **kwargs)

    return CVCanvas


def add_section(
    story: List[Any],
    title: str,
    blocks: List[Any],
    theme: Dict[str, Any],
    content_width: float,
    compact: bool = False,
) -> None:
    if not blocks:
        return
    first_content = getattr(blocks[0], "_content", [blocks[0]])
    first_unit = [
        SectionHeaderFlowable(title, theme, content_width, compact),
        Spacer(1, 5 if compact else 6),
    ]
    first_unit.extend(first_content)
    story.append(KeepTogether(first_unit))
    story.extend(blocks[1:])
    story.append(Spacer(1, 4 if compact else 5))


def build_pdf(data: Dict[str, Any], output_path: Path, draft: bool) -> None:
    register_fonts()
    theme = THEMES[data["theme"]]
    density = data.get("layout_density", "standard")
    compact = density == "compact"
    relaxed = density == "relaxed"
    doc = SimpleDocTemplate(
        str(output_path),
        pagesize=A4,
        leftMargin=15 * mm,
        rightMargin=15 * mm,
        topMargin=(10.5 if compact else 12 if relaxed else 11) * mm,
        bottomMargin=(12 if compact else 14 if relaxed else 13) * mm,
        allowSplitting=1,
        title=f"{normalize_text(data['name'])} - {normalize_text(data['titles'][0])} CV",
        author=normalize_text(data["name"]).title(),
        subject=f"Curriculum vitae for {normalize_text(data['titles'][0])}",
        creator="Persona Forge CV Generator",
    )
    content_width = A4[0] - (30 * mm)

    name_style = ParagraphStyle(
        "CVName",
        fontName="CVSans-Bold",
        fontSize=22 if compact else 22.5,
        leading=23.5 if compact else 24.5,
        textColor=theme["title"],
        spaceAfter=0.75 if compact else 2 if relaxed else 1,
    )
    title_style = ParagraphStyle(
        "CVTitle",
        fontName="CVSans-Bold",
        fontSize=9.8 if compact else 10,
        leading=11.6 if compact else 12.4 if relaxed else 12,
        textColor=theme["accent"],
        spaceAfter=1.5 if compact else 3 if relaxed else 2,
    )
    contact_style = ParagraphStyle(
        "CVContact",
        fontName="CVSans",
        fontSize=8 if compact else 8.2,
        leading=9.7 if compact else 10.3 if relaxed else 10,
        textColor=theme["subtle"],
        spaceAfter=4 if compact else 7 if relaxed else 5,
    )
    summary_style = ParagraphStyle(
        "CVSummary",
        fontName="CVSans",
        fontSize=9.1 if compact else 9.4,
        leading=11.8 if compact else 13 if relaxed else 12.5,
        textColor=theme["body"],
        alignment=TA_LEFT,
        spaceAfter=2.2 if compact else 4 if relaxed else 3,
    )
    company_style = ParagraphStyle(
        "CVCompany",
        fontName="CVSans-Italic",
        fontSize=8.9 if compact else 9.1,
        leading=10.8 if compact else 11.5 if relaxed else 11.2,
        textColor=theme["accent"],
        spaceAfter=1 if compact else 2 if relaxed else 1.5,
    )
    context_style = ParagraphStyle(
        "CVContext",
        fontName="CVSans",
        fontSize=9 if compact else 9.3,
        leading=11.7 if compact else 12.9 if relaxed else 12.5,
        textColor=theme["subtle"],
        alignment=TA_LEFT,
        spaceAfter=1.2 if compact else 2.2 if relaxed else 1.5,
    )
    subhead_style = ParagraphStyle(
        "CVSubhead",
        fontName="CVSans-Bold",
        fontSize=8.2 if compact else 8.4,
        leading=10 if compact else 10.6 if relaxed else 10.4,
        textColor=theme["accent"],
        spaceBefore=0.8 if compact else 1.5 if relaxed else 1,
        spaceAfter=0.4 if compact else 1 if relaxed else 0.5,
    )
    bullet_style = ParagraphStyle(
        "CVBullet",
        fontName="CVSans",
        fontSize=9 if compact else 9.3,
        leading=11.8 if compact else 13 if relaxed else 12.7,
        textColor=theme["body"],
        alignment=TA_LEFT,
        leftIndent=3.2 * mm,
        firstLineIndent=-3.2 * mm,
        spaceAfter=1.2 if compact else 2.1 if relaxed else 1.7,
    )
    text_style = ParagraphStyle(
        "CVText",
        fontName="CVSans",
        fontSize=9 if compact else 9.3,
        leading=11.7 if compact else 12.8 if relaxed else 12.5,
        textColor=theme["body"],
        alignment=TA_LEFT,
        spaceAfter=1.7 if compact else 3 if relaxed else 2.5,
    )

    story: List[Any] = []
    story.append(Paragraph(safe_text(data["name"]), name_style))
    story.append(Paragraph(safe_text(" | ".join(data["titles"])), title_style))
    story.append(Paragraph(safe_contact_line(data["contact"]), contact_style))

    pills = data.get("metric_pills", [])
    if pills:
        story.append(MetricBannerFlowable(pills, theme, content_width))
        story.append(Spacer(1, 6))

    summary = data.get("summary", "")
    if summary:
        add_section(
            story,
            "Professional Summary",
            [Paragraph(safe_text(summary), summary_style)],
            theme,
            content_width,
            compact,
        )

    experience_blocks: List[Any] = []
    for experience in data.get("experience", []):
        if experience.get("page_break_before"):
            experience_blocks.append(PageBreak())
        company = normalize_text(experience.get("company", ""))
        location = normalize_text(experience.get("location", ""))
        company_line = f"{company} | {location}" if location else company
        role_elements: List[Any] = [
            JobHeaderFlowable(
                experience.get("role", ""),
                experience.get("dates", ""),
                theme,
                content_width,
                compact,
            ),
            Paragraph(safe_text(company_line), company_style),
        ]
        if experience.get("context"):
            role_elements.append(Paragraph(safe_text(experience["context"]), context_style))
        key_metrics = list(experience.get("key_metrics", []))
        execution = list(experience.get("execution", []))

        # Keep the role identity, context, and first substantive claim together.
        # Remaining bullets may flow naturally, avoiding the large blank areas
        # caused by wrapping an entire role in KeepTogether.
        execution_heading_added = False
        if key_metrics:
            role_elements.append(Paragraph("SELECTED RESULTS", subhead_style))
            role_elements.append(
                Paragraph("-  <b>" + safe_text(key_metrics.pop(0)) + "</b>", bullet_style)
            )
        elif execution:
            role_elements.append(Paragraph("SCOPE AND EXECUTION", subhead_style))
            role_elements.append(Paragraph("-  " + safe_text(execution.pop(0)), bullet_style))
            execution_heading_added = True
        experience_blocks.append(KeepTogether(role_elements))

        for item in key_metrics:
            experience_blocks.append(Paragraph("-  <b>" + safe_text(item) + "</b>", bullet_style))
        if execution:
            if not execution_heading_added:
                experience_blocks.append(
                    KeepTogether(
                        [
                            Paragraph("SCOPE AND EXECUTION", subhead_style),
                            Paragraph("-  " + safe_text(execution.pop(0)), bullet_style),
                        ]
                    )
                )
            for item in execution:
                experience_blocks.append(Paragraph("-  " + safe_text(item), bullet_style))
        experience_blocks.append(Spacer(1, 5 if compact else 7 if relaxed else 6))
    add_section(
        story,
        "Professional Experience",
        experience_blocks,
        theme,
        content_width,
        compact,
    )

    system_blocks: List[Any] = []
    for item in data.get("systems", []):
        title = safe_text(item.get("title", ""))
        description = safe_text(item.get("description", ""))
        text = f"-  <b>{title}:</b> {description}" if title else f"-  {description}"
        system_blocks.append(Paragraph(text, bullet_style))
    add_section(
        story,
        normalize_text(data.get("systems_heading", "Selected Systems and Projects")),
        system_blocks,
        theme,
        content_width,
        compact,
    )

    methodology_blocks: List[Any] = []
    for item in data.get("methodologies", []):
        method_name = safe_text(item.get("name", ""))
        description = safe_text(item.get("description", ""))
        text = f"-  <b>{method_name}:</b> {description}" if method_name else f"-  {description}"
        methodology_blocks.append(Paragraph(text, bullet_style))
    add_section(
        story,
        normalize_text(data.get("methodologies_heading", "Methods and Frameworks")),
        methodology_blocks,
        theme,
        content_width,
        compact,
    )

    skill_blocks: List[Any] = []
    for category, tools in data.get("tech_stack", {}).items():
        tools_text = ", ".join(tools) if isinstance(tools, list) else normalize_text(tools)
        skill_blocks.append(
            Paragraph(f"<b>{safe_text(category)}:</b> {safe_text(tools_text)}", text_style)
        )
    competencies = data.get("competencies", [])
    if competencies:
        skill_blocks.append(
            Paragraph(
                "<b>Core competencies:</b> " + safe_text(" | ".join(competencies)),
                text_style,
            )
        )
    add_section(
        story,
        "Skills and Core Competencies",
        skill_blocks,
        theme,
        content_width,
        compact,
    )

    education_blocks: List[Any] = []
    for item in data.get("education", []):
        degree = safe_text(item.get("degree", ""))
        institution = safe_text(item.get("institution", ""))
        year = safe_text(item.get("year", ""))
        pieces = [piece for piece in (degree, institution, year) if piece]
        education_blocks.append(Paragraph(" | ".join(pieces), text_style))
    languages = data.get("languages", [])
    if languages:
        language_items = []
        for item in languages:
            language_name = normalize_text(item.get("name", ""))
            language_level = normalize_text(item.get("level", ""))
            if not language_name:
                continue
            language_items.append(
                f"{language_name}: {language_level}" if language_level else language_name
            )
        language_text = " | ".join(language_items)
        education_blocks.append(
            Paragraph("<b>Languages:</b> " + safe_text(language_text), text_style)
        )
    add_section(
        story,
        "Education and Languages",
        education_blocks,
        theme,
        content_width,
        compact,
    )

    doc.build(story, canvasmaker=canvas_factory(data["name"], draft))


def inspect_pdf(path: Path, page_budget: int, expected_name: str) -> Dict[str, Any]:
    reader = PdfReader(str(path))
    page_count = len(reader.pages)
    used_base_fonts = set()
    extracted_pages = []
    for page in reader.pages:
        def visit_text(text, cm, tm, font_dict, font_size):
            if text.strip() and font_dict is not None:
                used_base_fonts.add(str(font_dict.get("/BaseFont", "")))

        extracted_pages.append(page.extract_text(visitor_text=visit_text) or "")
    extracted_text = "\n".join(extracted_pages)
    controls = sorted(
        {ord(char) for char in extracted_text if (ord(char) < 32 and char not in "\n\t\f") or ord(char) == 127}
    )

    font_records: List[Dict[str, Any]] = []
    fonts_without_unicode: List[str] = []
    symbol_fonts: List[str] = []
    for page in reader.pages:
        resources = page.get("/Resources")
        if resources is None:
            continue
        resources = resources.get_object()
        fonts = resources.get("/Font")
        if fonts is None:
            continue
        fonts = fonts.get_object()
        for resource_name, font_ref in fonts.items():
            font = font_ref.get_object()
            base_font = str(font.get("/BaseFont", ""))
            has_to_unicode = "/ToUnicode" in font
            record = {
                "resource": str(resource_name),
                "base_font": base_font,
                "has_to_unicode": has_to_unicode,
                "used_for_text": base_font in used_base_fonts,
            }
            if record not in font_records:
                font_records.append(record)
            if (
                base_font in used_base_fonts
                and not has_to_unicode
                and base_font not in fonts_without_unicode
            ):
                fonts_without_unicode.append(base_font)
            if "Symbol" in base_font and base_font not in symbol_fonts:
                symbol_fonts.append(base_font)

    errors: List[str] = []
    if page_count > page_budget:
        errors.append(f"page count {page_count} exceeds page_budget {page_budget}")
    if not extracted_text.strip():
        errors.append("PDF text extraction returned no text")
    if normalize_text(expected_name).lower() not in normalize_text(extracted_text).lower():
        errors.append("candidate name is missing from extracted text")
    if controls:
        errors.append("extracted text contains control characters: " + ", ".join(map(str, controls)))
    if symbol_fonts:
        errors.append("Symbol fonts detected: " + ", ".join(symbol_fonts))
    warnings: List[str] = []
    if fonts_without_unicode:
        warnings.append(
            "font resources without ToUnicode maps detected: " + ", ".join(fonts_without_unicode)
        )
    if errors:
        raise ValueError("PDF validation failed:\n- " + "\n- ".join(errors))

    return {
        "page_count": page_count,
        "page_budget": page_budget,
        "text_characters": len(extracted_text),
        "control_characters": controls,
        "fonts": font_records,
        "symbol_fonts": symbol_fonts,
        "fonts_without_tounicode": fonts_without_unicode,
        "warnings": warnings,
    }


def write_json(path: Path, value: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build and validate an evidence-status-aware ATS-readable CV PDF"
    )
    parser.add_argument("--data", required=True, help="Path to the CV claim-sheet JSON")
    parser.add_argument("--output", required=True, help="Path for the final PDF")
    parser.add_argument("--report", help="Optional path for the validation JSON")
    parser.add_argument(
        "--allow-unverified",
        action="store_true",
        help="Allow legacy-unverified input and visibly mark the PDF as a draft",
    )
    args = parser.parse_args()

    data_path = Path(args.data).resolve()
    output_path = Path(args.output).resolve()
    report_path = Path(args.report).resolve() if args.report else output_path.with_suffix(".validation.json")
    if not data_path.exists():
        print(f"Input file not found: {data_path}", file=sys.stderr)
        return 1

    try:
        data = json.loads(data_path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("The claim sheet must be a JSON object.")
        validation = validate_data(data, args.allow_unverified)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        temporary_path = output_path.with_suffix(output_path.suffix + ".tmp")
        if temporary_path.exists():
            temporary_path.unlink()
        build_pdf(data, temporary_path, validation["draft"])
        pdf_checks = inspect_pdf(temporary_path, data["page_budget"], data["name"])
        os.replace(temporary_path, output_path)
        report = {
            "schema": "persona-forge.cv-validation/v1",
            "input": str(data_path),
            "output": str(output_path),
            "evidence_status": validation["evidence_status"],
            "draft": validation["draft"],
            "warnings": validation["warnings"],
            "checks": pdf_checks,
            "visual_review": {
                "status": "required",
                "note": "Render every page to PNG and inspect before delivery.",
            },
        }
        write_json(report_path, report)
        print(
            f"Generated {output_path} ({pdf_checks['page_count']} page(s), "
            f"budget {pdf_checks['page_budget']}, evidence {validation['evidence_status']})."
        )
        print(f"Validation report: {report_path}")
        return 0
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        temporary_path = output_path.with_suffix(output_path.suffix + ".tmp")
        if temporary_path.exists():
            temporary_path.unlink()
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
