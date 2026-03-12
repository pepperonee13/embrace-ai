
import os
import requests
from flask import Flask, request, render_template, jsonify
from werkzeug.utils import secure_filename
from dotenv import load_dotenv

load_dotenv()
app = Flask(__name__)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

@app.route("/", methods=["GET"])
def index():
    return render_template("index.html")

@app.route("/send", methods=["POST"])
def send():
    prompt = request.form.get("prompt", "")
    files = request.files.getlist("files")
    file_contents = {f.filename: f.read().decode("utf-8", errors="ignore") for f in files}
    # Simulate Gemini API usage (for now just echoing)
    response = {
        "prompt": prompt,
        "files": file_contents,
        "message": "Request would be sent to Gemini API here."
    }
    return jsonify(response)

if __name__ == "__main__":
    app.run(debug=True)
