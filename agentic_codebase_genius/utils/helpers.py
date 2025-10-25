# --- agentic_codebase_genius/utils/helpers.py ---

import os
import json
import shutil
import subprocess
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv
from pymongo import MongoClient
import git
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders

# Optional: Gemini SDK
try:
    import google.generativeai as genai
except ImportError:
    genai = None
    print("⚠️ google-generativeai not installed. Gemini features disabled.")

# -------------------------------------------------
# Load environment variables
# -------------------------------------------------
load_dotenv()


# -------------------------------------------------
# MongoDB utilities
# -------------------------------------------------
def get_mongo_client():
    uri = os.getenv("MONGO_DB_URI")
    if not uri:
        print("⚠️ Missing MONGO_DB_URI in .env")
        return None
    return MongoClient(uri, serverSelectionTimeoutMS=5000)


def save_document(collection, data):
    client = get_mongo_client()
    if not client:
        return False
    db = client["codebase_genius"]
    col = db[collection]
    col.insert_one(data)
    client.close()
    return True


def fetch_documents(collection, query=None):
    client = get_mongo_client()
    if not client:
        return []
    db = client["codebase_genius"]
    col = db[collection]
    results = list(col.find(query or {}))
    client.close()
    return results


# -------------------------------------------------
# Repository utilities
# -------------------------------------------------
def clone_repo(url, dest_base="outputs"):
    """Clone a GitHub repository locally."""
    dest_base = Path(dest_base)
    dest_base.mkdir(parents=True, exist_ok=True)
    repo_name = url.split("/")[-1].replace(".git", "")
    repo_path = dest_base / repo_name / "repo"

    if repo_path.exists():
        shutil.rmtree(repo_path)

    git.Repo.clone_from(url, repo_path)
    return str(repo_path)


def build_file_tree(repo_path):
    """Traverse repo and build a JSON-friendly file structure."""
    repo_path = Path(repo_path)
    tree = {}
    for root, dirs, files in os.walk(repo_path):
        dirs[:] = [d for d in dirs if d not in [".git", "node_modules", "__pycache__"]]
        rel = os.path.relpath(root, repo_path)
        tree[rel] = sorted(files)
    return tree


def read_readme(repo_path):
    """Return README content if found."""
    for candidate in ["README.md", "README.rst", "README"]:
        p = Path(repo_path) / candidate
        if p.exists():
            return p.read_text(encoding="utf-8")
    return ""


# -------------------------------------------------
# Simple Python file parser
# -------------------------------------------------
def parse_python_files(repo_path):
    """Extract top-level function/class names (naive parser)."""
    results = []
    for root, _, files in os.walk(repo_path):
        for fn in files:
            if fn.endswith(".py"):
                path = Path(root) / fn
                text = path.read_text(encoding="utf-8", errors="ignore")
                funcs, classes = [], []
                for line in text.splitlines():
                    s = line.strip()
                    if s.startswith("def "):
                        funcs.append(s.split("(")[0].replace("def ", "").strip())
                    elif s.startswith("class "):
                        classes.append(s.split("(")[0].replace("class ", "").strip(": "))
                results.append({"file": str(path), "functions": funcs, "classes": classes})
    return results


# -------------------------------------------------
# Graphviz diagram generation
# -------------------------------------------------
def generate_function_graph(repo_name, analysis_data, out_dir="outputs"):
    """Generate a simple function graph using Graphviz (optional)."""
    out_dir = Path(out_dir) / repo_name
    out_dir.mkdir(parents=True, exist_ok=True)
    dot_path = out_dir / "ccg.dot"
    png_path = out_dir / "ccg.png"

    with dot_path.open("w", encoding="utf-8") as f:
        f.write("digraph CCG {\n")
        for fileinfo in analysis_data:
            for fn in fileinfo.get("functions", []):
                f.write(f'  "{fn}" [shape=ellipse];\n')
        f.write("}\n")

    try:
        subprocess.run(["dot", "-Tpng", str(dot_path), "-o", str(png_path)], check=True)
        return str(png_path)
    except Exception:
        return str(dot_path)


# -------------------------------------------------
# Markdown documentation generator
# -------------------------------------------------
def generate_markdown(repo_name, repo_maps, analysis_data, out_dir="outputs"):
    """Generate Markdown documentation for the analyzed repo."""
    out_dir = Path(out_dir) / repo_name
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / "docs.md"

    content = f"# {repo_name} Documentation\n\n"
    content += "## Repository Overview\n\n"
    content += "### File Tree\n```\n"

    try:
        content += json.dumps(repo_maps, indent=2)[:5000]
    except Exception:
        content += str(repo_maps)[:5000]

    content += "\n```\n\n## Code Analysis Summary\n"
    for item in analysis_data:
        content += f"### {item.get('file')}\n"
        content += f"- Functions: {', '.join(item.get('functions', []))}\n"
        content += f"- Classes: {', '.join(item.get('classes', []))}\n\n"

    graph_path = generate_function_graph(repo_name, analysis_data, out_dir=out_dir.parent)
    content += f"## Diagrams\n\nCCG diagram located at `{graph_path}`\n"

    out_file.write_text(content, encoding="utf-8")
    return str(out_file)


# -------------------------------------------------
# Gemini Integration (Optional)
# -------------------------------------------------
def init_gemini():
    if not genai:
        raise ImportError("google-generativeai not installed.")
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("Missing GEMINI_API_KEY in .env")
    genai.configure(api_key=api_key)
    return genai.GenerativeModel("gemini-1.5-flash")


def summarize_readme_with_gemini(readme_text, repo_name):
    """Generate concise README summary using Gemini."""
    model = init_gemini()
    prompt = (
        f"Summarize the README of repository '{repo_name}' in Markdown format.\n"
        f"Include purpose, features, setup, and usage.\n\n{readme_text}"
    )
    result = model.generate_content(prompt)
    return getattr(result, "text", "").strip()


def explain_code_module_with_gemini(file_content, filename):
    """Explain a single Python file using Gemini."""
    model = init_gemini()
    prompt = (
        f"You are Codebase Genius. Explain the file '{filename}' concisely.\n"
        f"Highlight key classes and functions.\n\n{file_content[:3000]}"
    )
    result = model.generate_content(prompt)
    return getattr(result, "text", "").strip()


def synthesize_final_doc_with_gemini(repo_name, repo_summary, analysis_text):
    """Synthesize final Markdown doc from previous summaries."""
    model = init_gemini()
    prompt = f"""
Create a clean Markdown documentation for '{repo_name}' using the information below:

Repository Summary:
{repo_summary}

Code Analysis:
{analysis_text}
"""
    result = model.generate_content(prompt)
    return getattr(result, "text", "").strip()


# -------------------------------------------------
# Email notification helper
# -------------------------------------------------
def send_email_notification(subject, body, attachment_path=None, to_email=None):
    sender = os.getenv("SENDER_EMAIL")
    password = os.getenv("SENDER_PASSWORD")
    name = os.getenv("SENDER_NAME", "Codebase Genius Bot")

    if not (sender and password):
        print("⚠️ Missing email credentials in .env")
        return False

    to_email = to_email or sender
    msg = MIMEMultipart()
    msg["From"] = f"{name} <{sender}>"
    msg["To"] = to_email
    msg["Subject"] = subject
    msg.attach(MIMEText(body, "plain"))

    # Attach file if exists
    if attachment_path and os.path.exists(attachment_path):
        with open(attachment_path, "rb") as f:
            part = MIMEBase("application", "octet-stream")
            part.set_payload(f.read())
            encoders.encode_base64(part)
            part.add_header(
                "Content-Disposition",
                f"attachment; filename={os.path.basename(attachment_path)}",
            )
            msg.attach(part)

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(sender, password)
            server.send_message(msg)
        print("✅ Email sent successfully.")
        return True
    except Exception as e:
        print("❌ Email send failed:", e)
        return False
