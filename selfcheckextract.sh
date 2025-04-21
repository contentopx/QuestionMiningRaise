#!/bin/bash
# 🧠 Shell script to export Self Check data with full page HTML in 'question stem' column

echo "🚀 Extracting Self Checks: full HTML in 'question stem' column..."

python3 - <<EOF
import os
import re
import csv
import html
import chardet
import pandas as pd
from bs4 import BeautifulSoup
import xml.etree.ElementTree as ET

# === Config ===
ROOT_DIR = "/Users/rs162/Documents/OPX/k12-contents-raise"
TOC_PATH = os.path.join(ROOT_DIR, "toc.md")
HTML_DIR = os.path.join(ROOT_DIR, "html")
XML_DIR = os.path.join(ROOT_DIR, "mbz/activities")
CSV_OUT = os.path.join(ROOT_DIR, "selfcheck_fullpage_in_stem.csv")

def extract_selfcheck_links(toc_file):
    entries = []
    with open(toc_file, "r") as file:
        for line in file:
            match = re.search(r'\[([0-9.]+): Self Check.*\]\(\.\/html\/([a-f0-9\-]+)\.html\)', line)
            if match:
                section, uuid = match.groups()
                entries.append((section.strip(), uuid.strip()))
    return entries

def detect_encoding_and_read(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return f.read()
    except UnicodeDecodeError:
        with open(path, 'rb') as f:
            raw = f.read(100000)
            detected = chardet.detect(raw)
            encoding = detected['encoding'] if detected['encoding'] else 'utf-8'
        with open(path, 'r', encoding=encoding, errors='ignore') as f:
            return f.read()

def extract_full_html(uuid):
    filename = f"{uuid}.html"
    path = os.path.join(HTML_DIR, filename)
    
    # Validate it's a legit HTML file
    if not os.path.exists(path) or not filename.endswith(".html"):
        return f"<!-- Missing HTML file for UUID: {uuid} -->"
    
    html_content = detect_encoding_and_read(path)
    return html_content.lstrip()  # Strip leading whitespace only

def extract_answers_from_xml(uuid):
    for root, _, files in os.walk(XML_DIR):
        for fname in files:
            if fname == "lesson.xml":
                path = os.path.join(root, fname)
                xml_content = detect_encoding_and_read(path)
                if uuid in xml_content:
                    tree = ET.ElementTree(ET.fromstring(xml_content))
                    for page in tree.findall(".//page"):
                        if uuid in html.unescape(page.findtext("contents", "")):
                            return parse_answers(page, uuid)
    return None

def parse_answers(page, uuid):
    answers, feedbacks, correct = {}, {}, ""
    letters = ['A', 'B', 'C', 'D']
    for i, ans in enumerate(page.findall(".//answer")):
        if i >= 4: break
        score = ans.findtext("score", "0")
        ans_text = html.unescape(ans.findtext("answer_text", ""))
        response = html.unescape(ans.findtext("response", ""))
        text = BeautifulSoup(ans_text, "html.parser").decode_contents()
        fb = BeautifulSoup(response, "html.parser").decode_contents()
        label = letters[i]
        answers[label] = text
        feedbacks[label] = fb
        if score == "1":
            correct = label
    return answers, feedbacks, correct, uuid

def normalize_math_symbols(text):
    if pd.isna(text):
        return ""
    text = str(text)
    replacements = {
        "‚â•": r"\ge", "‚â§": r"\le",
        "≥": r"\ge", "≤": r"\le",
        "−": "-", "–": "-", "—": "-",
        "“": '"', "”": '"', "‘": "'", "’": "'",
        "\xa0": " ", "\u200b": "", "\ufeff": ""
    }
    for wrong, right in replacements.items():
        text = text.replace(wrong, right)
    return text.strip()

def run():
    toc = extract_selfcheck_links(TOC_PATH)
    with open(CSV_OUT, "w", newline='', encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "question stem",  # Now holds full HTML of Self Check page
            "option A", "option B", "option C", "option D",
            "option A feedback", "option B feedback", "option C feedback", "option D feedback",
            "correct answer", "data content ID", "question nickname"
        ])
        for section, uuid in toc:
            full_html = extract_full_html(uuid)
            result = extract_answers_from_xml(uuid)
            if result:
                answers, feedbacks, correct, content_id = result
                row = [full_html]
                for label in ['A', 'B', 'C', 'D']:
                    row.append(normalize_math_symbols(answers.get(label, "")))
                for label in ['A', 'B', 'C', 'D']:
                    row.append(normalize_math_symbols(feedbacks.get(label, "")))
                row += [correct, content_id, f"Alg1_{section.replace('.', '_')}_SC"]
            else:
                row = [full_html] + [""] * 11 + [f"Alg1_{section.replace('.', '_')}_SC"]
            writer.writerow(row)
    print(f"✅ Export complete! File saved to: {CSV_OUT}")

run()
EOF
