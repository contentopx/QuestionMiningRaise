#!/bin/bash
# Shell script that runs embedded Python to extract ALL Self Check questions

echo "🧠 Running Python script to extract ALL Self Check questions..."

python3 - <<EOF
import os
import re
import csv
import html
import pandas as pd
from bs4 import BeautifulSoup
import xml.etree.ElementTree as ET

# === Config ===
ROOT_DIR = "/Users/rs162/Documents/OPX/k12-contents-raise"
TOC_PATH = os.path.join(ROOT_DIR, "toc.md")
HTML_DIR = os.path.join(ROOT_DIR, "html")
XML_DIR = os.path.join(ROOT_DIR, "mbz/activities")
CSV_OUT = os.path.join(ROOT_DIR, "selfcheck_all.csv")

def extract_selfcheck_links(toc_file):
    entries = []
    with open(toc_file, "r") as file:
        for line in file:
            match = re.search(r'\[([0-9.]+): Self Check.*\]\(\.\/html\/([a-f0-9\-]+)\.html\)', line)
            if match:
                section, uuid = match.groups()
                entries.append((section.strip(), uuid.strip()))
    return entries

def extract_stem(uuid):
    path = os.path.join(HTML_DIR, f"{uuid}.html")
    if not os.path.exists(path):
        return "(No question stem found)"
    with open(path, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")
        return soup.get_text(strip=True)

def extract_answers_from_xml(uuid):
    for root, _, files in os.walk(XML_DIR):
        for fname in files:
            if fname == "lesson.xml":
                path = os.path.join(root, fname)
                with open(path, "r", encoding="utf-8") as f:
                    xml = f.read()
                    if uuid in xml:
                        tree = ET.ElementTree(ET.fromstring(xml))
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
        text = BeautifulSoup(ans_text, "html.parser").get_text(strip=True)
        fb = BeautifulSoup(response, "html.parser").get_text(strip=True)
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
            "question stem", "option A", "option B", "option C", "option D",
            "option A feedback", "option B feedback", "option C feedback", "option D feedback",
            "correct answer", "data content ID", "question nickname"
        ])
        for section, uuid in toc:
            stem = extract_stem(uuid)
            result = extract_answers_from_xml(uuid)
            if result:
                answers, feedbacks, correct, content_id = result
                row = [stem]
                for label in ['A', 'B', 'C', 'D']:
                    row.append(normalize_math_symbols(answers.get(label, "")))
                for label in ['A', 'B', 'C', 'D']:
                    row.append(normalize_math_symbols(feedbacks.get(label, "")))
                row += [correct, content_id, f"Alg1_{section.replace('.', '_')}_SC"]
            else:
                row = [stem] + [""] * 11 + [f"Alg1_{section.replace('.', '_')}_SC"]
            writer.writerow(row)
    print(f"✅ Done! Output saved to: {CSV_OUT}")

run()
EOF
