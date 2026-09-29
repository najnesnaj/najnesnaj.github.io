#!/usr/bin/env python3
"""Build a PowerPoint presentation for a non-technical audience
explaining the Nextcloud + Euro-Office air-gapped solution."""

from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
import os

IMG_DIR = os.path.dirname(os.path.abspath(__file__))

# Colour palette
BLUE_DARK   = RGBColor(0x00, 0x2B, 0x5C)
BLUE_MED    = RGBColor(0x00, 0x54, 0xA6)
BLUE_LIGHT  = RGBColor(0xD6, 0xEA, 0xF8)
GREEN       = RGBColor(0x1E, 0x8E, 0x49)
RED         = RGBColor(0xC0, 0x39, 0x2B)
ORANGE      = RGBColor(0xE6, 0x7E, 0x22)
WHITE       = RGBColor(0xFF, 0xFF, 0xFF)
BLACK       = RGBColor(0x00, 0x00, 0x00)
GREY_LIGHT  = RGBColor(0xF2, 0xF2, 0xF2)
GREY_MED    = RGBColor(0x7F, 0x8C, 0x8D)

prs = Presentation()
prs.slide_width  = Inches(13.333)
prs.slide_height = Inches(7.5)

SLIDE_W = prs.slide_width
SLIDE_H = prs.slide_height


def add_bg(slide, color):
    """Fill the slide background with a solid colour."""
    bg = slide.background
    fill = bg.fill
    fill.solid()
    fill.fore_color.rgb = color


def add_rect(slide, left, top, width, height, color, alpha=None):
    shape = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, left, top, width, height)
    shape.fill.solid()
    shape.fill.fore_color.rgb = color
    shape.line.fill.background()
    return shape


def add_textbox(slide, left, top, width, height, text, font_size=18,
                bold=False, color=BLACK, alignment=PP_ALIGN.LEFT,
                font_name="Calibri"):
    txBox = slide.shapes.add_textbox(left, top, width, height)
    tf = txBox.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = text
    p.font.size = Pt(font_size)
    p.font.bold = bold
    p.font.color.rgb = color
    p.font.name = font_name
    p.alignment = alignment
    return txBox


def add_bullet_list(slide, left, top, width, height, items,
                    font_size=18, color=BLACK, bold_first=False,
                    spacing=Pt(6), font_name="Calibri"):
    txBox = slide.shapes.add_textbox(left, top, width, height)
    tf = txBox.text_frame
    tf.word_wrap = True
    for i, item in enumerate(items):
        if i == 0:
            p = tf.paragraphs[0]
        else:
            p = tf.add_paragraph()
        p.text = item
        p.font.size = Pt(font_size)
        p.font.color.rgb = color
        p.font.name = font_name
        p.space_after = spacing
        p.level = 0
        # bullet character
        pPr = p._pPr
        from pptx.oxml.ns import qn
        buNone = pPr.findall(qn('a:buNone'))
        for bn in buNone:
            pPr.remove(bn)
        buChar = pPr.makeelement(qn('a:buChar'), {'char': '\u2022'})
        pPr.append(buChar)
        buClr = pPr.makeelement(qn('a:buClr'), {})
        srgb = buClr.makeelement(qn('a:srgbClr'), {'val': color.hex if hasattr(color, 'hex') else '000000'})
        buClr.append(srgb)
        pPr.append(buClr)
    return txBox


def add_colored_bullets(slide, left, top, width, height, items, font_size=18,
                        icon_color=GREEN, font_name="Calibri"):
    """items = list of (bullet_text, is_positive)"""
    txBox = slide.shapes.add_textbox(left, top, width, height)
    tf = txBox.text_frame
    tf.word_wrap = True
    for i, (text, positive) in enumerate(items):
        if i == 0:
            p = tf.paragraphs[0]
        else:
            p = tf.add_paragraph()
        icon = "+" if positive else "-"
        p.text = f"{icon}  {text}"
        p.font.size = Pt(font_size)
        p.font.color.rgb = GREEN if positive else RED
        p.font.name = font_name
        p.space_after = Pt(6)
    return txBox


def add_image_fit(slide, img_path, left, top, max_w, max_h):
    """Add an image scaled to fit within max_w x max_h."""
    from PIL import Image
    img = Image.open(img_path)
    iw, ih = img.size
    ratio = min(max_w / iw, max_h / ih)
    w = int(iw * ratio)
    h = int(ih * ratio)
    # center horizontally
    cx = left + (max_w - w) // 2
    cy = top + (max_h - h) // 2
    slide.shapes.add_picture(img_path, cx, cy, w, h)


# ── Slide 1: Title ──────────────────────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])  # blank
add_bg(slide, BLUE_DARK)
add_rect(slide, 0, 0, SLIDE_W, Inches(0.15), BLUE_MED)

add_textbox(slide, Inches(1), Inches(1.8), Inches(11), Inches(1.5),
            "Nextcloud + Euro-Office",
            font_size=44, bold=True, color=WHITE, alignment=PP_ALIGN.CENTER)
add_textbox(slide, Inches(1), Inches(3.3), Inches(11), Inches(1),
            "A Secure, Air-Gapped Office & File Sharing Solution",
            font_size=26, color=RGBColor(0xBB, 0xDE, 0xFB), alignment=PP_ALIGN.CENTER)
add_textbox(slide, Inches(1), Inches(5.5), Inches(11), Inches(0.8),
            "Designed for organisations that need full control over their data\nwithout relying on the internet",
            font_size=16, color=GREY_MED, alignment=PP_ALIGN.CENTER)

# ── Slide 2: The Challenge ──────────────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_rect(slide, 0, 0, SLIDE_W, Inches(1.1), BLUE_DARK)
add_textbox(slide, Inches(0.6), Inches(0.2), Inches(12), Inches(0.7),
            "The Challenge", font_size=32, bold=True, color=WHITE)

items = [
    "Many organisations need to share files and edit documents collaboratively",
    "Cloud services (Google Workspace, Microsoft 365) require an internet connection and send data to external servers",
    "Government agencies, defence, healthcare and other sectors often operate on networks with no internet access (air-gapped)",
    "They still need the same productivity tools: file sync, calendar, contacts, document editing",
    "Existing solutions may carry security risks, licensing costs or vendor lock-in"
]
add_bullet_list(slide, Inches(0.8), Inches(1.5), Inches(11.5), Inches(5.5),
                items, font_size=20)

# ── Slide 3: What is Nextcloud? ─────────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_rect(slide, 0, 0, SLIDE_W, Inches(1.1), BLUE_DARK)
add_textbox(slide, Inches(0.6), Inches(0.2), Inches(12), Inches(0.7),
            "What is Nextcloud?", font_size=32, bold=True, color=WHITE)

left_items = [
    "A self-hosted platform for file sharing and collaboration",
    "Dropbox/Google Drive replacement you control completely",
    "Features: files, calendar, contacts, email, chat, video calls",
    "Runs on your own hardware - your data never leaves your network",
    "Open source - free to use, no per-user licensing fees",
    "Large ecosystem of apps and integrations"
]
add_bullet_list(slide, Inches(0.8), Inches(1.5), Inches(6.5), Inches(5.5),
                left_items, font_size=18)

# Add the Nextcloud admin login screenshot
img_path = os.path.join(IMG_DIR, "nextcloud-local-admin-login.png")
if os.path.exists(img_path):
    add_image_fit(slide, img_path, Inches(7.8), Inches(1.3), Inches(5), Inches(5.5))

# ── Slide 4: What is Euro-Office? ───────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_rect(slide, 0, 0, SLIDE_W, Inches(1.1), BLUE_DARK)
add_textbox(slide, Inches(0.6), Inches(0.2), Inches(12), Inches(0.7),
            "What is Euro-Office?", font_size=32, bold=True, color=WHITE)

left_items = [
    "An office document suite designed for government agencies",
    "Real-time collaborative editing of documents, spreadsheets and presentations",
    "Stripped of external connections and telemetry - safe for classified networks",
    "Integrates directly into Nextcloud for seamless workflow",
    "Supports common formats: .docx, .xlsx, .pptx, .odt and more",
    "Self-hosted - no data leaves your infrastructure"
]
add_bullet_list(slide, Inches(0.8), Inches(1.5), Inches(6.5), Inches(5.5),
                left_items, font_size=18)

img_path = os.path.join(IMG_DIR, "example-euro-office.png")
if os.path.exists(img_path):
    add_image_fit(slide, img_path, Inches(7.8), Inches(1.3), Inches(5), Inches(5.5))

# ── Slide 5: How They Work Together ────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_rect(slide, 0, 0, SLIDE_W, Inches(1.1), BLUE_DARK)
add_textbox(slide, Inches(0.6), Inches(0.2), Inches(12), Inches(0.7),
            "How They Work Together", font_size=32, bold=True, color=WHITE)

items = [
    "Nextcloud provides the file storage, sharing, and user management",
    "Euro-Office provides the document editing and collaboration engine",
    "Users open a document in Nextcloud and it opens in Euro-Office automatically",
    "Multiple people can edit the same document in real time",
    "Changes are saved directly back to Nextcloud - no separate step needed",
    "All running on your own servers, on your own network"
]
add_bullet_list(slide, Inches(0.8), Inches(1.5), Inches(7), Inches(5.5),
                items, font_size=18)

# Architecture diagram
img_path = os.path.join(IMG_DIR, "overview-containers-nextcloud.png")
if os.path.exists(img_path):
    add_image_fit(slide, img_path, Inches(8.2), Inches(1.3), Inches(4.5), Inches(5.5))

# ── Slide 6: Document Formats ───────────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_rect(slide, 0, 0, SLIDE_W, Inches(1.1), BLUE_DARK)
add_textbox(slide, Inches(0.6), Inches(0.2), Inches(12), Inches(0.7),
            "Supported Document Formats", font_size=32, bold=True, color=WHITE)

left_items = [
    "Word processing: .docx, .odt, .txt",
    "Spreadsheets: .xlsx, .ods, .csv",
    "Presentations: .pptx, .odp",
    "PDF viewing and editing",
    "Import and export from Microsoft Office formats",
    "Collaborative editing with change tracking"
]
add_bullet_list(slide, Inches(0.8), Inches(1.5), Inches(6.5), Inches(5.5),
                left_items, font_size=18)

img_path = os.path.join(IMG_DIR, "document-formats.png")
if os.path.exists(img_path):
    add_image_fit(slide, img_path, Inches(7.8), Inches(1.3), Inches(5), Inches(5.5))

# ── Slide 7: Running Containers ─────────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_rect(slide, 0, 0, SLIDE_W, Inches(1.1), BLUE_DARK)
add_textbox(slide, Inches(0.6), Inches(0.2), Inches(12), Inches(0.7),
            "The System in Action", font_size=32, bold=True, color=WHITE)

items = [
    "Everything runs in isolated containers - like lightweight virtual machines",
    "Containers include: Nextcloud, Euro-Office document server, database, cache, and web server",
    "Managed through a single control panel (AIO - All-in-One)",
    "Automatic restart on system reboot",
    "Can also run on Kubernetes for larger deployments"
]
add_bullet_list(slide, Inches(0.8), Inches(1.5), Inches(7), Inches(5.5),
                items, font_size=18)

img_path = os.path.join(IMG_DIR, "running-container-euro-office.png")
if os.path.exists(img_path):
    add_image_fit(slide, img_path, Inches(8.2), Inches(1.3), Inches(4.5), Inches(5.5))

# ── Slide 8: AI Features ────────────────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_rect(slide, 0, 0, SLIDE_W, Inches(1.1), BLUE_DARK)
add_textbox(slide, Inches(0.6), Inches(0.2), Inches(12), Inches(0.7),
            "Built-in AI Integration", font_size=32, bold=True, color=WHITE)

items = [
    "Euro-Office supports configurable AI models for document assistance",
    "AI runs locally - no data is sent to external cloud AI services",
    "Models can be added and configured through the admin interface",
    "Suitable for organisations exploring AI-assisted document workflows",
    "Can be fully disabled if AI features are not desired"
]
add_bullet_list(slide, Inches(0.8), Inches(1.5), Inches(7), Inches(5.5),
                items, font_size=18)

img_path = os.path.join(IMG_DIR, "euro-office-AI-config.png")
if os.path.exists(img_path):
    add_image_fit(slide, img_path, Inches(8.2), Inches(1.3), Inches(4.5), Inches(5.5))

# ── Slide 9: Deployment Options ─────────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_rect(slide, 0, 0, SLIDE_W, Inches(1.1), BLUE_DARK)
add_textbox(slide, Inches(0.6), Inches(0.2), Inches(12), Inches(0.7),
            "Deployment Options", font_size=32, bold=True, color=WHITE)

# Option A
add_rect(slide, Inches(0.6), Inches(1.5), Inches(5.8), Inches(5.2), GREY_LIGHT)
add_textbox(slide, Inches(0.8), Inches(1.6), Inches(5.4), Inches(0.6),
            "Option A: Single Server (Podman)", font_size=22, bold=True, color=BLUE_MED)
items_a = [
    "Runs on a single Linux computer",
    "Uses Podman (a secure container engine)",
    "Quick to set up - about 1-2 hours",
    "Ideal for small teams (up to ~50 users)",
    "No special hardware required",
    "Backup with standard tools"
]
add_bullet_list(slide, Inches(0.8), Inches(2.3), Inches(5.4), Inches(4.2),
                items_a, font_size=16)

# Option B
add_rect(slide, Inches(6.9), Inches(1.5), Inches(5.8), Inches(5.2), GREY_LIGHT)
add_textbox(slide, Inches(7.1), Inches(1.6), Inches(5.4), Inches(0.6),
            "Option B: Cluster (Kubernetes)", font_size=22, bold=True, color=BLUE_MED)
items_b = [
    "Runs on multiple servers (cluster)",
    "Uses Kubernetes for management",
    "Scales to hundreds of users",
    "Higher availability and fault tolerance",
    "Requires more infrastructure",
    "More complex to set up and maintain"
]
add_bullet_list(slide, Inches(7.1), Inches(2.3), Inches(5.4), Inches(4.2),
                items_b, font_size=16)

# ── Slide 10: Advantages ────────────────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_rect(slide, 0, 0, SLIDE_W, Inches(1.1), GREEN)
add_textbox(slide, Inches(0.6), Inches(0.2), Inches(12), Inches(0.7),
            "Advantages", font_size=32, bold=True, color=WHITE)

advantages = [
    ("Complete data sovereignty - your data never leaves your premises", True),
    ("No internet dependency - works fully offline (air-gapped)", True),
    ("Free and open source - no licensing fees or vendor lock-in", True),
    ("Secure by design - rootless containers, no central server daemon", True),
    ("Government-grade compliance (FedRAMP, NIST, SOC 2 aligned)", True),
    ("Real-time document collaboration like Google Docs / Office 365", True),
    ("Runs on standard Linux hardware - no special equipment needed", True),
    ("Full ecosystem: file sync, calendar, contacts, chat, video calls", True),
    ("Easy to maintain with automated container management", True),
    ("Can start small and scale to a Kubernetes cluster later", True),
]
add_colored_bullets(slide, Inches(0.8), Inches(1.4), Inches(11.5), Inches(5.8),
                    advantages, font_size=17)

# ── Slide 11: Disadvantages ─────────────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_rect(slide, 0, 0, SLIDE_W, Inches(1.1), RED)
add_textbox(slide, Inches(0.6), Inches(0.2), Inches(12), Inches(0.7),
            "Disadvantages", font_size=32, bold=True, color=WHITE)

disadvantages = [
    ("Requires Linux system administration knowledge to install and maintain", False),
    ("Initial setup involves several technical steps and configuration fixes", False),
    ("Self-signed security certificates cause browser warnings (must be accepted)", False),
    ("Some mobile apps may not work with self-signed certificates", False),
    ("Not officially supported by Nextcloud AIO when using Podman (community guide)", False),
    ("Certain features like automatic backups need manual configuration", False),
    ("Updates require manual intervention - not fully automatic", False),
    ("Kubernetes deployment is significantly more complex to set up", False),
    ("No commercial support - relies on community and open-source documentation", False),
    ("Euro-Office is less feature-rich than Microsoft 365 or Google Workspace", False),
]
add_colored_bullets(slide, Inches(0.8), Inches(1.4), Inches(11.5), Inches(5.8),
                    disadvantages, font_size=17)

# ── Slide 12: Security Comparison ──────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_rect(slide, 0, 0, SLIDE_W, Inches(1.1), BLUE_DARK)
add_textbox(slide, Inches(0.6), Inches(0.2), Inches(12), Inches(0.7),
            "Why Podman Over Docker?", font_size=32, bold=True, color=WHITE)

# Table header
tbl_left = Inches(0.8)
tbl_top = Inches(1.5)
rows, cols = 6, 3
shape = slide.shapes.add_table(rows, cols, tbl_left, tbl_top, Inches(11.5), Inches(5))
table = shape.table

# Header row
headers = ["Feature", "Docker", "Podman"]
for i, h in enumerate(headers):
    cell = table.cell(0, i)
    cell.text = h
    for paragraph in cell.text_frame.paragraphs:
        paragraph.font.size = Pt(16)
        paragraph.font.bold = True
        paragraph.font.color.rgb = WHITE
    cell.fill.solid()
    cell.fill.fore_color.rgb = BLUE_DARK

data = [
    ("Architecture", "Central daemon (single point of failure)", "Daemonless (each container is isolated)"),
    ("Default privilege", "Requires root access", "Runs rootless by default"),
    ("Licensing", "Paid for large organisations", "Free and open source (Apache 2.0)"),
    ("Government Linux", "Deprecated by Red Hat", "Default engine in RHEL 8+"),
    ("Audit trail", "Actions hidden behind daemon", "Direct user ID tracking"),
]
for r, (feat, docker, podman) in enumerate(data, start=1):
    for c, val in enumerate([feat, docker, podman]):
        cell = table.cell(r, c)
        cell.text = val
        for paragraph in cell.text_frame.paragraphs:
            paragraph.font.size = Pt(14)
            paragraph.font.color.rgb = BLACK
        if r % 2 == 0:
            cell.fill.solid()
            cell.fill.fore_color.rgb = GREY_LIGHT

# ── Slide 13: Real-World Usage ─────────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_rect(slide, 0, 0, SLIDE_W, Inches(1.1), BLUE_DARK)
add_textbox(slide, Inches(0.6), Inches(0.2), Inches(12), Inches(0.7),
            "Who Benefits from This Solution?", font_size=32, bold=True, color=WHITE)

items = [
    "Government agencies handling classified or sensitive information",
    "Healthcare organisations subject to patient data regulations (GDPR, HIPAA)",
    "Defence and military networks with no internet connectivity",
    "Education institutions wanting to keep student data in-house",
    "Any organisation that wants to own and control its own IT infrastructure",
    "Teams that need Microsoft Office-like functionality without Microsoft licensing costs"
]
add_bullet_list(slide, Inches(0.8), Inches(1.5), Inches(11.5), Inches(5.5),
                items, font_size=20)

# ── Slide 14: Summary ──────────────────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, BLUE_DARK)
add_rect(slide, 0, 0, SLIDE_W, Inches(0.15), BLUE_MED)

add_textbox(slide, Inches(1), Inches(1.2), Inches(11), Inches(1),
            "Summary", font_size=36, bold=True, color=WHITE, alignment=PP_ALIGN.CENTER)

summary_items = [
    "Nextcloud + Euro-Office provides a complete, self-hosted office suite",
    "Your data stays on your network - no internet connection required",
    "Secure, compliant, and free from vendor lock-in",
    "Runs on affordable Linux hardware using modern container technology",
    "Suitable for organisations of all sizes, from small teams to large agencies",
]
add_bullet_list(slide, Inches(1.5), Inches(2.5), Inches(10), Inches(4),
                summary_items, font_size=20, color=WHITE)

# ── Slide 15: Thank You ────────────────────────────────────────────────────
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, BLUE_DARK)
add_rect(slide, 0, 0, SLIDE_W, Inches(0.15), BLUE_MED)

add_textbox(slide, Inches(1), Inches(2.5), Inches(11), Inches(1.2),
            "Thank You", font_size=44, bold=True, color=WHITE, alignment=PP_ALIGN.CENTER)
add_textbox(slide, Inches(1), Inches(4), Inches(11), Inches(1),
            "Questions?", font_size=28, color=RGBColor(0xBB, 0xDE, 0xFB), alignment=PP_ALIGN.CENTER)
add_textbox(slide, Inches(1), Inches(5.5), Inches(11), Inches(0.8),
            "Documentation: najnesnaj.github.io",
            font_size=16, color=GREY_MED, alignment=PP_ALIGN.CENTER)

# Save
output_path = os.path.join(IMG_DIR, "Nextcloud_Euro-Office_Presentation.pptx")
prs.save(output_path)
print(f"Presentation saved to: {output_path}")
