# QuestionMiningRaise

# 🧠 Self Check Extractor for RAISE Curriculum 

This script extracts **Self Check questions** from the [RAISE Math K–12 curriculum](https://www.raise.education), including:

It normalizes corrupted characters (e.g. `≥`, `≤`, `−`) to clean LaTeX-style MathJax syntax, ensuring compatibility with rendering engines and CSV tools.

## 🛠️ How It Works

The script:

1. Parses `toc.md` to identify all "Self Check" questions
2. Extracts question stems from individual HTML files
3. Extracts answers and feedback from associated `lesson.xml` files
4. Cleans corrupted symbols and exports a structured CSV

---

## 🧪 Output

The final CSV (`selfcheck_all.csv`) includes:

| Column               | Description                              |
|----------------------|------------------------------------------|
| `question stem`      | Full text of the question                |
| `option A` to `D`    | Multiple choice answers                  |
| `option A–D feedback`| Individual answer feedback               |
| `correct answer`     | Correct answer label (A, B, C, D)        |
| `data content ID`    | UUID from content div                    |
| `question nickname`  | Friendly ID e.g. `Alg1_1_1_2_SC`         |
