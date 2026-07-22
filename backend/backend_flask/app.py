# ============================================================
# IMPORTS
# ============================================================
from dotenv import load_dotenv
load_dotenv() 
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.exceptions import HTTPException
from functools import wraps

import smtplib
from email.mime.text import MIMEText
import pymysql
import mysql.connector
import jwt
import os
import re
import json
import random
import time
import base64
import uuid
import csv
import io
import traceback
import smtplib
from email.mime.text import MIMEText
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

# ------------------------------------------------------------
# Local TLS trust fix: on machines where an antivirus (e.g. Avast/AVG)
# intercepts outbound HTTPS for scanning, it re-signs every certificate
# with its own locally-generated root CA. That root isn't in certifi's
# bundle, so every outbound Gemini/Gemma API call fails at the TLS
# handshake ("unable to get local issuer certificate") and quiz
# generation gets stuck at 0 sets forever. If certs/local_root_ca.pem
# is present (see backend/.gitignore - it's machine-local, not shared),
# extend certifi's bundle with it and point Python + grpc at the result.
# No-ops harmlessly on machines that don't have this file.
try:
    _local_ca = os.path.join(os.path.dirname(__file__), "certs", "local_root_ca.pem")
    if os.path.exists(_local_ca):
        import certifi
        _combined_ca_path = os.path.join(os.path.dirname(__file__), "certs", "_combined_ca_bundle.pem")
        with open(certifi.where(), "rb") as _base, open(_local_ca, "rb") as _extra:
            _bundle = _base.read() + b"\n" + _extra.read()
        with open(_combined_ca_path, "wb") as _out:
            _out.write(_bundle)
        os.environ["SSL_CERT_FILE"] = _combined_ca_path
        os.environ["REQUESTS_CA_BUNDLE"] = _combined_ca_path
        os.environ["GRPC_DEFAULT_SSL_ROOTS_FILE_PATH"] = _combined_ca_path
        print(f"Using extended CA bundle (local root + certifi): {_combined_ca_path}")
except Exception as _ca_err:
    print("Local CA bundle setup skipped:", _ca_err)

import google.generativeai as genai
from google.ai import generativelanguage_v1beta as glm
from google.api_core.client_options import ClientOptions
from db import get_db



from datetime import datetime, date, timedelta
import pytz

IST = pytz.timezone("Asia/Kolkata")

def today_ist():
    return datetime.now(IST).date()


def parse_time_field(t):
    """Normalizes a MySQL TIME column (returned as timedelta/str/time) to a datetime.time."""
    if not t:
        return None
    if isinstance(t, str):
        try:
            return datetime.strptime(t, "%H:%M:%S").time()
        except Exception:
            try:
                return datetime.strptime(t, "%H:%M").time()
            except Exception:
                return None
    if isinstance(t, timedelta):
        return (datetime.min + t).time()
    if type(t).__name__ == "time":
        return t
    return None


# ============================================================
# LOAD ENVIRONMENT VARIABLES
# ============================================================
load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY")
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
if not GOOGLE_API_KEY:
    raise RuntimeError("GOOGLE_API_KEY not found in .env")

genai.configure(api_key=GOOGLE_API_KEY)

# Load rotation keys
GEMINI_KEYS = [
    GOOGLE_API_KEY,
    os.getenv("GOOGLE_API_KEY_1"),
    os.getenv("GOOGLE_API_KEY_2"),
    os.getenv("GOOGLE_API_KEY_3"),
    os.getenv("GOOGLE_API_KEY_4"),
    os.getenv("GOOGLE_API_KEY_5")
]
GEMINI_KEYS = [k for k in GEMINI_KEYS if k]

MYSQL_CONFIG = {
    "host": os.getenv("MYSQL_HOST"),
    "user": os.getenv("MYSQL_USER"),
    "password": os.getenv("MYSQL_PASSWORD"),
    "database": os.getenv("MYSQL_DB"),
}

SMTP_SERVER = "smtp-relay.brevo.com"
SMTP_PORT = 465
SMTP_USER = "9da39b001@smtp-brevo.com"
SMTP_PASS = os.getenv("BREVO_SMTP_PASS")
FROM_EMAIL = "techpallotine@gmail.com"

if not SECRET_KEY:
    raise Exception("SECRET_KEY missing")
if not GOOGLE_API_KEY:
    raise Exception("GOOGLE_API_KEY missing")
if not SMTP_PASS:
    raise Exception("BREVO_SMTP_PASS missing")





# ============================================================
# FLASK SETUP
# ============================================================
app = Flask(__name__)
app.config["SECRET_KEY"] = SECRET_KEY
CORS(app, supports_credentials=True)


CORS(app, resources={r"/*": {"origins": "*"}})

UPLOAD_FOLDER = os.path.join("uploads", "profile_images")
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER


# ============================================================
# SAFE ERROR HANDLING
# Never leak raw exception text (SSL errors, Brevo/Gemini connection
# failures, DB driver errors, etc.) to the client - log the real
# exception server-side and return one generic, user-safe message.
# ============================================================
GENERIC_ERROR_MESSAGE = "Something went wrong on our end. Please try again in a moment."


def generic_error_response(e, status=500, message=None):
    print("Unhandled exception:", repr(e))
    traceback.print_exc()
    return jsonify({"success": False, "error": message or GENERIC_ERROR_MESSAGE, "message": message or GENERIC_ERROR_MESSAGE}), status


@app.errorhandler(HTTPException)
def handle_http_exception(e):
    return jsonify({"success": False, "message": e.description}), e.code


@app.errorhandler(Exception)
def handle_uncaught_exception(e):
    return generic_error_response(e)


# ============================================================
# GOOGLE GEMINI SETUP
# ============================================================
genai.configure(api_key=GOOGLE_API_KEY)

# ============================================================
# DATABASE HELPER
# ============================================================

import cloudinary
import cloudinary.uploader

cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True
)


from datetime import time as dt_time, timedelta

def format_time_to_str(val):
    if not val:
        return ""
    if isinstance(val, str):
        return val
    if isinstance(val, timedelta):
        tot_sec = int(val.total_seconds())
        h = tot_sec // 3600
        m = (tot_sec % 3600) // 60
        s = tot_sec % 60
        return f"{h:02d}:{m:02d}:{s:02d}"
    if hasattr(val, "strftime"):
        return val.strftime("%H:%M:%S")
    return str(val)

def parse_time_field(val):
    if not val:
        return None
    if isinstance(val, dt_time):
        return val
    if isinstance(val, timedelta):
        tot_sec = int(val.total_seconds())
        h = tot_sec // 3600
        m = (tot_sec % 3600) // 60
        s = tot_sec % 60
        return dt_time(h, m, s)
    if isinstance(val, str):
        parts = val.split(":")
        if len(parts) >= 2:
            return dt_time(int(parts[0]), int(parts[1]), int(parts[2]) if len(parts) > 2 else 0)
    return None
# OTP CONFIG (IN-MEMORY)
# ============================================================
OTP_TTL_SECONDS = 5 * 60
MAX_ATTEMPTS = 3

otp_store = {}
forgot_otp_store = {}


def generate_otp():
    return f"{random.randint(100000, 999999):06d}"


def send_otp_email_only(email):
    otp = generate_otp()
    expires_at = datetime.utcnow() + timedelta(seconds=OTP_TTL_SECONDS)


    otp_store[email.lower()] = {
        "otp": otp,
        "expires_at": expires_at,
        "attempts": 0
    }

    html = load_html_template(
        "otp_template.html",
        otp=otp,
        year = datetime.now().year

    )

    send_email_smtp(
        email,
        "Skill Sphere Email Verification",
        html
    )

    print("OTP sent (testing only):", otp)


def verify_otp(email, entered):
    key = email.lower()

    if key not in otp_store:
        return False, "No OTP found"

    entry = otp_store[key]

    if datetime.utcnow() > entry["expires_at"]:

        del otp_store[key]
        return False, "OTP expired"

    if entry["attempts"] >= MAX_ATTEMPTS:
        del otp_store[key]
        return False, "Maximum attempts exceeded"

    entry["attempts"] += 1

    if str(entered).strip() == entry["otp"]:
        del otp_store[key]
        return True, "OTP verified"

    return False, "Invalid OTP"

# ============================================================
# SEND OTP
# ============================================================
@app.route("/send_otp", methods=["POST"])
def send_otp():
    data = request.get_json()
    email = data.get("email")

    if not email:
        return jsonify({"success": False, "message": "Email required"}), 400

    send_otp_email_only(email)
    return jsonify({"success": True, "message": "OTP sent"}), 200

# ============================================================
# PUBLIC DEPARTMENTS FOR SIGNUP
# ============================================================
@app.route("/api/public/departments", methods=["GET", "OPTIONS"])
def public_departments():
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    conn = get_db()
    cur = conn.cursor(pymysql.cursors.DictCursor)
    try:
        cur.execute("SELECT id, name FROM departments ORDER BY name")
        deps = cur.fetchall()
        return jsonify({"success": True, "departments": deps}), 200
    except Exception as e:
        print("PUBLIC DEPARTMENTS ERROR:", repr(e))
        return jsonify({"success": False, "departments": []}), 200
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


def validate_password_strength(password):
    # Applies everywhere a student or admin/hod/faculty password gets set
    # or reset: 8+ chars, at least one uppercase, one lowercase, one
    # digit, one special character.
    if not password or len(password) < 8:
        return False, "Password must be at least 8 characters long"
    if not re.search(r"[A-Z]", password):
        return False, "Password must contain at least one uppercase letter"
    if not re.search(r"[a-z]", password):
        return False, "Password must contain at least one lowercase letter"
    if not re.search(r"[0-9]", password):
        return False, "Password must contain at least one digit"
    if not re.search(r"[^A-Za-z0-9]", password):
        return False, "Password must contain at least one special character"
    return True, ""


# ============================================================
# VERIFY OTP & SIGNUP
# ============================================================
@app.route("/verify_otp_and_signup", methods=["POST"])
def verify_otp_and_signup():
    conn = None
    cur = None
    try:
        data = request.get_json() or {}

        required = ["name", "uid", "branch", "year", "email", "password", "otp"]
        for field in required:
            if not data.get(field):
                return jsonify({
                    "success": False,
                    "message": f"{field} required"
                }), 400

        is_valid, pw_msg = validate_password_strength(data["password"])
        if not is_valid:
            return jsonify({"success": False, "message": pw_msg}), 400

        # 🔐 Verify OTP first (no DB yet)
        ok, msg = verify_otp(data["email"], data["otp"])
        if not ok:
            return jsonify({"success": False, "message": msg}), 400

        conn = get_db()
        conn.begin()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        # 🚫 Check existing user (Check email and UID independently)
        cur.execute(
            "SELECT id, email, uid FROM students WHERE email=%s OR uid=%s",
            (data["email"], data["uid"])
        )
        existing = cur.fetchone()

        if existing:
            conn.rollback()
            if existing["email"] == data["email"]:
                errMsg = "Email already registered"
            else:
                errMsg = "UID already registered"
            return jsonify({
                "success": False,
                "message": errMsg
            }), 400

        hashed = generate_password_hash(data["password"])

        # Determine dept_id from branch code or lookup
        branch_code = str(data["branch"]).strip().upper()
        dept_id = BRANCH_TO_DEPT_ID.get(branch_code)

        if not dept_id:
            # Fallback: check if branch matches department name or id directly
            cur.execute("SELECT id FROM departments WHERE name=%s OR id=%s", (data["branch"], data["branch"]))
            row = cur.fetchone()
            if row:
                dept_id = row["id"]
            else:
                dept_id = 7 # Default to AI if unmapped

        # Standardize year to single digit integer string ('1', '2', '3', '4')
        raw_year = str(data["year"]).strip()
        student_year = raw_year[0] if raw_year and raw_year[0].isdigit() else "1"

        # 🧾 Insert user (Name can be duplicate, UID and Email are unique)
        cur.execute(
            """
            INSERT INTO students (name, uid, branch, year, email, password, dept_id)
            VALUES (%s,%s,%s,%s,%s,%s,%s)
            """,
            (
                data["name"].strip(),
                data["uid"].strip(),
                branch_code,
                student_year,
                data["email"].strip(),
                hashed,
                dept_id
            )
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Signup successful"
        }), 200

    except Exception as e:
        if conn:
            conn.rollback()
        print("SIGNUP ERROR:", repr(e))
        return jsonify({
            "success": False,
            "message": "Signup failed"
        }), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


# ============================================================
# LOGIN
# ============================================================
@app.route("/login", methods=["POST"])
def login():
    data = request.get_json() or {}

    if not data.get("email") or not data.get("password"):
        return jsonify({"error": "Email and password required"}), 400

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor()

        cur.execute(
            "SELECT uid, name, email, branch, year, password FROM students WHERE email=%s",
            (data["email"],)
        )
        user = cur.fetchone()

        if not user:
            return jsonify({"error": "User not found"}), 401

        if not check_password_hash(user["password"], data["password"]):
            return jsonify({"error": "Invalid credentials"}), 401

        # 🔐 JWT now contains minimal required identity data
        token = jwt.encode(
            {
                "uid": user["uid"],
                "year": user["year"],
                "branch": user["branch"],
                "exp": datetime.utcnow() + timedelta(days=7)
            },
            SECRET_KEY,
            algorithm="HS256"
        )

        return jsonify({
            "message": "Login successful",
            "token": token,
            "student": {
                "name": user["name"],
                "email": user["email"],
                "uid": user["uid"],
                "branch": user["branch"],
                "year": user["year"]
            }
        }), 200

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()



# ============================================================
# JWT DECORATOR
# ============================================================
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):

        # 🔥 Allow CORS preflight
        if request.method == "OPTIONS":
            return jsonify({"success": True}), 200

        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "Token missing"}), 401

        token = auth_header.replace("Bearer ", "")

        try:
            # 🔹 Decode JWT (signature + expiry verified)
            data = jwt.decode(
                token,
                SECRET_KEY,
                algorithms=["HS256"]
            )

            # 🔹 Construct user object (same shape as DB user)
            user = {
                "uid": data["uid"],
                "year": data.get("year"),
                "branch": data.get("branch")
            }

        except jwt.ExpiredSignatureError:
            return jsonify({"error": "Token expired"}), 401

        except jwt.InvalidTokenError:
            return jsonify({"error": "Invalid token"}), 401

        except Exception as e:
            print("TOKEN ERROR:", repr(e))
            return jsonify({"error": "Authentication failed"}), 401

        return f(user, *args, **kwargs)

    return decorated



# ============================================================
# GEMINI QUESTION GENERATOR
# ============================================================



# ============================================================
# PROFILE
# ============================================================
@app.route("/get_student_profile", methods=["GET"])
@token_required
def get_student_profile(current_user):
    conn = None
    cur = None
    try:
        uid = current_user["uid"]
        year = int(current_user["year"])

        attempts_table = (
            f"daily_quiz_attempts_y{year}"
        )

        conn = get_db()
        cur = conn.cursor()

        cur.execute(
            f"""
            SELECT COUNT(*) AS total_attempts
            FROM {attempts_table}
            WHERE uid=%s
            """,
            (uid,)
        )
        attempts = cur.fetchone()["total_attempts"]

        cur.execute(
            "SELECT name, branch, profile_image FROM students WHERE uid=%s",
            (uid,)
        )
        student = cur.fetchone()

        if not student:
            return jsonify({
                "success": False,
                "error": "Student not found"
            }), 404

        profile_image = student["profile_image"]
        if profile_image and not profile_image.startswith("http") and not profile_image.startswith("data:"):
            profile_image = request.host_url.rstrip("/") + "/" + profile_image

        return jsonify({
            "success": True,
            "profile": {
                "name": student["name"],
                "uid": uid,
                "branch": student["branch"],
                "year": year,
                "profile_image": profile_image,
                "aptitude_attempted": attempts,
                "branch_level": current_user.get("current_level", 1)
            }
        }), 200

    except Exception as e:
        print("❌ PROFILE ERROR:", repr(e))
        return jsonify({
            "success": False,
            "error": "Internal server error"
        }), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()



@app.route("/upload_profile_image", methods=["POST", "OPTIONS"])
@token_required
def upload_profile_image(current_user):

    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.get_json(silent=True) or {}
    image_base64 = data.get("image_base64")

    if not image_base64:
        return jsonify({"error": "Image missing"}), 400

    # 🔒 Remove base64 header if present
    raw_base64 = image_base64
    if "," in raw_base64:
        raw_base64 = raw_base64.split(",")[1]

    # 🔒 Basic size protection (≈5 MB base64)
    if len(raw_base64) > 7_000_000:
        return jsonify({"error": "Image too large"}), 413

    image_url = None

    # 🔥 Try Cloudinary Upload
    try:
        if os.getenv("CLOUDINARY_CLOUD_NAME") and os.getenv("CLOUDINARY_API_KEY"):
            result = cloudinary.uploader.upload(
                base64.b64decode(raw_base64),
                folder="skillsphere/profile_images",
                public_id=str(current_user["uid"]),  # overwrite same user image
                overwrite=True,
                resource_type="image"
            )
            image_url = result.get("secure_url")
    except Exception as e:
        print("CLOUDINARY UPLOAD NOTICE:", repr(e))

    # 🔥 Fallback to data URI if Cloudinary upload fails or is not configured
    if not image_url:
        image_url = f"data:image/jpeg;base64,{raw_base64}"

    conn = None
    cur = None
    try:
        # 🔥 Save profile image URL in DB
        conn = get_db()
        cur = conn.cursor()

        cur.execute(
            "UPDATE students SET profile_image=%s WHERE uid=%s",
            (image_url, current_user["uid"])
        )

        conn.commit()

        return jsonify({
            "success": True,
            "profile_image": image_url
        }), 200

    except Exception as e:
        if conn:
            conn.rollback()
        print("IMAGE UPLOAD ERROR:", repr(e))
        return jsonify({"error": "Image upload failed"}), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()



from flask import send_from_directory

# ============================================================
# LOGOUT
# ============================================================
@app.route("/logout", methods=["POST"])
def logout():
    return jsonify({"success": True}), 200




FORGOT_OTP_TTL = 5 * 60
forgot_otp_store = {}

def load_html_template(filename, **kwargs):
    template_path = os.path.join(os.getcwd(), filename)

    if not os.path.exists(template_path):
        raise FileNotFoundError(f"{filename} not found")

    with open(template_path, "r", encoding="utf-8") as f:
        html = f.read()

    for key, value in kwargs.items():
        html = html.replace(f"{{{{{key}}}}}", str(value))

    return html



@app.route("/forgot_password", methods=["POST"])
def forgot_password():
    conn = None
    cur = None
    try:
        data = request.get_json() or {}

        uid = str(data.get("uid", "")).strip()
        email_input = str(data.get("email", "")).strip()

        if not uid and not email_input:
            return jsonify({"error": "Email or UID required"}), 400

        # 🔒 Fetch email & uid safely
        conn = get_db()
        cur = conn.cursor()

        if email_input:
            cur.execute("SELECT uid, email FROM students WHERE email=%s", (email_input,))
        else:
            cur.execute("SELECT uid, email FROM students WHERE uid=%s", (uid,))
        row = cur.fetchone()

        if not row:
            return jsonify({"error": "Account not found"}), 404

        uid = row["uid"]
        email = row["email"]

    except Exception as e:
        print("FORGOT PASSWORD DB ERROR:", repr(e))
        return jsonify({"error": "Internal server error"}), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    # -------------------------------------------------
    # OTP generation (AFTER DB is closed)
    # -------------------------------------------------
    otp = str(random.randint(100000, 999999))
    expires = datetime.utcnow() + timedelta(seconds=FORGOT_OTP_TTL)

    # Store keyed by string uid - verify_forgot_otp/reset_password both
    # look this up via str(data.get("uid")), but `uid` here comes back
    # from the DB as a native int, so an unconverted int key would never
    # match those string lookups and every verification would fail with
    # "OTP not requested or expired" regardless of timing.
    forgot_otp_store[str(uid)] = {
        "otp": otp,
        "expires": expires,
        "verified": False,
        "attempts": 0
    }

    html = load_html_template(
        "forgototp.html",
        otp=otp,
        year=datetime.now().year
    )

    # -------------------------------------------------
    # Send email
    # -------------------------------------------------
    try:
        send_email_smtp(
            email,
            "Password Reset OTP — Skill Sphere",
            html
        )
    except Exception as e:
        # ❌ Remove OTP if email fails
        forgot_otp_store.pop(str(uid), None)

        print("FORGOT OTP EMAIL ERROR:", repr(e))
        return jsonify({
            "error": "Failed to send OTP email. Please try again later."
        }), 500

    return jsonify({
        "message": "OTP sent to registered email"
    }), 200




def load_template(otp, template_name):
    template_path = os.path.join(os.getcwd(), template_name)

    if not os.path.exists(template_path):
        raise FileNotFoundError(f"{template_name} not found")

    with open(template_path, "r", encoding="utf-8") as f:
        html = f.read()

    html = html.replace("{{otp}}", otp)
    html = html.replace("{{year}}", str(datetime.now().year))
    return html


import requests
import os

def send_email_smtp(to_email, subject, html_body):
    api_key = os.getenv("BREVO_API_KEY") or os.getenv("ADMIN_KEY")
    if not api_key:
        raise Exception("BREVO_API_KEY or ADMIN_KEY not set")

    url = "https://api.brevo.com/v3/smtp/email"

    payload = {
        "sender": {
            "name": "SkillSphere",
            "email": FROM_EMAIL
        },
        "to": [{"email": to_email}],
        "subject": subject,
        "htmlContent": html_body
    }

    headers = {
        "accept": "application/json",
        "api-key": api_key,
        "content-type": "application/json"
    }

    response = requests.post(url, json=payload, headers=headers, timeout=15)

    if response.status_code not in (200, 201, 202):
        raise Exception(f"Brevo API error: {response.text}")

    print("Email sent via Brevo API to:", to_email)


def send_email_with_attachment(to_email, subject, html_body, attachment_bytes, filename):
    return send_email_with_attachments(to_email, subject, html_body, [(attachment_bytes, filename)])


def send_email_with_attachments(to_email, subject, html_body, attachments):
    # attachments: list of (bytes, filename) tuples - Brevo's API already
    # accepts a list here, one email can carry several files.
    api_key = os.getenv("BREVO_API_KEY") or os.getenv("ADMIN_KEY")
    if not api_key:
        raise Exception("BREVO_API_KEY or ADMIN_KEY not set")

    url = "https://api.brevo.com/v3/smtp/email"

    payload = {
        "sender": {
            "name": "SkillSphere",
            "email": FROM_EMAIL
        },
        "to": [{"email": to_email}],
        "subject": subject,
        "htmlContent": html_body,
        "attachment": [
            {"content": base64.b64encode(data).decode("utf-8"), "name": filename}
            for data, filename in attachments
        ]
    }

    headers = {
        "accept": "application/json",
        "api-key": api_key,
        "content-type": "application/json"
    }

    response = requests.post(url, json=payload, headers=headers, timeout=30)

    if response.status_code not in (200, 201, 202):
        raise Exception(f"Brevo API error: {response.text}")

    print("Email with attachment sent via Brevo API to:", to_email)




@app.route("/verify_forgot_otp", methods=["POST"])
def verify_forgot_otp():
    data = request.get_json() or {}

    uid = str(data.get("uid", "")).strip()
    otp = str(data.get("otp", "")).strip()

    if not uid or not otp:
        return jsonify({"error": "UID and OTP required"}), 400

    entry = forgot_otp_store.get(uid)

    if not entry:
        return jsonify({"error": "OTP not requested or expired"}), 400

    if entry.get("verified"):
        return jsonify({"error": "OTP already used"}), 400

    if datetime.utcnow() > entry["expires"]:
        del forgot_otp_store[uid]
        return jsonify({"error": "OTP expired"}), 400

    if entry.get("attempts", 0) >= MAX_ATTEMPTS:
        del forgot_otp_store[uid]
        return jsonify({"error": "Maximum attempts exceeded. Please request a new OTP."}), 400

    entry["attempts"] = entry.get("attempts", 0) + 1

    if otp != entry["otp"]:
        return jsonify({"error": "Invalid OTP"}), 400

    # ✅ Mark OTP as used
    entry["verified"] = True

    return jsonify({"message": "OTP verified"}), 200


@app.route("/reset_password", methods=["POST"])
def reset_password():
    conn = None
    cur = None
    try:
        data = request.get_json() or {}

        uid = str(data.get("uid", "")).strip()
        new_password = data.get("new_password")
        confirm_password = data.get("confirm_password")

        if not uid or not new_password or not confirm_password:
            return jsonify({"error": "All fields required"}), 400

        if new_password != confirm_password:
            return jsonify({"error": "Passwords do not match"}), 400

        is_valid, pw_msg = validate_password_strength(new_password)
        if not is_valid:
            return jsonify({"error": pw_msg}), 400

        entry = forgot_otp_store.get(uid)

        if not entry or not entry.get("verified"):
            return jsonify({"error": "OTP not verified"}), 400

        hashed = generate_password_hash(new_password)

        conn = get_db()
        conn.begin()
        cur = conn.cursor()

        cur.execute(
            "UPDATE students SET password=%s WHERE uid=%s",
            (hashed, uid)
        )

        if cur.rowcount == 0:
            conn.rollback()
            return jsonify({"error": "User not found"}), 404

        conn.commit()

        # ✅ OTP cleanup ONLY after successful commit
        forgot_otp_store.pop(uid, None)

        return jsonify({
            "message": "Password reset successful"
        }), 200

    except Exception as e:
        if conn:
            conn.rollback()
        print("RESET PASSWORD ERROR:", repr(e))
        return jsonify({"error": "Password reset failed"}), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


#/////////////////////////////////////////////////////////////////////////////////////////////////////////////
#NO CHANGE ABOVE THIUS LINE
#/////////////////////////////////////////////////////////////////////////////////////////////////////////////


def build_daily_mcq_prompt(topics, difficulty):
    difficulty_map = {
        "easy": "easy, basic, beginner-friendly",
        "medium": "moderate, conceptual, exam-oriented",
        "hard": "difficult, tricky, placement-level",
        "very hard": "extremely difficult, trap-based, company-style"
    }

    difficulty_text = difficulty_map.get(
        difficulty.lower(),
        "difficult, placement-level"
    )

    return f"""
Act as an elite AI placement MCQ generator for AI engineering students.

Generate exactly 10 {difficulty_text} multiple choice questions.

Topics strictly limited to:
{topics}

Rules:
- One correct option only
- No explanations
- Questions must strictly match the difficulty level
- Avoid repetition
- Output STRICT JSON ONLY

Format:
[
  {{
    "question": "string",
    "options": ["A) ...", "B) ...", "C) ...", "D) ..."],
    "answer": "A"
  }}
]
"""

def generate_mcqs_from_ai(topics, difficulty):
    shuffled_keys = list(GEMINI_KEYS)
    random.shuffle(shuffled_keys)
    
    prompt = build_daily_mcq_prompt(topics, difficulty)
    
    last_error = None
    for attempt, key in enumerate(shuffled_keys):
        try:
            client_opts = ClientOptions(api_key=key)
            my_client = glm.GenerativeServiceClient(client_options=client_opts)
            
            model = genai.GenerativeModel("gemini-flash-latest")
            model._client = my_client

            response = model.generate_content(prompt)

            # Robust parser: try raw_decode from each '[' until we get 10 questions
            questions = None
            raw = response.text
            search_start = 0
            while True:
                idx = raw.find("[", search_start)
                if idx == -1:
                    break
                try:
                    decoder = json.JSONDecoder()
                    parsed, end = decoder.raw_decode(raw[idx:])
                    if isinstance(parsed, list) and len(parsed) == 10:
                        # Verify each item has required keys
                        if all("question" in q and "options" in q and "answer" in q for q in parsed):
                            questions = parsed
                            break
                except (json.JSONDecodeError, ValueError):
                    pass
                search_start = idx + 1

            if questions is None:
                # Fallback: try stripping markdown fences
                text = re.sub(r"```json|```", "", raw.strip())
                try:
                    parsed = json.loads(text)
                    if isinstance(parsed, list) and len(parsed) == 10:
                        questions = parsed
                except:
                    pass

            if questions is None or len(questions) != 10:
                raise Exception(f"Invalid MCQ format (parsed {len(questions) if questions else 0} questions)")

            return questions

        except Exception as e:
            last_error = e
            print(f"AI Attempt {attempt+1} failed with key {key[:10]}... Error: {e}")

    print("AI ERROR (All keys exhausted):", last_error)
    return []

    

def cleanup_old_quiz(year, uid):
    conn = None
    cur = None
    try:
        today = today_ist()

        cache_table = f"daily_quiz_questions_y{year}"
        bank_table = f"daily_quiz_questions_bank_y{year}"

        conn = get_db()
        conn.begin()   # 🔒 atomic cleanup
        cur = conn.cursor()

        # 🔥 Delete previous-day cached questions
        cur.execute(
            f"""
            DELETE FROM {cache_table}
            WHERE uid=%s AND quiz_date < %s
            """,
            (uid, today)
        )

        # 🔥 Delete previous-day bank questions
        cur.execute(
            f"""
            DELETE FROM {bank_table}
            WHERE uid=%s AND quiz_date < %s
            """,
            (uid, today)
        )

        conn.commit()

    except Exception as e:
        if conn:
            conn.rollback()
        print("CLEANUP OLD QUIZ ERROR:", repr(e))
        # optional: re-raise or just log
        # raise

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

def load_questions_from_csv(uid, topic_name):
    csv_file_path = os.path.join(os.path.dirname(__file__), "data_warehousing_questions.csv")
    if not os.path.exists(csv_file_path):
        return None
        
    try:
        import csv
        student_qs = []
        all_qs = []
        
        with open(csv_file_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                # Compare topic name (case-insensitive)
                if row.get("topic", "").strip().lower() != topic_name.strip().lower():
                    continue
                    
                q_item = {
                    "question": row["question"],
                    "options": [row["option_a"], row["option_b"], row["option_c"], row["option_d"]],
                    "answer": row["correct_answer"]
                }
                all_qs.append(q_item)
                if str(row.get("student_uid")) == str(uid):
                    student_qs.append(q_item)
                    
        # If we found student-specific questions, return them
        if len(student_qs) == 10:
            return student_qs
            
        # Fallback: if student not found in CSV, pick 10 random questions from this topic
        if len(all_qs) >= 10:
            import random
            return random.sample(all_qs, 10)
            
        return None
    except Exception as e:
        print(f"Error loading questions from CSV: {e}")
        return None


def get_daily_quiz(year, quiz_type, uid, quiz_id=None):
    conn = None
    cur = None
    try:
        today = today_ist()
        topic_table = f"daily_quiz_topics_y{year}"
        cache_table = f"daily_quiz_questions_y{year}"
        bank_table = f"daily_quiz_questions_bank_y{year}"
        attempts_table = f"daily_quiz_attempts_y{year}"

        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        if not quiz_id:
            branch = current_user.get("branch", "")
            cur.execute(
                f"SELECT id FROM {topic_table} WHERE quiz_date=%s AND quiz_type=%s AND (department=%s OR department='ALL' OR department IS NULL OR department='') ORDER BY id DESC LIMIT 1",
                (today, quiz_type, branch)
            )
            row = cur.fetchone()
            if not row:
                cur.execute(
                    f"SELECT id FROM {topic_table} WHERE quiz_date=%s AND quiz_type=%s ORDER BY id DESC LIMIT 1",
                    (today, quiz_type)
                )
                row = cur.fetchone()
            if not row:
                cur.close()
                conn.close()
                return []
            quiz_id = row["id"]
        else:
            quiz_id = int(quiz_id)

        # Duration is looked up once, up front, so both the resume and
        # fresh-start branches below can compute remaining_seconds without
        # a second topic-table round trip.
        cur.execute(f"SELECT duration_minutes, question_per_set FROM {topic_table} WHERE id=%s", (quiz_id,))
        duration_row = cur.fetchone() or {}
        duration_minutes = duration_row.get("duration_minutes") or 10
        questions_per_set = duration_row.get("question_per_set") or 10

        # Check attempt status using both quiz_id and quiz_date
        try:
            cur.execute(
                f"SELECT status, started_at FROM {attempts_table} WHERE uid=%s AND quiz_date=%s AND quiz_id=%s",
                (uid, today, quiz_id)
            )
            existing_attempt = cur.fetchone()
        except Exception:
            try:
                cur.execute(f"ALTER TABLE {attempts_table} ADD COLUMN started_at DATETIME NULL DEFAULT CURRENT_TIMESTAMP")
                conn.commit()
            except Exception:
                pass
            cur.execute(
                f"SELECT status, started_at FROM {attempts_table} WHERE uid=%s AND quiz_date=%s AND quiz_id=%s",
                (uid, today, quiz_id)
            )
            existing_attempt = cur.fetchone()

        if existing_attempt:
            if existing_attempt["status"] != "started":
                cur.close()
                conn.close()
                return {"attempted": True}

        if existing_attempt:
            cur.execute(
                "SELECT set_number FROM daily_quiz_student_mapping WHERE uid=%s AND quiz_date=%s AND quiz_id=%s",
                (uid, today, quiz_id)
            )
            map_row = cur.fetchone()
            if not map_row:
                cur.close()
                conn.close()
                return []
            allocated_set = map_row["set_number"]
            
            # Load cached questions directly for resuming
            cur.execute(
                f"SELECT questions_json FROM {cache_table} WHERE uid=%s AND quiz_date=%s AND quiz_type=%s AND quiz_id=%s",
                (uid, today, quiz_type, quiz_id)
            )
            cache_row = cur.fetchone()
            if not cache_row:
                cur.close()
                conn.close()
                return []
            
            frontend_questions = json.loads(cache_row["questions_json"])

            # Load autosaved answers
            cur.execute("""
                SELECT question_id, selected_answer 
                FROM daily_quiz_autosave
                WHERE uid = %s AND quiz_date = %s AND quiz_id = %s
            """, (uid, today, quiz_id))
            autosave_rows = cur.fetchall()
            autosave_map = {r["question_id"]: r["selected_answer"] for r in autosave_rows}

            for q in frontend_questions:
                q["selected_answer"] = autosave_map.get(q["question_id"], "")

            if existing_attempt["started_at"]:
                started_at = existing_attempt["started_at"]
            else:
                # Attempt row predates duration tracking - start the clock now.
                started_at = datetime.now()
                cur.execute(
                    f"UPDATE {attempts_table} SET started_at=%s WHERE uid=%s AND quiz_date=%s AND quiz_id=%s",
                    (started_at, uid, today, quiz_id)
                )

            elapsed = (datetime.now() - started_at).total_seconds()
            remaining_seconds = max(0, int(duration_minutes) * 60 - int(elapsed))

            cur.close()
            conn.close()
            return {
                "questions": frontend_questions,
                "remaining_seconds": remaining_seconds,
                "duration_minutes": duration_minutes,
            }
        else:
            cur.execute(
                f"SELECT id, topic, difficulty, status, quiz_start_time, quiz_end_time FROM {topic_table} WHERE id=%s",
                (quiz_id,)
            )
            topic_row = cur.fetchone()
            if not topic_row:
                cur.close()
                conn.close()
                return []
            if topic_row.get("status") != "READY":
                cur.close()
                conn.close()
                # Question generation can still be in progress at the
                # scheduled start time (e.g. another quiz's generation was
                # already running and queued this one behind it) - a plain
                # "not ready" status code means nothing to a student, so
                # show a friendly retry message instead.
                return {"error": "Quiz has not started yet. Please try again after some time."}

            # Check timings
            now_time = datetime.now(IST).time()
            start_time = topic_row.get("quiz_start_time")
            end_time = topic_row.get("quiz_end_time")

            def parse_time_field(t):
                if not t:
                    return None
                if isinstance(t, str):
                    try:
                        return datetime.strptime(t, "%H:%M:%S").time()
                    except:
                        try:
                            return datetime.strptime(t, "%H:%M").time()
                        except:
                            return None
                if isinstance(t, timedelta):
                    return (datetime.min + t).time()
                if type(t).__name__ == 'time':
                    return t
                return None

            st = parse_time_field(start_time)
            et = parse_time_field(end_time)

            if st and now_time < st:
                cur.close()
                conn.close()
                return {"error": f"Quiz starts at {st.strftime('%I:%M %p')}. Please try again then."}

            if et and now_time > et:
                cur.close()
                conn.close()
                return {"error": f"Quiz has ended at {et.strftime('%I:%M %p')}."}

            # A student whose attempt was reset by the quiz creator gets no
            # special-case row anywhere else (their attempt/mapping rows were
            # simply deleted), so a reset re-attempt is otherwise indistinguishable
            # from a genuine first-time start. This marker table is how the set
            # picker below tells the two apart: a reset student is allowed to draw
            # from ANY set (including ones already marked DONE), while a real
            # first-timer only draws from sets not yet handed to anyone.
            cur.execute("""
                CREATE TABLE IF NOT EXISTS daily_quiz_reset_students (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    uid INT NOT NULL,
                    quiz_id INT NOT NULL,
                    reset_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY uq_uid_quiz (uid, quiz_id)
                )
            """)
            cur.execute(
                "SELECT 1 FROM daily_quiz_reset_students WHERE uid=%s AND quiz_id=%s",
                (uid, quiz_id)
            )
            was_reset = cur.fetchone() is not None

            conn.begin()
            if was_reset:
                cur.execute("""
                    SELECT set_number
                    FROM daily_quiz_sets
                    WHERE quiz_id = %s
                    ORDER BY RAND()
                    LIMIT 1
                """, (quiz_id,))
            else:
                cur.execute("""
                    SELECT set_number
                    FROM daily_quiz_sets
                    WHERE quiz_id = %s AND status = 'AVAILABLE'
                    ORDER BY RAND()
                    LIMIT 1
                """, (quiz_id,))
            set_row = cur.fetchone()
            used_fallback = False

            if not set_row:
                # If all unique AVAILABLE sets for this quiz_id are exhausted, draw from any set for this quiz_id
                cur.execute("""
                    SELECT set_number
                    FROM daily_quiz_sets
                    WHERE quiz_id = %s
                    ORDER BY RAND()
                    LIMIT 1
                """, (quiz_id,))
                set_row = cur.fetchone()

            if not set_row:
                conn.rollback()
                cur.close()
                conn.close()
                return {"error": "Quiz is not ready yet or no sets available"}

            allocated_set = set_row["set_number"]

            # Mark this set as handed out so the next genuine first-timer
            # won't be given the same set - unless this was a reset draw,
            # which intentionally re-picks from the full pool without
            # affecting DONE/AVAILABLE status.
            if not was_reset:
                cur.execute("""
                    UPDATE daily_quiz_sets SET status = 'DONE'
                    WHERE quiz_id = %s AND set_number = %s
                """, (quiz_id, allocated_set))
            else:
                cur.execute(
                    "DELETE FROM daily_quiz_reset_students WHERE uid=%s AND quiz_id=%s",
                    (uid, quiz_id)
                )

            cur.execute("""
                INSERT INTO daily_quiz_student_mapping (uid, year, quiz_date, quiz_id, set_number)
                VALUES (%s, %s, %s, %s, %s)
            """, (uid, year, today, quiz_id, allocated_set))

            try:
                cur.execute(
                    f"""
                    INSERT INTO {attempts_table}
                    (uid, quiz_date, quiz_id, status, score, total, time_taken_seconds, started_at)
                    VALUES (%s, %s, %s, 'started', 0, 0, 0, NOW())
                    """,
                    (uid, today, quiz_id)
                )
            except Exception:
                cur.execute(
                    f"""
                    INSERT INTO {attempts_table}
                    (uid, quiz_date, quiz_id, status, score, total, time_taken_seconds)
                    VALUES (%s, %s, %s, 'started', 0, 0, 0)
                    """,
                    (uid, today, quiz_id)
                )
            conn.commit()

            cur.execute("""
                SELECT question, option_a, option_b, option_c, option_d, correct_option
                FROM daily_quiz_questions_pregenerated
                WHERE quiz_id = %s AND set_number = %s
            """, (quiz_id, allocated_set))
            questions = cur.fetchall()
            
            if not questions:
                # Fallback to any pregenerated questions for this specific quiz_id
                cur.execute("""
                    SELECT question, option_a, option_b, option_c, option_d, correct_option
                    FROM daily_quiz_questions_pregenerated
                    WHERE quiz_id = %s
                """, (quiz_id,))
                questions = cur.fetchall()

            # 🔒 STICK TO EXACT question_per_set COUNT
            if questions and len(questions) > questions_per_set:
                questions = questions[:questions_per_set]
            frontend_questions = []
            for q in questions:
                opts = [q["option_a"], q["option_b"], q["option_c"], q["option_d"]]
                correct_idx = ord(q["correct_option"]) - ord("A")
                correct_answer_text = opts[correct_idx]

                cur.execute(
                    f"""
                    INSERT INTO {bank_table}
                    (quiz_date, uid, quiz_id, question_text, correct_answer)
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    (today, uid, quiz_id, q["question"], correct_answer_text)
                )
                qid = cur.lastrowid
                frontend_questions.append({
                    "question_id": qid,
                    "question": q["question"],
                    "options": opts
                })

            cur.execute(
                f"""
                INSERT INTO {cache_table}
                (uid, quiz_date, quiz_id, quiz_type, questions_json)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (uid, today, quiz_id, quiz_type, json.dumps(frontend_questions))
            )
            conn.commit()
            cur.close()
            conn.close()

        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        cur.execute(
            f"SELECT questions_json FROM {cache_table} WHERE uid=%s AND quiz_date=%s AND quiz_type=%s AND quiz_id=%s",
            (uid, today, quiz_type, quiz_id)
        )
        cache_row = cur.fetchone()
        if not cache_row:
            cur.close()
            conn.close()
            return []
        
        frontend_questions = json.loads(cache_row["questions_json"])

        cur.execute("""
            SELECT question_id, selected_answer 
            FROM daily_quiz_autosave
            WHERE uid = %s AND quiz_date = %s AND quiz_id = %s
        """, (uid, today, quiz_id))
        autosave_rows = cur.fetchall()
        autosave_map = {r["question_id"]: r["selected_answer"] for r in autosave_rows}

        for q in frontend_questions:
            q["selected_answer"] = autosave_map.get(q["question_id"], "")

        cur.close()
        conn.close()
        return {
            "questions": frontend_questions,
            "remaining_seconds": int(duration_minutes) * 60,
            "duration_minutes": duration_minutes,
        }

    except Exception as e:
        if conn:
            conn.rollback()
        print("GET DAILY QUIZ ERROR:", repr(e))
        return []
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


def has_attempted_today(year, uid, quiz_id=None):
    conn = None
    cur = None
    try:
        today = today_ist()
        attempts_table = f"daily_quiz_attempts_y{year}"

        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        if quiz_id:
            cur.execute(
                f"""
                SELECT status
                FROM {attempts_table}
                WHERE uid=%s AND quiz_date=%s AND quiz_id=%s
                LIMIT 1
                """,
                (uid, today, quiz_id)
            )
        else:
            cur.execute(
                f"""
                SELECT status
                FROM {attempts_table}
                WHERE uid=%s AND quiz_date=%s
                LIMIT 1
                """,
                (uid, today)
            )
        row = cur.fetchone()
        if not row:
            return False
        return row["status"] != 'started'

    except Exception as e:
        print("HAS ATTEMPTED ERROR:", repr(e))
        return True
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


@app.route("/daily_quiz", methods=["GET", "OPTIONS"])
@token_required
def daily_quiz(current_user):

    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    year = int(current_user["year"])
    uid = current_user["uid"]
    quiz_type = "placement"
    branch = current_user.get("branch", "")
    
    quiz_id = request.args.get("quiz_id")
    print(f"[DAILY_QUIZ] uid={uid} year={year} branch={branch} quiz_id={quiz_id}")

    if has_attempted_today(year, uid, quiz_id):
        print(f"[DAILY_QUIZ] Already attempted - uid={uid} quiz_id={quiz_id}")
        return jsonify({
            "success": True,
            "attempted": True,
            "message": "Quiz already attempted today"
        }), 200

    questions = get_daily_quiz(year, quiz_type, uid, quiz_id)
    print(f"[DAILY_QUIZ] get_daily_quiz result type={type(questions)} val={questions if not isinstance(questions, list) else f'list of {len(questions)} items'}")

    if isinstance(questions, dict) and "error" in questions:
        print(f"[DAILY_QUIZ] Error returned: {questions['error']}")
        return jsonify({
            "success": False,
            "attempted": False,
            "message": questions["error"]
        }), 400

    if isinstance(questions, dict) and questions.get("attempted") == True:
        return jsonify({
            "success": True,
            "attempted": True,
            "message": "Quiz already attempted today"
        }), 200

    if not questions:
        print(f"[DAILY_QUIZ] 404: questions is falsy: {repr(questions)}")
        return jsonify({
            "success": False,
            "attempted": False,
            "message": "No quiz today"
        }), 404

    return jsonify({
        "success": True,
        "attempted": False,
        "quiz_date": today_ist().strftime("%Y-%m-%d"),
        "quiz_type": quiz_type,
        "questions": questions["questions"],
        "remaining_seconds": questions["remaining_seconds"],
        "duration_minutes": questions["duration_minutes"]
    }), 200



def resolve_tables(year):
    year = str(year)

    if year not in ("1", "2", "3", "4"):
        raise ValueError("Invalid year")

    return (
        f"daily_quiz_attempts_y{year}",
        f"daily_quiz_answers_y{year}",
        f"daily_quiz_questions_bank_y{year}"
    )



@app.route("/api/profile/today", methods=["GET"])
@token_required
def profile_today(current_user):
    conn = None
    cur = None
    try:
        uid = current_user["uid"]
        year = int(current_user["year"])

        attempts_table, _, _ = resolve_tables(year)

        conn = get_db()
        cur = conn.cursor()

        cur.execute(
            f"""
            SELECT SUM(score) AS total_score, SUM(total) AS total_questions, MAX(attempted_at) AS last_attempted
            FROM {attempts_table}
            WHERE uid=%s AND quiz_date=%s AND status='submitted'
            """,
            (uid, today_ist())
        )

        row = cur.fetchone()

        if not row or row["total_questions"] is None:
            return jsonify({
                "attempted": False,
                "message": "Quiz not attempted today"
            }), 200

        return jsonify({
            "attempted": True,
            "score": int(row["total_score"]),
            "total": int(row["total_questions"]),
            "attempted_at": row["last_attempted"]
        }), 200

    except Exception as e:
        return generic_error_response(e)

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


def format_creator_name(created_by, cur=None):
    if not created_by:
        return "Admin"
    cb = str(created_by).strip()
    if not cb:
        return "Admin"
    cb_lower = cb.lower()
    if cb_lower in ["admin", "system", "superadmin", "administrator"]:
        return "Admin"

    close_cur = False
    conn = None
    if not cur:
        try:
            conn = get_db()
            cur = conn.cursor(pymysql.cursors.DictCursor)
            close_cur = True
        except Exception:
            pass

    try:
        if cur:
            cur.execute("""
                SELECT name, role FROM admins 
                WHERE email = %s OR admin_uid = %s OR id = %s
                LIMIT 1
            """, (cb, cb, int(cb) if cb.isdigit() else -1))
            admin_row = cur.fetchone()
            if admin_row:
                role = (admin_row.get("role") or "").lower()
                name = (admin_row.get("name") or "").strip()
                if role in ["admin", "super_admin", "superadmin"]:
                    return "Admin"
                if name:
                    if name.lower() in ["admin", "super admin", "administrator"]:
                        return "Admin"
                    return name
    except Exception as e:
        print("format_creator_name error:", e)
    finally:
        if close_cur:
            if cur: cur.close()
            if conn: conn.close()

    if "admin" in cb_lower:
        return "Admin"
    return cb


@app.route("/api/profile/today/quizzes", methods=["GET", "OPTIONS"])
@token_required
def profile_today_quizzes(current_user):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    conn = None
    cur = None
    try:
        uid = current_user["uid"]
        year = int(current_user["year"])
        quiz_type = request.args.get("type", "ai")  # "ai" or "faculty"
        today = today_ist()

        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        if quiz_type == "faculty":
            marks_table = f"assignment_quiz_marks_y{year}"
            cur.execute(f"""
                SELECT 
                    m.quiz_id,
                    m.quiz_date,
                    m.score,
                    m.total_questions AS total,
                    m.submitted_at,
                    q.quiz_name,
                    q.quiz_start_time,
                    q.quiz_end_time,
                    q.created_by,
                    q.department AS subject,
                    a.name AS creator_name,
                    a.role AS creator_role
                FROM {marks_table} m
                LEFT JOIN faculty_quiz_master q ON q.quiz_id = m.quiz_id
                LEFT JOIN admins a ON a.email = q.created_by
                WHERE m.uid = %s AND m.quiz_date = %s
                ORDER BY m.id DESC
            """, (uid, today))
            rows = cur.fetchall()

            quizzes = []
            now = datetime.now(IST)
            for r in rows:
                end_time_val = parse_time_field(r["quiz_end_time"])
                is_ended = True
                end_time_str = format_time_to_str(r["quiz_end_time"])
                if end_time_val and r["quiz_date"]:
                    end_dt = IST.localize(datetime.combine(r["quiz_date"], end_time_val))
                    if now < end_dt:
                        is_ended = False

                role = (r.get("creator_role") or "").lower()
                cname = (r.get("creator_name") or "").strip()
                if role in ["admin", "super_admin", "superadmin"] or not cname:
                    creator = "Admin"
                elif cname.lower() in ["admin", "super admin", "administrator"]:
                    creator = "Admin"
                else:
                    creator = cname

                subj = r["subject"] or r["quiz_name"] or "Faculty Quiz"

                quizzes.append({
                    "quiz_id": r["quiz_id"],
                    "quiz_name": r["quiz_name"] or f"Faculty Quiz #{r['quiz_id']}",
                    "quiz_date": str(r["quiz_date"]),
                    "subject": subj,
                    "score": r["score"],
                    "total": r["total"],
                    "quiz_start_time": format_time_to_str(r["quiz_start_time"]),
                    "quiz_end_time": end_time_str,
                    "created_by": creator,
                    "is_ended": is_ended,
                    "type": "faculty"
                })

            return jsonify({
                "success": True,
                "quiz_type": "faculty",
                "quizzes": quizzes
            }), 200

        else:  # "ai" Daily Target Quizzes
            attempts_table = f"daily_quiz_attempts_y{year}"
            topics_table = f"daily_quiz_topics_y{year}"

            cur.execute(f"""
                SELECT 
                    a.id AS attempt_id,
                    a.quiz_id,
                    a.quiz_date,
                    a.score,
                    a.total,
                    a.attempted_at,
                    t.topic,
                    t.subject,
                    t.department,
                    t.created_by,
                    ad.name AS creator_name,
                    ad.role AS creator_role
                FROM {attempts_table} a
                LEFT JOIN {topics_table} t ON t.id = a.quiz_id
                LEFT JOIN admins ad ON ad.email = t.created_by
                WHERE a.uid = %s AND a.quiz_date = %s AND a.status = 'submitted'
                ORDER BY a.id DESC
            """, (uid, today))
            rows = cur.fetchall()

            quizzes = []
            for r in rows:
                title = r["topic"] or r["subject"] or f"AI Daily Quiz #{r['quiz_id'] or r['attempt_id']}"
                subj = r["subject"] or r["topic"] or "Daily Target"
                dept = r.get("department") or current_user.get("branch") or "AI"

                role = (r.get("creator_role") or "").lower()
                cname = (r.get("creator_name") or "").strip()
                if role in ["admin", "super_admin", "superadmin"] or not cname:
                    creator = "Admin"
                elif cname.lower() in ["admin", "super admin", "administrator"]:
                    creator = "Admin"
                else:
                    creator = cname

                quizzes.append({
                    "quiz_id": r["quiz_id"],
                    "attempt_id": r["attempt_id"],
                    "quiz_name": title,
                    "quiz_date": str(r["quiz_date"]),
                    "department": dept,
                    "subject": subj,
                    "created_by": creator,
                    "score": r["score"],
                    "total": r["total"],
                    "is_ended": True,
                    "type": "ai"
                })

            return jsonify({
                "success": True,
                "quiz_type": "ai",
                "quizzes": quizzes
            }), 200

    except Exception as e:
        print("TODAY QUIZZES ERROR:", repr(e))
        return jsonify({"success": False, "message": "Internal server error"}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()


@app.route("/api/profile/review", methods=["GET"])
@token_required
def profile_review(current_user):
    conn = None
    cur = None
    try:
        uid = current_user["uid"]              # 🔒 from token
        year = request.args.get("year", type=int)
        quiz_date = request.args.get("quiz_date")  # yyyy-mm-dd

        if not year or not quiz_date:
            return jsonify({"error": "year and quiz_date required"}), 400

        attempts_table, answers_table, questions_table = resolve_tables(year)

        conn = get_db()
        cur = conn.cursor()

        # Step 1: Get attempt ID
        cur.execute(
            f"""
            SELECT id
            FROM {attempts_table}
            WHERE uid=%s AND quiz_date=%s
            """,
            (uid, quiz_date)
        )

        attempt = cur.fetchone()
        if not attempt:
            return jsonify({"error": "Quiz not attempted"}), 404

        attempt_id = attempt["id"]

        # Step 2: Fetch questions + answers
        cur.execute(
            f"""
            SELECT 
                q.question_text,
                q.correct_answer,
                a.selected_answer,
                a.is_correct
            FROM {answers_table} a
            JOIN {questions_table} q
                ON a.question_id = q.id
            WHERE a.attempt_id=%s
            """,
            (attempt_id,)
        )

        rows = cur.fetchall()

        return jsonify({
            "success": True,
            "review": rows
        }), 200

    except Exception as e:
        print("PROFILE REVIEW ERROR:", repr(e))
        return jsonify({"error": "Internal server error"}), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()



@app.route("/api/profile/status", methods=["GET"])
@token_required
def attempt_status(current_user):
    conn = None
    cur = None
    try:
        uid = current_user["uid"]          # 🔒 from token
        year = request.args.get("year", type=int)

        if not year:
            return jsonify({"error": "year required"}), 400

        attempts_table, _, _ = resolve_tables(year)

        conn = get_db()
        cur = conn.cursor()

        cur.execute(
            f"""
            SELECT 1
            FROM {attempts_table}
            WHERE uid=%s AND quiz_date=%s
            """,
            (uid, today_ist())
        )

        exists = cur.fetchone()

        return jsonify({
            "attempted": bool(exists)
        }), 200

    except Exception as e:
        print("PROFILE STATUS ERROR:", repr(e))
        # Safe default: assume attempted to prevent duplicate quiz
        return jsonify({"attempted": True}), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


@app.route("/api/quiz/submit", methods=["POST", "OPTIONS"])
@token_required
def submit_quiz(current_user):

    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.json or {}

    uid = current_user["uid"]
    year = int(current_user["year"])
    answers = data.get("answers", [])
    time_taken = data.get("time_taken_seconds")

    if not answers:
        return jsonify({"error": "No answers submitted"}), 400

    attempts_table = f"daily_quiz_attempts_y{year}"
    bank_table = f"daily_quiz_questions_bank_y{year}"
    today = today_ist()

    conn = None
    cur = None

    try:
        conn = get_db()
        conn.begin()              # 🔴 IMPORTANT (disable autocommit for this txn)
        cur = conn.cursor(pymysql.cursors.DictCursor)

        quiz_id = data.get("quiz_id")
        if not quiz_id:
            # Find first started attempt for today
            cur.execute(
                f"SELECT quiz_id FROM {attempts_table} WHERE uid=%s AND quiz_date=%s AND status='started' LIMIT 1",
                (uid, today)
            )
            row = cur.fetchone()
            if row and row["quiz_id"]:
                quiz_id = row["quiz_id"]

        # -------------------------------------------------
        # 🔒 CHECK QUIZ STATUS (LOCK ROW)
        # -------------------------------------------------
        if quiz_id:
            cur.execute(
                f"""
                SELECT status
                FROM {attempts_table}
                WHERE uid=%s AND quiz_date=%s AND quiz_id=%s
                FOR UPDATE
                """,
                (uid, today, quiz_id)
            )
        else:
            cur.execute(
                f"""
                SELECT status
                FROM {attempts_table}
                WHERE uid=%s AND quiz_date=%s
                FOR UPDATE
                """,
                (uid, today)
            )
        attempt = cur.fetchone()

        if not attempt or attempt["status"] != "started":
            conn.rollback()
            return jsonify({"error": "Quiz already closed or not started"}), 409

        # -------------------------------------------------
        # FETCH CORRECT ANSWERS
        # -------------------------------------------------
        if quiz_id:
            cur.execute(
                f"""
                SELECT id, correct_answer
                FROM {bank_table}
                WHERE uid=%s AND quiz_date=%s AND quiz_id=%s
                """,
                (uid, today, quiz_id)
            )
        else:
            cur.execute(
                f"""
                SELECT id, correct_answer
                FROM {bank_table}
                WHERE uid=%s AND quiz_date=%s AND quiz_id IS NULL
                """,
                (uid, today)
            )

        rows = cur.fetchall()
        if not rows:
            conn.rollback()
            return jsonify({"error": "Quiz questions not found"}), 400

        correct_map = {r["id"]: r["correct_answer"] for r in rows}
        total_questions = len(correct_map)

        score = 0

        for a in answers:
            qid = a.get("question_id")
            selected = a.get("selected_answer")

            if not qid:
                continue

            qid = int(qid)

            cur.execute(
                f"""
                UPDATE {bank_table}
                SET student_answer=%s
                WHERE id=%s AND uid=%s AND quiz_date=%s
                """,
                (selected, qid, uid, today)
            )

            if selected and selected == correct_map.get(qid):
                score += 1

        # -------------------------------------------------
        # 🔐 FINAL SUBMIT
        # -------------------------------------------------
        if quiz_id:
            cur.execute(
                f"""
                UPDATE {attempts_table}
                SET score=%s,
                    total=%s,
                    time_taken_seconds=%s,
                    status='submitted'
                WHERE uid=%s AND quiz_date=%s AND quiz_id=%s
                """,
                (score, total_questions, time_taken, uid, today, quiz_id)
            )
            cur.execute("""
                DELETE FROM daily_quiz_autosave
                WHERE uid = %s AND quiz_date = %s AND quiz_id = %s
            """, (uid, today, quiz_id))
        else:
            cur.execute(
                f"""
                UPDATE {attempts_table}
                SET score=%s,
                    total=%s,
                    time_taken_seconds=%s,
                    status='submitted'
                WHERE uid=%s AND quiz_date=%s
                """,
                (score, total_questions, time_taken, uid, today)
            )
            cur.execute("""
                DELETE FROM daily_quiz_autosave
                WHERE uid = %s AND quiz_date = %s
            """, (uid, today))

        conn.commit()

        return jsonify({
            "success": True,
            "score": score,
            "total": total_questions
        }), 200

    except Exception as e:
        if conn:
            conn.rollback()
        print("SUBMIT QUIZ ERROR:", repr(e))
        return jsonify({"error": "Submission failed"}), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()



@app.route("/api/quiz/review", methods=["GET"])
@token_required
def quiz_review(current_user):
    conn = None
    cur = None
    try:
        uid = current_user["uid"]
        year = int(current_user["year"])

        bank_table = f"daily_quiz_questions_bank_y{year}"
        attempts_table = f"daily_quiz_attempts_y{year}"

        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        quiz_id = request.args.get("quiz_id", type=int)

        # 1️⃣ Get latest attempt matching quiz_id, or fallback to latest desc
        if quiz_id:
            cur.execute(
                f"""
                SELECT quiz_date, score, total, quiz_id
                FROM {attempts_table}
                WHERE uid=%s AND quiz_id=%s
                LIMIT 1
                """,
                (uid, quiz_id)
            )
        else:
            cur.execute(
                f"""
                SELECT quiz_date, score, total, quiz_id
                FROM {attempts_table}
                WHERE uid=%s
                ORDER BY quiz_date DESC, id DESC
                LIMIT 1
                """,
                (uid,)
            )
        attempt = cur.fetchone()

        if not attempt:
            return jsonify({
                "success": True,
                "score": 0,
                "total": 0,
                "answers": []
            }), 200

        quiz_date = attempt["quiz_date"]
        actual_quiz_id = attempt["quiz_id"]

        quiz_name = "AI Daily Quiz"
        subject = "Placement Preparation"
        department = current_user.get("branch") or "AI"
        start_time_str = ""
        end_time_str = ""

        if actual_quiz_id:
            topics_table = f"daily_quiz_topics_y{year}"
            cur.execute(
                f"SELECT topic, subject, department, created_by, quiz_start_time, quiz_end_time FROM {topics_table} WHERE id=%s",
                (actual_quiz_id,)
            )
            top_row = cur.fetchone()
            if top_row:
                quiz_name = top_row["topic"] or top_row["subject"] or f"Quiz #{actual_quiz_id}"
                subject = top_row["subject"] or top_row["topic"] or "Placement Preparation"
                if top_row.get("department"):
                    department = top_row["department"]
                creator = format_creator_name(top_row.get("created_by"), cur)
                start_time_str = format_time_to_str(top_row.get("quiz_start_time"))
                end_time_str = format_time_to_str(top_row.get("quiz_end_time"))

        # 2️⃣ Fetch Q + correct + student answers
        if actual_quiz_id:
            cur.execute(
                f"""
                SELECT
                    question_text AS question,
                    correct_answer,
                    student_answer
                FROM {bank_table}
                WHERE uid=%s AND quiz_date=%s AND (quiz_id=%s OR quiz_id IS NULL)
                ORDER BY id ASC
                """,
                (uid, quiz_date, actual_quiz_id)
            )
        else:
            cur.execute(
                f"""
                SELECT
                    question_text AS question,
                    correct_answer,
                    student_answer
                FROM {bank_table}
                WHERE uid=%s AND quiz_date=%s AND quiz_id IS NULL
                ORDER BY id ASC
                """,
                (uid, quiz_date)
            )

        rows = cur.fetchall()

        answers = [
            {
                "question": r["question"],
                "your_answer": r["student_answer"],
                "correct_answer": r["correct_answer"],
                "is_correct": r["student_answer"] == r["correct_answer"]
            }
            for r in rows
        ]

        return jsonify({
            "success": True,
            "quiz_name": quiz_name,
            "quiz_date": str(quiz_date),
            "start_time": start_time_str,
            "end_time": end_time_str,
            "department": department,
            "subject": subject,
            "created_by": creator,
            "score": attempt["score"],
            "total": attempt["total"],
            "answers": answers
        }), 200

    except Exception as e:
        print("QUIZ REVIEW ERROR:", repr(e))
        return jsonify({
            "success": False,
            "error": "Internal server error"
        }), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


##################################################################################################################
@app.route("/api/profile/marks_history", methods=["GET"])
@token_required
def marks_history(current_user):
    conn = None
    cur = None
    try:
        uid = current_user["uid"]
        student_year = int(current_user["year"])

        # Validate query params
        month = request.args.get("month", type=int)
        year_filter = request.args.get("year", type=int)

        if not month or not year_filter:
            return jsonify({
                "success": False,
                "error": "month and year are required"
            }), 400

        attempts_table = (
            f"daily_quiz_attempts_y{student_year}"
        )
        topics_table = (
            f"daily_quiz_topics_y{student_year}"
        )

        conn = get_db()
        cur = conn.cursor()

        cur.execute(
            f"""
            SELECT
                a.quiz_date, a.score, a.total, a.quiz_id,
                t.subject, t.topic, t.quiz_start_time, t.quiz_end_time,
                t.created_by, ad.name AS created_by_name
            FROM {attempts_table} a
            LEFT JOIN {topics_table} t ON t.id = a.quiz_id
            LEFT JOIN admins ad ON ad.email = t.created_by
            WHERE a.uid=%s
              AND MONTH(a.quiz_date)=%s
              AND YEAR(a.quiz_date)=%s
            ORDER BY a.quiz_date DESC
            """,
            (uid, month, year_filter)
        )

        rows = cur.fetchall()

        history = []
        total_scored = 0
        total_possible = 0

        for r in rows:
            total_scored += r["score"]
            total_possible += r["total"]
            organiser = r.get("created_by_name") or r.get("created_by") or "Admin"
            history.append({
                "quiz_date": r["quiz_date"].strftime("%Y-%m-%d"),
                "score": r["score"],
                "total": r["total"],
                "quiz_id": r.get("quiz_id"),
                "subject": r.get("subject"),
                "topic": r.get("topic"),
                "quiz_start_time": str(r["quiz_start_time"]) if r.get("quiz_start_time") is not None else "",
                "quiz_end_time": str(r["quiz_end_time"]) if r.get("quiz_end_time") is not None else "",
                "organised_by": organiser
            })

        return jsonify({
            "success": True,
            "history": history,
            "total_scored": total_scored,
            "total_possible": total_possible
        }), 200

    except Exception as e:
        print("MARKS HISTORY ERROR:", repr(e))
        return jsonify({
            "success": False,
            "error": "Internal server error"
        }), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


    

@app.route("/api/leaderboard", methods=["GET"])
@token_required
def leaderboard(current_user):
    conn = None
    cur = None
    try:
        year = int(current_user["year"])

        # IST current month & year
        ist = pytz.timezone("Asia/Kolkata")
        now = datetime.now(ist)
        current_month = now.month
        current_year = now.year

        attempts_table = (
            f"daily_quiz_attempts_y{year}"
        )
        marks_table = (
            f"assignment_quiz_marks_y{year}"
        )

        conn = get_db()
        cur = conn.cursor()

        cur.execute(
            f"""
            SELECT 
                s.name,
                SUM(combined.score) AS total_score
            FROM (
                SELECT uid, score, quiz_date FROM {attempts_table}
                UNION ALL
                SELECT uid, score, quiz_date FROM {marks_table}
            ) combined
            JOIN students s ON s.uid = combined.uid
            WHERE MONTH(combined.quiz_date)=%s
              AND YEAR(combined.quiz_date)=%s
            GROUP BY combined.uid, s.name
            ORDER BY total_score DESC
            LIMIT 10
            """,
            (current_month, current_year)
        )

        top10 = cur.fetchall()

        return jsonify({
            "success": True,
            "month": now.strftime("%B"),
            "top10": top10
        }), 200

    except Exception as e:
        print("LEADERBOARD ERROR:", repr(e))
        return jsonify({
            "success": False,
            "error": "Internal server error"
        }), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()






@app.route("/api/quiz/today/status", methods=["GET"])
@token_required
def today_quiz_status(current_user):
    conn = None
    cur = None
    try:
        uid = current_user["uid"]
        year = int(current_user["year"])

        attempts_table, _, _ = resolve_tables(year)
        topic_table = f"daily_quiz_topics_y{year}"
        today = today_ist()

        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        # Helper to format times
        def format_time_to_str(t):
            if not t:
                return "00:00:00"
            if isinstance(t, str):
                return t
            if isinstance(t, timedelta):
                return str(t)
            if type(t).__name__ == 'time':
                return t.strftime("%H:%M:%S")
            return str(t)

        # Fetch daily topic details for today, filtered by student's department
        branch = current_user.get("branch", "")
        cur.execute(
            f"SELECT id, title, subject, topic, difficulty, quiz_start_time, quiz_end_time, status, department FROM {topic_table} WHERE quiz_date=%s AND quiz_type='placement' AND (department=%s OR department='ALL' OR department IS NULL OR department='')",
            (today, branch)
        )
        topic_rows = cur.fetchall()

        quizzes = []
        now_time_str = datetime.now(IST).strftime("%H:%M:%S")
        for topic_row in topic_rows:
            end_time_str = format_time_to_str(topic_row["quiz_end_time"])
            if now_time_str > end_time_str:
                continue

            # Check if attempted
            cur.execute(
                f"SELECT status FROM {attempts_table} WHERE uid=%s AND quiz_date=%s AND quiz_id=%s",
                (uid, today, topic_row["id"])
            )
            attempt_row = cur.fetchone()
            attempted = False
            if attempt_row and attempt_row["status"] != "started":
                attempted = True

            quizzes.append({
                "id": topic_row["id"],
                "available": True,
                "attempted": attempted,
                "title": topic_row["title"],
                "subject": topic_row["subject"],
                "topic": topic_row["topic"],
                "difficulty": topic_row["difficulty"],
                "quiz_start_time": format_time_to_str(topic_row["quiz_start_time"]),
                "quiz_end_time": end_time_str,
                "status": topic_row["status"]
            })

        return jsonify({
            "available": len(quizzes) > 0,
            "quizzes": quizzes
        }), 200

    except Exception as e:
        return generic_error_response(e)

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()




#########################################################################################
# faculty quiz routes
#############################################################################################3

import pymysql

@app.route("/faculty_quiz", methods=["GET", "OPTIONS"])
@token_required
def faculty_quiz(current_user):

    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    conn = None
    cur = None
    try:
        uid = current_user["uid"]
        year = int(current_user["year"])
        quiz_id = request.args.get("quiz_id", type=int)

        if not quiz_id:
            return jsonify({
                "success": False,
                "message": "quiz_id required"
            }), 400

        marks_table = f"assignment_quiz_marks_y{year}"
        branch = current_user.get("branch", "")

        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        # 1️⃣ Check quiz exists (scoped to the student's own department)
        cur.execute(
            """
            SELECT quiz_id, quiz_name, quiz_date, quiz_start_time, quiz_end_time, duration_minutes
            FROM faculty_quiz_master
            WHERE quiz_id=%s AND year=%s AND department=%s
            """,
            (quiz_id, year, branch),
        )
        quiz = cur.fetchone()
        if not quiz:
            return jsonify({
                "success": False,
                "message": "Quiz not found"
            }), 404

        # 2️⃣ Check already attempted (final submission already exists)
        cur.execute(
            f"SELECT id FROM {marks_table} WHERE uid=%s AND quiz_id=%s",
            (uid, quiz_id),
        )
        if cur.fetchone():
            return jsonify({
                "success": True,
                "attempted": True
            }), 200

        # 3️⃣ Check/record the attempt's start time
        cur.execute(
            "SELECT started_at FROM faculty_quiz_attempts WHERE uid=%s AND quiz_id=%s",
            (uid, quiz_id),
        )
        attempt = cur.fetchone()

        now_ist = datetime.now(IST)
        now_naive = now_ist.replace(tzinfo=None)

        if not attempt:
            start_t = parse_time_field(quiz["quiz_start_time"])
            end_t = parse_time_field(quiz["quiz_end_time"])
            if start_t and now_ist < IST.localize(datetime.combine(quiz["quiz_date"], start_t)):
                return jsonify({"success": False, "message": f"Quiz starts at {start_t.strftime('%I:%M %p')}. Please try again then."}), 400
            if end_t and now_ist > IST.localize(datetime.combine(quiz["quiz_date"], end_t)):
                return jsonify({"success": False, "message": f"Quiz has ended at {end_t.strftime('%I:%M %p')}."}), 400

            cur.execute(
                "INSERT INTO faculty_quiz_attempts (uid, quiz_id, started_at) VALUES (%s, %s, %s)",
                (uid, quiz_id, now_naive.strftime("%Y-%m-%d %H:%M:%S")),
            )
            conn.commit()
            started_at = now_naive
        else:
            started_at = attempt["started_at"]
            if isinstance(started_at, str):
                try:
                    started_at = datetime.strptime(started_at, "%Y-%m-%d %H:%M:%S")
                except Exception:
                    started_at = now_naive
            elif isinstance(started_at, datetime) and started_at.tzinfo is not None:
                started_at = started_at.astimezone(IST).replace(tzinfo=None)

        elapsed = (now_naive - started_at).total_seconds()
        if elapsed < 0:
            elapsed = 0
        duration_secs = int(quiz["duration_minutes"]) * 60
        remaining_seconds = max(0, min(duration_secs, duration_secs - int(elapsed)))

        # 4️⃣ Fetch questions
        cur.execute(
            """
            SELECT id, question, option_a, option_b, option_c, option_d
            FROM faculty_quiz_questions_new
            WHERE quiz_id=%s
            ORDER BY id
            """,
            (quiz_id,),
        )
        rows = cur.fetchall()
        if not rows:
            return jsonify({
                "success": False,
                "message": "No questions found"
            }), 404

        # 5️⃣ Deterministic per-student shuffle - same seed always produces
        # the same order for this (uid, quiz_id), so a page refresh doesn't
        # reshuffle mid-attempt. No persistence needed.
        rng = random.Random(uid * 1_000_003 + quiz_id)
        rows = list(rows)
        rng.shuffle(rows)

        # 6️⃣ Merge in any autosaved answers for resume
        cur.execute(
            "SELECT question_id, selected_answer FROM faculty_quiz_autosave WHERE uid=%s AND quiz_id=%s",
            (uid, quiz_id),
        )
        autosave_map = {r["question_id"]: r["selected_answer"] for r in cur.fetchall()}

        questions = []
        for r in rows:
            opts = [("A", r["option_a"]), ("B", r["option_b"]), ("C", r["option_c"]), ("D", r["option_d"])]
            rng.shuffle(opts)
            questions.append({
                "question_id": r["id"],
                "question": r["question"],
                "options": [{"key": k, "text": v} for k, v in opts],
                "selected_answer": autosave_map.get(r["id"], "")
            })

        return jsonify({
            "success": True,
            "attempted": False,
            "quiz_id": quiz_id,
            "quiz_name": quiz["quiz_name"],
            "duration_minutes": quiz["duration_minutes"],
            "remaining_seconds": remaining_seconds,
            "questions": questions
        }), 200

    except Exception as e:
        print("FACULTY QUIZ ERROR:", repr(e))
        return jsonify({"error": "Internal server error"}), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


@app.route("/api/faculty_quiz/submit", methods=["POST"])
@token_required
def assignment_submit(current_user):

    conn = None
    cur = None
    try:
        uid = current_user["uid"]
        year = int(current_user["year"])

        data = request.json or {}
        answers = data.get("answers", [])
        quiz_id = data.get("quiz_id")

        if quiz_id is None:
            return jsonify({"error": "Quiz ID missing"}), 400

        today = today_ist()

        marks_table = (
            f"assignment_quiz_marks_y{year}"
        )

        conn = get_db()
        conn.begin()   # 🔒 force transaction
        cur = conn.cursor(pymysql.cursors.DictCursor)

        # 🔒 Prevent reattempt (LOCK)
        cur.execute(
            f"""
            SELECT id
            FROM {marks_table}
            WHERE uid=%s AND quiz_id=%s
            FOR UPDATE
            """,
            (uid, quiz_id),
        )

        if cur.fetchone():
            conn.rollback()
            return jsonify({"error": "Quiz already submitted"}), 409

        # 🔹 Fetch the quiz's real creator (previously hardcoded to "Admin")
        cur.execute(
            "SELECT created_by FROM faculty_quiz_master WHERE quiz_id=%s",
            (quiz_id,),
        )
        quiz_row = cur.fetchone()
        created_by = quiz_row["created_by"] if quiz_row and quiz_row.get("created_by") else "Admin"

        # 🔹 Fetch ALL correct answers for quiz
        cur.execute(
            """
            SELECT id, correct_option
            FROM faculty_quiz_questions_new
            WHERE quiz_id=%s
            """,
            (quiz_id,),
        )

        rows = cur.fetchall()
        total_questions = len(rows)

        correct_map = {r["id"]: r["correct_option"] for r in rows}

        score = 0

        # Ensure student answers table exists
        cur.execute("""
            CREATE TABLE IF NOT EXISTS faculty_quiz_student_answers (
                id INT AUTO_INCREMENT PRIMARY KEY,
                uid INT NOT NULL,
                quiz_id INT NOT NULL,
                question_id INT NOT NULL,
                selected_answer VARCHAR(255),
                UNIQUE KEY uk_std_q (uid, quiz_id, question_id)
            )
        """)

        for a in answers:
            qid = a.get("question_id")
            selected = a.get("selected_answer")

            if qid is None or selected is None:
                continue

            if correct_map.get(qid) == selected:
                score += 1

            cur.execute("""
                INSERT INTO faculty_quiz_student_answers (uid, quiz_id, question_id, selected_answer)
                VALUES (%s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE selected_answer = VALUES(selected_answer)
            """, (uid, quiz_id, qid, selected))

        # 🧾 Store attempt
        cur.execute(
            f"""
            INSERT INTO {marks_table}
            (uid, quiz_id, quiz_date, total_questions, score, created_by)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (uid, quiz_id, today, total_questions, score, created_by),
        )

        cur.execute(
            "UPDATE faculty_quiz_attempts SET status='submitted' WHERE uid=%s AND quiz_id=%s",
            (uid, quiz_id),
        )

        # Clear autosave entries on successful submission
        cur.execute(
            "DELETE FROM faculty_quiz_autosave WHERE uid = %s AND quiz_id = %s",
            (uid, quiz_id)
        )

        conn.commit()

        return jsonify({
            "success": True,
            "score": score,
            "total": total_questions
        }), 200

    except Exception as e:
        if conn:
            conn.rollback()
        print("FACULTY SUBMIT ERROR:", repr(e))
        return jsonify({"error": "Submission failed"}), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


@app.route("/api/faculty_quiz/review", methods=["GET", "OPTIONS"])
@token_required
def faculty_quiz_review(current_user):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    conn = None
    cur = None
    try:
        uid = current_user["uid"]
        year = int(current_user["year"])
        quiz_id = request.args.get("quiz_id", type=int)

        if not quiz_id:
            return jsonify({"success": False, "message": "quiz_id required"}), 400

        marks_table = f"assignment_quiz_marks_y{year}"

        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        # 1️⃣ Fetch quiz details
        cur.execute("""
            SELECT fqm.quiz_id, fqm.quiz_name, fqm.quiz_date, fqm.quiz_start_time, fqm.quiz_end_time, 
                   fqm.created_by, fqm.department AS subject, a.name AS creator_name, a.role AS creator_role
            FROM faculty_quiz_master fqm
            LEFT JOIN admins a ON a.email = fqm.created_by
            WHERE fqm.quiz_id=%s
        """, (quiz_id,))
        quiz = cur.fetchone()
        if not quiz:
            return jsonify({"success": False, "message": "Quiz not found"}), 404

        role = (quiz.get("creator_role") or "").lower()
        cname = (quiz.get("creator_name") or "").strip()
        if role in ["admin", "super_admin", "superadmin"] or not cname:
            creator_name = "Admin"
        elif cname.lower() in ["admin", "super admin", "administrator"]:
            creator_name = "Admin"
        else:
            creator_name = cname

        raw_dept = str(quiz.get("subject") or "AI").strip().upper()
        quiz_subject = BRANCH_TO_FULL_NAME.get(raw_dept, raw_dept)

        # 2️⃣ Fetch student attempt
        cur.execute(f"""
            SELECT score, total_questions, submitted_at
            FROM {marks_table}
            WHERE uid=%s AND quiz_id=%s
        """, (uid, quiz_id))
        attempt = cur.fetchone()
        if not attempt:
            return jsonify({"success": False, "message": "Quiz attempt not found"}), 404

        # 3️⃣ Check if quiz has ended (IST)
        now = datetime.now(IST)
        end_time_val = parse_time_field(quiz["quiz_end_time"])
        is_finished = True
        start_time_str = format_time_to_str(quiz["quiz_start_time"])
        end_time_str = format_time_to_str(quiz["quiz_end_time"])

        if end_time_val and quiz["quiz_date"]:
            end_datetime = IST.localize(datetime.combine(quiz["quiz_date"], end_time_val))
            if now < end_datetime:
                is_finished = False

        answers_hidden = not is_finished

        # 4️⃣ Fetch questions
        cur.execute("""
            SELECT id, question, option_a, option_b, option_c, option_d, correct_option
            FROM faculty_quiz_questions_new
            WHERE quiz_id=%s
            ORDER BY id
        """, (quiz_id,))
        questions = cur.fetchall()

        # 5️⃣ Fetch student's selected answers
        cur.execute("""
            SELECT question_id, selected_answer
            FROM faculty_quiz_student_answers
            WHERE uid=%s AND quiz_id=%s
        """, (uid, quiz_id))
        sa_rows = cur.fetchall()
        user_answers = {r["question_id"]: r["selected_answer"] for r in sa_rows}

        answers_list = []
        for q in questions:
            user_ans_raw = user_answers.get(q["id"])
            user_ans = str(user_ans_raw).strip() if user_ans_raw else "Not Answered"

            correct_opt_raw = q["correct_option"] if not answers_hidden else None

            def resolve_ans_text(opt):
                if not opt or opt == "Not Answered":
                    return "Not Answered"
                opt_key = str(opt).strip().upper()
                opt_map = {
                    "A": q.get("option_a"),
                    "B": q.get("option_b"),
                    "C": q.get("option_c"),
                    "D": q.get("option_d"),
                }
                if opt_key in opt_map and opt_map[opt_key]:
                    val = str(opt_map[opt_key]).strip()
                    if val.upper().startswith(f"{opt_key}.") or val.upper().startswith(f"{opt_key})"):
                        return val
                    return f"{opt_key}. {val}"
                return str(opt)

            your_answer_text = resolve_ans_text(user_ans)
            correct_answer_text = resolve_ans_text(correct_opt_raw) if correct_opt_raw else None
            is_correct = (user_ans.upper() == str(q["correct_option"]).strip().upper()) if not answers_hidden else None

            answers_list.append({
                "question": q["question"],
                "option_a": q["option_a"],
                "option_b": q["option_b"],
                "option_c": q["option_c"],
                "option_d": q["option_d"],
                "your_answer": your_answer_text,
                "correct_answer": correct_answer_text,
                "is_correct": is_correct
            })

        return jsonify({
            "success": True,
            "quiz_name": quiz["quiz_name"],
            "quiz_date": str(quiz["quiz_date"]),
            "start_time": start_time_str,
            "end_time": end_time_str,
            "subject": quiz_subject,
            "created_by": creator_name,
            "score": attempt["score"],
            "total": attempt["total_questions"],
            "answers_hidden": answers_hidden,
            "message": f"Answers will be available after quiz ends at {end_time_str}" if answers_hidden else "Quiz review available",
            "answers": answers_list
        }), 200

    except Exception as e:
        print("FACULTY QUIZ REVIEW ERROR:", repr(e))
        return jsonify({"success": False, "message": "Internal server error"}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()


@app.route("/api/faculty_quiz/autosave", methods=["POST", "OPTIONS"])
@token_required
def faculty_quiz_autosave(current_user):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.json or {}
    quiz_id = data.get("quiz_id")
    question_id = data.get("question_id")
    selected_answer = data.get("selected_answer")

    if not all([quiz_id, question_id, selected_answer]):
        return jsonify({"error": "quiz_id, question_id, and selected_answer are required"}), 400

    uid = current_user["uid"]

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO faculty_quiz_autosave (uid, quiz_id, question_id, selected_answer)
            VALUES (%s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE selected_answer = %s
        """, (uid, quiz_id, question_id, selected_answer, selected_answer))
        conn.commit()
        return jsonify({"success": True, "message": "Answer autosaved"}), 200
    except Exception as e:
        return generic_error_response(e)
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


@app.route("/api/profile/faculty_quiz/today", methods=["GET"])
@token_required
def faculty_quiz_today_marks(current_user):
    conn = None
    cur = None
    try:
        uid = current_user["uid"]
        year = int(current_user["year"])
        today = today_ist()

        quiz_table = "faculty_quiz_master"
        marks_table = (
            f"assignment_quiz_marks_y{year}"
        )

        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        cur.execute(
            f"""
            SELECT 
                SUM(m.score) AS total_score, 
                SUM(m.total_questions) AS total_questions, 
                MAX(m.submitted_at) AS last_submitted
            FROM {marks_table} m
            WHERE m.uid=%s AND m.quiz_date=%s
            """,
            (uid, today),
        )

        row = cur.fetchone()

        if not row or row["total_questions"] is None:
            return jsonify({
                "attempted": False,
                "score": 0,
                "total": 0,
                "message": "Faculty Quiz not attempted today"
            }), 200

        return jsonify({
            "attempted": True,
            "score": int(row["total_score"]),
            "total": int(row["total_questions"]),
            "submitted_at": str(row["last_submitted"]) if row["last_submitted"] else None
        }), 200

    except Exception as e:
        return generic_error_response(e)

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()



@app.route("/api/profile/faculty_quiz/history", methods=["GET"])
@token_required
def faculty_quiz_marks_history(current_user):
    conn = None
    cur = None
    try:
        uid = current_user["uid"]
        year = int(current_user["year"])

        marks_table = (
            f"assignment_quiz_marks_y{year}"
        )

        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        cur.execute(
            f"""
            SELECT
                m.quiz_id,
                m.quiz_date,
                m.score,
                m.total_questions,
                q.quiz_name,
                q.quiz_start_time,
                q.quiz_end_time,
                q.created_by AS quiz_created_by,
                a.name AS creator_name,
                a.role AS creator_role
            FROM {marks_table} m
            JOIN faculty_quiz_master q
                ON m.quiz_id = q.quiz_id
            LEFT JOIN admins a
                ON a.email = q.created_by
            WHERE m.uid = %s
            ORDER BY m.quiz_date DESC
            """,
            (uid,),
        )

        rows = cur.fetchall()

        history = []
        for r in rows:
            role = (r.get("creator_role") or "").lower()
            cname = (r.get("creator_name") or "").strip()
            if role in ["admin", "super_admin", "superadmin"] or not cname:
                creator = "Admin"
            elif cname.lower() in ["admin", "super admin", "administrator"]:
                creator = "Admin"
            else:
                creator = cname

            history.append({
                "quiz_id": r["quiz_id"],
                "quiz_name": r.get("quiz_name") or f"Faculty Quiz #{r['quiz_id']}",
                "quiz_date": r["quiz_date"].strftime("%Y-%m-%d"),
                "quiz_start_time": format_time_to_str(r.get("quiz_start_time")),
                "quiz_end_time": format_time_to_str(r.get("quiz_end_time")),
                "score": r["score"],
                "total_questions": r["total_questions"],
                "created_by": creator
            })

        return jsonify({
            "success": True,
            "history": history
        }), 200

    except Exception as e:
        print("FACULTY QUIZ HISTORY ERROR:", repr(e))
        return jsonify({
            "success": False,
            "error": "Internal server error"
        }), 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()



@app.route("/faculty_quiz/list", methods=["GET"])
@token_required
def faculty_quiz_list(current_user):
    conn = None
    cur = None
    try:
        uid = current_user["uid"]
        year = int(current_user["year"])
        today = today_ist()
        branch = current_user.get("branch", "")

        marks_table = (
            f"assignment_quiz_marks_y{year}"
        )

        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        cur.execute(
            """
            SELECT fqm.quiz_id, fqm.quiz_name, fqm.quiz_date, fqm.quiz_start_time,
                   fqm.quiz_end_time, fqm.created_by, a.name AS creator_name, a.role AS creator_role
            FROM faculty_quiz_master fqm
            LEFT JOIN admins a ON a.email = fqm.created_by
            WHERE fqm.quiz_date=%s AND fqm.year=%s AND fqm.department=%s
            ORDER BY fqm.quiz_start_time
            """,
            (today, year, branch),
        )

        quizzes = cur.fetchall()

        if not quizzes:
            return jsonify({
                "success": True,
                "count": 0,
                "quizzes": []
            }), 200

        quiz_ids = [q["quiz_id"] for q in quizzes]
        placeholders = ",".join(["%s"] * len(quiz_ids))

        cur.execute(
            f"""
            SELECT quiz_id, score, total_questions
            FROM {marks_table}
            WHERE uid=%s AND quiz_id IN ({placeholders})
            """,
            (uid, *quiz_ids),
        )

        attempted_map = {r["quiz_id"]: r for r in cur.fetchall()}

        def format_time(t):
            if not t:
                return "00:00:00"
            if isinstance(t, str):
                return t
            if isinstance(t, timedelta):
                return str(t)
            if type(t).__name__ == 'time':
                return t.strftime("%H:%M:%S")
            return str(t)

        now_time_str = datetime.now(IST).strftime("%H:%M:%S")

        result = []
        for q in quizzes:
            qid = q["quiz_id"]
            is_attempted = qid in attempted_map
            attempt_info = attempted_map.get(qid)

            if is_attempted or now_time_str <= format_time(q["quiz_end_time"]):
                role = (q.get("creator_role") or "").lower()
                cname = (q.get("creator_name") or "").strip()
                if role in ["admin", "super_admin", "superadmin"] or not cname:
                    creator = "Admin"
                elif cname.lower() in ["admin", "super admin", "administrator"]:
                    creator = "Admin"
                else:
                    creator = cname

                result.append({
                    "quiz_id": qid,
                    "quiz_name": q["quiz_name"],
                    "quiz_date": q["quiz_date"].strftime("%Y-%m-%d"),
                    "quiz_start_time": format_time_to_str(q["quiz_start_time"]),
                    "quiz_end_time": format_time_to_str(q["quiz_end_time"]),
                    "created_by": creator,
                    "attempted": is_attempted,
                    "score": attempt_info["score"] if attempt_info else None,
                    "total": attempt_info["total_questions"] if attempt_info else None
                })

        return jsonify({
            "success": True,
            "count": len(result),
            "quizzes": result
        }), 200

    except Exception as e:
        return generic_error_response(e)

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()





# Intermediate app.run removed. All routes register and start at the EOF block.







##########################################################################

# ============================================================
# ADMIN BACKEND - AUTH + DASHBOARD + FORGOT PASSWORD (OTP)
# ============================================================

# -------------------- BASIC IMPORTS -------------------------

from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from functools import wraps
from dotenv import load_dotenv
import pymysql
import jwt
import os
import uuid
import random
import requests
import os

from datetime import datetime, timedelta
import pytz
from db import get_db


# ============================================================
# LOAD ENV
# ============================================================


SECRET_KEY = os.getenv("SECRET_KEY")
SMTP_PASS = os.getenv("BREVO_SMTP_PASS")



if not SECRET_KEY:
    raise Exception("SECRET_KEY missing in .env")
if not SMTP_PASS:
    raise Exception("BREVO_SMTP_PASS missing in .env")

# ============================================================
# EMAIL CONFIG (BREVO)
# ============================================================
SMTP_SERVER = "smtp-relay.brevo.com"
SMTP_PORT = 587
SMTP_USER = "9da39b001@smtp-brevo.com"
FROM_EMAIL = "techpallotine@gmail.com"

BREVO_API_KEY = os.getenv("ADMIN_KEY") 


# ============================================================
# FLASK SETUP
# ============================================================


# ============================================================
# TIMEZONE + OTP CONFIG
# ============================================================
IST = pytz.timezone("Asia/Kolkata")

ADMIN_OTP_VALID_MINUTES = 5
admin_otp_store = {}
# 🔐 In-memory OTP store (temporary)
admin_login_otp_store = {}


from datetime import datetime
import pytz

IST = pytz.timezone("Asia/Kolkata")

def now_ist():
    return datetime.now(IST)

def dt_to_str(dt):
    if dt is None:
        return None
    return dt.astimezone(IST).strftime("%Y-%m-%d %H:%M:%S")


# ============================================================
# DATABASE CONNECTION
# ============================================================



# ============================================================
# JWT DECORATOR (ADMIN)
# ============================================================
def admin_token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):

        # allow OPTIONS preflight
        if request.method == "OPTIONS":
            return jsonify({"success": True}), 200

        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify({"error": "Token missing"}), 401

        token = auth.replace("Bearer ", "")

        db = None
        cur = None
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])

            if payload.get("type") != "admin":
                return jsonify({"error": "Invalid admin token"}), 403

            admin_uid = payload.get("admin_uid")

            db = get_db()
            cur = db.cursor(pymysql.cursors.DictCursor)

            cur.execute(
                "SELECT id, admin_uid, name, email, role, dept_id, faculty_id, is_active FROM admins WHERE admin_uid=%s AND is_active=1",
                (admin_uid,)
            )
            admin = cur.fetchone()

            if not admin:
                return jsonify({"error": "Admin not found"}), 401

        except jwt.ExpiredSignatureError:
            return jsonify({"error": "Token expired"}), 401
        except jwt.InvalidTokenError:
            return jsonify({"error": "Invalid token"}), 401

        finally:
            if cur:
                cur.close()
            if db:
                db.close()

        return f(admin, *args, **kwargs)

    return decorated


def role_required(*allowed_roles):
    """Decorator to restrict endpoints to specific roles. Use after @admin_token_required."""
    def decorator(f):
        @wraps(f)
        def decorated_function(admin, *args, **kwargs):
            if admin["role"] not in allowed_roles:
                return jsonify({"error": "Access denied. Insufficient permissions."}), 403
            return f(admin, *args, **kwargs)
        return decorated_function
    return decorator


BRANCH_TO_DEPT_ID = {
    "AI": 7,
    "DS": 8,
    "CSE": 2,
    "IT": 5,
    "ETC": 3,
    "MECH": 6,
    "CIVIL": 1,
    "EE": 4,
    "CS-CY": 10,
    "CSBS": 11,
    "IIOT": 9,
    "RAI": 12,
}
DEPT_ID_TO_BRANCH = {v: k for k, v in BRANCH_TO_DEPT_ID.items()}
BRANCH_TO_FULL_NAME = {
    "AI": "Artificial Intelligence",
    "DS": "Computer Science & Engineering (Data Science)",
    "CSE": "Computer Science & Engineering",
    "IT": "Information Technology",
    "ETC": "Electronics & Telecommunication",
    "MECH": "Mechanical Engineering",
    "CIVIL": "Civil Engineering",
    "EE": "Electrical Engineering",
    "CS-CY": "Computer Science & Engineering (Cyber Security)",
    "CSBS": "Computer Science & Business Systems",
    "IIOT": "Industrial Internet of Things",
    "RAI": "Robotics & Artificial Intelligence",
}


@app.route("/api/admin/departments/quiz-enabled", methods=["GET", "OPTIONS"])
@admin_token_required
def quiz_enabled_departments(admin):
    """Departments that BRANCH_TO_DEPT_ID actually maps to a student branch
    - i.e. the only choices that won't 400 with 'not yet configured' when
    picked on a quiz-creation form. `/api/admin/departments` lists every
    department for staff-management purposes, which is broader than this."""
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    dept_ids = list(DEPT_ID_TO_BRANCH.keys())
    if not dept_ids:
        return jsonify({"success": True, "departments": []}), 200

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        placeholders = ",".join(["%s"] * len(dept_ids))
        cur.execute(f"SELECT id, name FROM departments WHERE id IN ({placeholders}) ORDER BY name", dept_ids)
        return jsonify({"success": True, "departments": cur.fetchall()}), 200
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


def can_access_quiz(admin, created_by, cur):
    """Whether `admin` may view/manage a faculty-quiz created by `created_by`'s email."""
    if admin["role"] in ("super_admin", "admin"):
        return True
    if admin["role"] == "faculty":
        return created_by == admin["email"]
    if admin["role"] == "hod":
        cur.execute(
            "SELECT 1 FROM admins WHERE email=%s AND dept_id=%s AND role IN ('faculty','hod')",
            (created_by, admin["dept_id"])
        )
        return cur.fetchone() is not None
    return False


# ============================================================
# ADMIN SIGNUP removed: unauthenticated privileged-account creation.
# Use POST /api/admin/staff/create (role_required-gated) instead.
# ============================================================
@app.route("/api/admin/login", methods=["POST", "OPTIONS"])
def admin_login():
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200
    data = request.get_json(silent=True) or {}

    email = data.get("email")
    password = data.get("password")

    if not email or not password:
        return jsonify({"error": "Email and password required"}), 400

    db = get_db()
    cur = db.cursor(pymysql.cursors.DictCursor)

    cur.execute(
        """SELECT a.*, d.name as dept_name FROM admins a
           LEFT JOIN departments d ON a.dept_id = d.id
           WHERE a.email=%s AND a.is_active=1""",
        (email,)
    )
    admin = cur.fetchone()

    cur.close()
    db.close()

    if not admin:
        return jsonify({"error": "Admin not found"}), 401

    if not check_password_hash(admin["password_hash"], password):
        return jsonify({"error": "Invalid credentials"}), 401

    role = str(admin.get("role") or "").strip().upper()

    # 🔒 Admin (SUPER_ADMIN, ADMIN) & HOD logins require OTP
    if role in ("SUPER_ADMIN", "ADMIN", "HOD"):
        otp = generate_otp_admin()
        now_utc = datetime.utcnow()
        admin_login_otp_store[email] = {
            "otp": otp,
            "expires_at": now_utc + timedelta(minutes=5),
            "attempts": 0
        }
        send_otp_email(
            email, otp,
            name=admin["name"],
            designation=build_admin_designation(admin["role"], admin.get("dept_name")),
            purpose="login"
        )
        return jsonify({
            "success": True,
            "otp_required": True,
            "message": f"OTP sent to {email}"
        }), 200

    # 🟢 Faculty login: NO OTP required
    token = jwt.encode(
        {
            "admin_uid": admin["admin_uid"],
            "type": "admin",
            "role": admin["role"],
            "dept_id": admin["dept_id"],
            "faculty_id": admin["faculty_id"],
            "exp": datetime.utcnow() + timedelta(days=7)
        },
        SECRET_KEY,
        algorithm="HS256"
    )

    return jsonify({
        "success": True,
        "otp_required": False,
        "token": token,
        "admin": {
            "name": admin["name"],
            "email": admin["email"],
            "role": admin["role"],
            "dept_id": admin["dept_id"],
            "faculty_id": admin["faculty_id"],
            "dept_name": admin.get("dept_name") or ""
        }
    }), 200


@app.route("/api/admin/verify-login-otp", methods=["POST"])
def verify_admin_login_otp():
    data = request.get_json(silent=True) or {}

    email = data.get("email")
    otp = data.get("otp")

    if not email or not otp:
        return jsonify({"error": "Email and OTP required"}), 400

    record = admin_login_otp_store.get(email)

    if not record:
        return jsonify({"error": "OTP not found or expired"}), 400

    if datetime.utcnow() > record["expires_at"]:
        del admin_login_otp_store[email]
        return jsonify({"error": "OTP expired"}), 400

    if record.get("attempts", 0) >= MAX_ATTEMPTS:
        del admin_login_otp_store[email]
        return jsonify({"error": "Maximum attempts exceeded. Please log in again."}), 400

    record["attempts"] = record.get("attempts", 0) + 1

    if record["otp"] != otp:
        return jsonify({"error": "Invalid OTP"}), 400

    # 🔑 Fetch admin
    db = get_db()
    cur = db.cursor(pymysql.cursors.DictCursor)

    cur.execute(
        """SELECT a.admin_uid, a.name, a.email, a.role, a.dept_id, a.faculty_id,
                  d.name as dept_name
           FROM admins a
           LEFT JOIN departments d ON a.dept_id = d.id
           WHERE a.email=%s""",
        (email,)
    )
    admin = cur.fetchone()

    cur.close()
    db.close()

    # Remove OTP after success
    del admin_login_otp_store[email]

    # Issue JWT with role and dept_id
    token = jwt.encode(
        {
            "admin_uid": admin["admin_uid"],
            "type": "admin",
            "role": admin["role"],
            "dept_id": admin["dept_id"],
            "faculty_id": admin["faculty_id"],
            "exp": datetime.utcnow() + timedelta(days=7)
        },
        SECRET_KEY,
        algorithm="HS256"
    )

    return jsonify({
        "success": True,
        "token": token,
        "admin": {
            "name": admin["name"],
            "email": admin["email"],
            "role": admin["role"],
            "dept_id": admin["dept_id"],
            "faculty_id": admin["faculty_id"],
            "dept_name": admin.get("dept_name") or ""
        }
    }), 200






# ============================================================
# OTP HELPERS
# ============================================================
def generate_otp_admin():
    return str(random.randint(100000, 999999))

def load_html_template_admin(filename, **kwargs):
    template_path = os.path.join(
        os.path.dirname(__file__),
        "templates",
        filename
    )

    if not os.path.exists(template_path):
        raise FileNotFoundError(f"{filename} not found")

    with open(template_path, "r", encoding="utf-8") as f:
        html = f.read()

    # Replace placeholders {{key}}
    for key, value in kwargs.items():
        html = html.replace(f"{{{{{key}}}}}", str(value))

    return html



def build_admin_designation(role, dept_name=None):
    # e.g. "SUPER ADMIN", "ADMIN", or "HOD, ARTIFICIAL INTELLIGENCE"
    role_label = str(role or "").strip().upper().replace("_", " ")
    if role_label == "HOD" and dept_name:
        return f"HOD, {dept_name.upper()}"
    return role_label


def send_otp_email(email, otp, name="", designation="", purpose="login"):
    """
    Send OTP email using Brevo (Sendinblue) HTTP API
    Safe for Render / local / slow networks

    purpose: "login" (post-password login OTP) or "reset" (forgot-password
    OTP) - these are different actions and must not share copy/subject,
    otherwise a login OTP email reads as if the account's password is
    being reset.
    """

    BREVO_API_KEY = os.getenv("ADMIN_KEY")

    if not BREVO_API_KEY:
        print("ADMIN_KEY not set")
        return False

    if purpose == "reset":
        subject = "Skill Sphere Admin Portal — Password Reset OTP"
        action_text = "reset your Admin Portal password"
    else:
        subject = "Skill Sphere Admin Portal — Login OTP"
        action_text = "sign in to your Admin Portal account"

    html = load_html_template_admin(
        "admin_otp_template.html",
        otp=otp,
        year=datetime.now().year,
        name=name or "Administrator",
        designation=designation,
        action_text=action_text
    )

    url = "https://api.brevo.com/v3/smtp/email"

    headers = {
        "accept": "application/json",
        "api-key": BREVO_API_KEY,
        "content-type": "application/json",
    }

    payload = {
        "sender": {
            "name": "Skill Sphere Admin",
            "email": "techpallotine@gmail.com"  # must be verified
        },
        "to": [{"email": email}],
        "subject": subject,
        "htmlContent": html
    }

    try:
        response = requests.post(
            url,
            json=payload,
            headers=headers,
            timeout=10  # 🔥 CRITICAL FIX
        )

        if response.status_code != 201:
            print(
                "Brevo error:",
                response.status_code,
                response.text
            )
            return False

        return True

    except requests.exceptions.RequestException as e:
        # 🔥 NEVER crash login because of email delay
        print("Brevo timeout/network error:", str(e))
        return False

@app.route("/api/admin/resend_otp", methods=["POST"])
def admin_resend_otp():
    data = request.get_json() or {}
    email = data.get("email")

    if not email:
        return jsonify({"error": "Email required"}), 400

    db = None
    cur = None
    try:
        # 🔒 Check admin exists
        db = get_db()
        cur = db.cursor(pymysql.cursors.DictCursor)

        cur.execute(
            """SELECT a.admin_uid, a.name, a.role, d.name as dept_name
               FROM admins a
               LEFT JOIN departments d ON a.dept_id = d.id
               WHERE a.email=%s AND a.is_active=1""",
            (email,)
        )
        admin = cur.fetchone()

    finally:
        if cur:
            cur.close()
        if db:
            db.close()   # 🔥 return to pool

    if not admin:
        return jsonify({"error": "Admin email not found"}), 404

    # 🔄 Generate NEW OTP
    otp = generate_otp_admin()
    now_ist = datetime.now(IST)
    expires_at = now_ist + timedelta(minutes=ADMIN_OTP_VALID_MINUTES)

    # 🔥 Overwrite previous OTP (safe)
    admin_otp_store[email] = {
        "otp": otp,
        "expires_at": expires_at,
        "verified": False,
        "attempts": 0
    }

    send_otp_email(
        email, otp,
        name=admin["name"],
        designation=build_admin_designation(admin["role"], admin.get("dept_name")),
        purpose="reset"
    )

    return jsonify({
        "success": True,
        "message": "OTP resent successfully",
        "expires_in_minutes": ADMIN_OTP_VALID_MINUTES
    }), 200


# ============================================================
# FORGOT PASSWORD
# ============================================================
@app.route("/api/admin/forgot_password", methods=["POST"])
def admin_forgot_password():
    data = request.get_json() or {}
    email = data.get("email")

    if not email:
        return jsonify({"error": "Email required"}), 400

    db = get_db()
    cur = db.cursor(pymysql.cursors.DictCursor)
    cur.execute(
        """SELECT a.admin_uid, a.name, a.role, d.name as dept_name
           FROM admins a
           LEFT JOIN departments d ON a.dept_id = d.id
           WHERE a.email=%s AND a.is_active=1""",
        (email,)
    )
    admin = cur.fetchone()
    db.close()

    if not admin:
        return jsonify({"error": "Admin email not found"}), 404

    otp = generate_otp_admin()
    now_ist = datetime.now(IST)
    expires_at = now_ist + timedelta(minutes=ADMIN_OTP_VALID_MINUTES)

    admin_otp_store[email] = {
        "otp": otp,
        "expires_at": expires_at,
        "verified": False,
        "attempts": 0
    }

    send_otp_email(
        email, otp,
        name=admin["name"],
        designation=build_admin_designation(admin["role"], admin.get("dept_name")),
        purpose="reset"
    )

    return jsonify({"success": True, "message": "OTP sent"}), 200

# ============================================================
# VERIFY OTP
# ============================================================
@app.route("/api/admin/verify_otp", methods=["POST"])
def admin_verify_otp():
    data = request.get_json() or {}
    email = data.get("email")
    otp = data.get("otp")

    entry = admin_otp_store.get(email)
    if not entry:
        return jsonify({"error": "OTP not requested"}), 400

    if datetime.now(IST) > entry["expires_at"]:
        del admin_otp_store[email]
        return jsonify({"error": "OTP expired"}), 400

    if entry.get("attempts", 0) >= MAX_ATTEMPTS:
        del admin_otp_store[email]
        return jsonify({"error": "Maximum attempts exceeded. Please request a new OTP."}), 400

    entry["attempts"] = entry.get("attempts", 0) + 1

    if otp != entry["otp"]:
        return jsonify({"error": "Invalid OTP"}), 400

    entry["verified"] = True
    return jsonify({"success": True, "message": "OTP verified"}), 200

# ============================================================
# RESET PASSWORD
# ============================================================
@app.route("/api/admin/reset_password", methods=["POST"])
def admin_reset_password():
    data = request.get_json() or {}
    email = data.get("email")
    new_password = data.get("new_password")

    entry = admin_otp_store.get(email)
    if not entry or not entry.get("verified"):
        return jsonify({"error": "OTP not verified"}), 400

    is_valid, pw_msg = validate_password_strength(new_password)
    if not is_valid:
        return jsonify({"error": pw_msg}), 400

    hashed = generate_password_hash(new_password)

    db = None
    cur = None
    try:
        db = get_db()
        cur = db.cursor()

        cur.execute(
            "UPDATE admins SET password_hash=%s WHERE email=%s",
            (hashed, email)
        )

    finally:
        if cur:
            cur.close()
        if db:
            db.close()   # 🔥 return to pool

    del admin_otp_store[email]

    return jsonify({"success": True, "message": "Password reset successful"}), 200


# ============================================================
# RBAC: CURRENT USER PROFILE
# ============================================================
@app.route("/api/admin/me", methods=["GET", "OPTIONS"])
@admin_token_required
def admin_me(admin):
    return jsonify({
        "success": True,
        "user": {
            "id": admin["id"],
            "name": admin["name"],
            "email": admin["email"],
            "role": admin["role"],
            "dept_id": admin["dept_id"],
            "faculty_id": admin["faculty_id"]
        }
    }), 200


# ============================================================
# RBAC: DEPARTMENT MANAGEMENT (Super Admin only)
# ============================================================
@app.route("/api/admin/departments", methods=["GET", "OPTIONS"])
@admin_token_required
def list_departments(admin):
    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        cur.execute("SELECT id, name FROM departments ORDER BY name ASC")
        departments = cur.fetchall()
        return jsonify({"success": True, "departments": departments}), 200
    finally:
        if cur: cur.close()
        if conn: conn.close()


@app.route("/api/admin/department/create", methods=["POST", "OPTIONS"])
@admin_token_required
@role_required("super_admin")
def create_department(admin):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.get_json() or {}
    name = data.get("name", "").strip()

    if not name:
        return jsonify({"error": "Department name required"}), 400

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        cur.execute("SELECT id FROM departments WHERE name=%s", (name,))
        if cur.fetchone():
            return jsonify({"error": "Department already exists"}), 409

        cur.execute("INSERT INTO departments (name) VALUES (%s)", (name,))
        conn.commit()
        return jsonify({"success": True, "message": f"Department '{name}' created"}), 201
    finally:
        if cur: cur.close()
        if conn: conn.close()


@app.route("/api/admin/department/<int:dept_id>/delete", methods=["DELETE", "OPTIONS"])
@admin_token_required
@role_required("super_admin", "admin")
def delete_department(admin, dept_id):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("DELETE FROM departments WHERE id=%s", (dept_id,))
        conn.commit()
        return jsonify({"success": True, "message": "Department deleted"}), 200
    finally:
        if cur: cur.close()
        if conn: conn.close()


@app.route("/api/admin/department/<int:dept_id>/details", methods=["GET", "OPTIONS"])
@admin_token_required
def get_department_details(admin, dept_id):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    if admin["role"] == "faculty":
        return jsonify({"error": "Access denied. Insufficient permissions."}), 403
    if admin["role"] == "hod" and dept_id != admin["dept_id"]:
        return jsonify({"error": "Access denied. Insufficient permissions."}), 403

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        # 1. Fetch department name
        cur.execute("SELECT name FROM departments WHERE id=%s", (dept_id,))
        dept = cur.fetchone()
        if not dept:
            return jsonify({"error": "Department not found"}), 404

        # 2. Fetch all staff for this department, ordered HOD first, then name alphabetically
        cur.execute("""
            SELECT id, admin_uid, name, email, role, dept_id, faculty_id, is_active
            FROM admins
            WHERE dept_id = %s
            ORDER BY (role = 'hod') DESC, name ASC
        """, (dept_id,))
        staff_list = cur.fetchall()

        # 3. For each staff member, populate subjects and quizzes
        for s in staff_list:
            # Fetch subjects taught
            if s["faculty_id"]:
                cur.execute("""
                    SELECT subject_name, subject_code, year, type
                    FROM subjects
                    WHERE faculty_id = %s
                """, (s["faculty_id"],))
                s["subjects"] = cur.fetchall()
            else:
                s["subjects"] = []

            # Fetch quizzes created by email
            cur.execute("""
                SELECT quiz_id, quiz_date, year
                FROM faculty_quiz_master
                WHERE created_by = %s
            """, (s["email"],))
            s["quizzes"] = cur.fetchall()

        return jsonify({
            "success": True,
            "department_name": dept["name"],
            "staff": staff_list
        }), 200

    finally:
        if cur: cur.close()
        if conn: conn.close()


# ============================================================
# RBAC: STAFF MANAGEMENT (Create HOD/Faculty/SuperAdmin)
# ============================================================
@app.route("/api/admin/staff", methods=["GET", "OPTIONS"])
@admin_token_required
def list_staff(admin):
    """List staff accounts. Super Admin sees all, HOD sees faculty in their dept."""
    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        if admin["role"] in ["super_admin", "admin"]:
            cur.execute("""
                SELECT a.id, a.admin_uid, a.name, a.email, a.role, a.dept_id, a.is_active,
                       d.name as dept_name
                FROM admins a
                LEFT JOIN departments d ON a.dept_id = d.id
                ORDER BY a.role, a.name
            """)
        elif admin["role"] == "hod":
            cur.execute("""
                SELECT a.id, a.admin_uid, a.name, a.email, a.role, a.dept_id, a.is_active,
                       d.name as dept_name
                FROM admins a
                LEFT JOIN departments d ON a.dept_id = d.id
                WHERE a.dept_id = %s AND a.role = 'faculty'
                ORDER BY a.name
            """, (admin["dept_id"],))
        else:
            return jsonify({"success": True, "staff": []}), 200

        staff = cur.fetchall()
        return jsonify({"success": True, "staff": staff}), 200
    finally:
        if cur: cur.close()
        if conn: conn.close()


@app.route("/api/admin/staff/create", methods=["POST", "OPTIONS"])
@admin_token_required
@role_required("super_admin", "admin", "hod")
def create_staff(admin):
    """Create a new staff account.
    Super Admin can create: super_admin, admin, hod, faculty
    HOD can create: faculty (in their own department only)
    """
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.get_json() or {}
    name = data.get("name", "").strip()
    email = data.get("email", "").strip()
    password = data.get("password", "").strip()
    role = data.get("role", "").strip()
    dept_id = data.get("dept_id")

    if not name or not email or not password or not role:
        return jsonify({"error": "name, email, password, and role are required"}), 400

    valid_roles = ["super_admin", "admin", "hod", "faculty"]
    if role not in valid_roles:
        return jsonify({"error": f"Invalid role. Must be one of: {valid_roles}"}), 400

    is_valid, pw_msg = validate_password_strength(password)
    if not is_valid:
        return jsonify({"error": pw_msg}), 400

    # No one - not even an existing super_admin - may create another
    # super_admin account. This is a one-time, out-of-band role.
    if role == "super_admin":
        return jsonify({"error": "Creating additional super admin accounts is not allowed"}), 403

    # HOD can only create faculty in their own department
    if admin["role"] == "hod":
        if role != "faculty":
            return jsonify({"error": "HOD can only create faculty accounts"}), 403
        dept_id = admin["dept_id"]  # Force to HOD's own department

    # HOD and Faculty must have a dept_id
    if role in ["hod", "faculty"] and not dept_id:
        return jsonify({"error": "dept_id is required for HOD and Faculty roles"}), 400

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        # Check duplicate email
        cur.execute("SELECT id FROM admins WHERE email=%s", (email,))
        if cur.fetchone():
            return jsonify({"error": "Email already registered"}), 409

        # Enforce single HOD per department
        if role == 'hod':
            cur.execute("""
                SELECT id FROM admins 
                WHERE dept_id = %s AND role = 'hod' AND is_active = 1
            """, (dept_id,))
            if cur.fetchone():
                return jsonify({"error": "This department already has a Head of Department (HOD). Only one HOD is allowed per department."}), 400

        # Handle faculty and subject creation
        faculty_id = None
        if role == 'faculty':
            # Create entry in faculty table
            cur.execute("""
                INSERT INTO faculty (name, dept_id)
                VALUES (%s, %s)
            """, (name, dept_id))
            faculty_id = cur.lastrowid
            
            subject_name = data.get("subject_name", "").strip()
            subject_code = data.get("subject_code", "").strip()
            subject_year = data.get("subject_year", "2").strip()
            
            if subject_name:
                if not subject_code:
                    subject_code = "".join(x[0] for x in subject_name.split() if x).upper() + str(random.randint(100, 999))
                
                cur.execute("""
                    INSERT INTO subjects (subject_name, subject_code, faculty_id, dept_id, type, room, batch_required, hours, year, students, batches)
                    VALUES (%s, %s, %s, %s, 'theory', 'TBD', 'no', 3, %s, 60, 1)
                """, (subject_name, subject_code, faculty_id, dept_id, subject_year))

        new_uid = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO admins (admin_uid, name, email, password_hash, role, dept_id, faculty_id, is_active)
            VALUES (%s, %s, %s, %s, %s, %s, %s, 1)
        """, (new_uid, name, email, generate_password_hash(password), role, dept_id, faculty_id))
        conn.commit()

        return jsonify({
            "success": True,
            "message": f"{role.replace('_',' ').title()} account created for {name}",
            "admin_uid": new_uid
        }), 201
    finally:
        if cur: cur.close()
        if conn: conn.close()


@app.route("/api/admin/staff/<int:staff_id>/delete", methods=["DELETE", "OPTIONS"])
@admin_token_required
@role_required("super_admin", "admin", "hod")
def delete_staff(admin, staff_id):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor()
        # Prevent deleting yourself
        cur.execute("SELECT admin_uid, role, dept_id FROM admins WHERE id=%s", (staff_id,))
        row = cur.fetchone()
        if row and row["admin_uid"] == admin["admin_uid"]:
            return jsonify({"error": "Cannot delete your own account"}), 400

        if admin["role"] == "hod":
            if not row or row["role"] != "faculty" or row["dept_id"] != admin["dept_id"]:
                return jsonify({"error": "You can only remove faculty in your own department"}), 403

        cur.execute("UPDATE admins SET is_active=0 WHERE id=%s", (staff_id,))
        conn.commit()
        return jsonify({"success": True, "message": "Staff account deactivated"}), 200
    finally:
        if cur: cur.close()
        if conn: conn.close()


@app.route("/api/admin/staff/<int:staff_id>/activate", methods=["POST", "OPTIONS"])
@admin_token_required
@role_required("super_admin", "admin", "hod")
def activate_staff(admin, staff_id):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor()

        if admin["role"] == "hod":
            cur.execute("SELECT role, dept_id FROM admins WHERE id=%s", (staff_id,))
            row = cur.fetchone()
            if not row or row["role"] != "faculty" or row["dept_id"] != admin["dept_id"]:
                return jsonify({"error": "You can only activate faculty in your own department"}), 403

        cur.execute("UPDATE admins SET is_active=1 WHERE id=%s", (staff_id,))
        conn.commit()
        return jsonify({"success": True, "message": "Staff account activated"}), 200
    finally:
        if cur: cur.close()
        if conn: conn.close()


@app.route("/api/admin/staff/<int:staff_id>/update", methods=["POST", "OPTIONS"])
@admin_token_required
@role_required("super_admin", "admin", "hod")
def update_staff(admin, staff_id):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.get_json() or {}

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        cur.execute(
            "SELECT id, name, email, role, dept_id, faculty_id FROM admins WHERE id=%s",
            (staff_id,)
        )
        target = cur.fetchone()
        if not target:
            return jsonify({"error": "Staff not found"}), 404

        name = data.get("name", target["name"])
        email = data.get("email", target["email"])
        new_role = target["role"]
        dept_id = target["dept_id"]

        if admin["role"] == "hod":
            if target["role"] != "faculty" or target["dept_id"] != admin["dept_id"]:
                return jsonify({"error": "You can only modify faculty in your own department"}), 403
            if ("role" in data and data["role"] != target["role"]) or \
               ("dept_id" in data and data["dept_id"] != target["dept_id"]):
                return jsonify({"error": "HOD cannot change staff role or department"}), 400
        else:
            # super_admin / admin may change role/dept freely
            new_role = data.get("role", target["role"])
            dept_id = data.get("dept_id", target["dept_id"])

            if staff_id == admin["id"] and new_role != target["role"]:
                return jsonify({"error": "Cannot change your own role"}), 400

            # Same rule as staff creation: no promoting anyone to super_admin.
            if new_role == "super_admin" and target["role"] != "super_admin":
                return jsonify({"error": "Promoting an account to super admin is not allowed"}), 403

            if new_role in ("hod", "faculty") and not dept_id:
                return jsonify({"error": "dept_id is required for HOD and Faculty roles"}), 400

            if new_role == "hod":
                cur.execute("""
                    SELECT id FROM admins
                    WHERE dept_id=%s AND role='hod' AND is_active=1 AND id != %s
                """, (dept_id, staff_id))
                if cur.fetchone():
                    return jsonify({"error": "This department already has a Head of Department (HOD). Only one HOD is allowed per department."}), 400

        if email != target["email"]:
            cur.execute("SELECT id FROM admins WHERE email=%s AND id != %s", (email, staff_id))
            if cur.fetchone():
                return jsonify({"error": "Email already registered"}), 409

        conn.begin()
        cur.execute(
            "UPDATE admins SET name=%s, email=%s, role=%s, dept_id=%s WHERE id=%s",
            (name, email, new_role, dept_id, staff_id)
        )

        if target["faculty_id"] and (name != target["name"] or dept_id != target["dept_id"]):
            cur.execute(
                "UPDATE faculty SET name=%s, dept_id=%s WHERE id=%s",
                (name, dept_id, target["faculty_id"])
            )

        conn.commit()
        return jsonify({"success": True, "message": "Staff account updated"}), 200

    except Exception as e:
        if conn:
            conn.rollback()
        return generic_error_response(e)
    finally:
        if cur: cur.close()
        if conn: conn.close()


# ============================================================
# FETCH STUDENTS (Y2 / Y3)
# ============================================================
# ============================================================
# ADMIN : YEAR-WISE STUDENT LIST
# ============================================================

@app.route("/api/admin/students", methods=["GET", "OPTIONS"])
@admin_token_required
def get_students_yearwise(admin):

    year = request.args.get("year", type=int)
    # Optional — only meaningful for super_admin/admin, who can narrow the
    # registry to one department. hod/faculty are already forced to their
    # own dept_id below regardless of what's passed here.
    dept_id = request.args.get("dept_id", type=int)

    if year not in [1, 2, 3, 4]:
        return jsonify({
            "success": False,
            "message": "Invalid year"
        }), 400

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        if admin["role"] in ("hod", "faculty"):
            cur.execute(
                """
                SELECT uid, name, email, branch, dept_id
                FROM students
                WHERE year = %s AND dept_id = %s
                ORDER BY uid ASC
                """,
                (year, admin["dept_id"])
            )
        elif dept_id:
            cur.execute(
                """
                SELECT uid, name, email, branch, dept_id
                FROM students
                WHERE year = %s AND dept_id = %s
                ORDER BY uid ASC
                """,
                (year, dept_id)
            )
        else:
            cur.execute(
                """
                SELECT uid, name, email, branch, dept_id
                FROM students
                WHERE year = %s
                ORDER BY uid ASC
                """,
                (year,)
            )

        students = cur.fetchall()

        return jsonify({
            "success": True,
            "students": students
        }), 200

    except Exception as e:
        return generic_error_response(e)

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()   # 🔥 return to pool



@app.route("/api/admin/student/<uid>", methods=["GET", "OPTIONS"])
@admin_token_required
def get_single_student(admin, uid):

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        cur.execute(
            """
            SELECT uid, name, email, year, branch, dept_id
            FROM students
            WHERE uid = %s
            """,
            (uid,)
        )

        student = cur.fetchone()

        if not student:
            return jsonify({
                "success": False,
                "message": "Student not found"
            }), 404

        if admin["role"] in ("hod", "faculty") and student["dept_id"] != admin["dept_id"]:
            return jsonify({
                "success": False,
                "message": "Student not found"
            }), 404

        return jsonify({
            "success": True,
            "student": student
        }), 200

    except Exception as e:
        return generic_error_response(e)

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()   # 🔥 return to pool



@app.route("/api/admin/student/<uid>/delete", methods=["DELETE", "OPTIONS"])
@admin_token_required
@role_required("super_admin", "admin", "hod")
def delete_student(admin, uid):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    conn = None
    cur = None
    try:
        conn = get_db()
        conn.begin()
        cur = conn.cursor()

        if admin["role"] == "hod":
            cur.execute("SELECT dept_id FROM students WHERE uid = %s", (uid,))
            target = cur.fetchone()
            if not target or target["dept_id"] != admin["dept_id"]:
                conn.rollback()
                return jsonify({
                    "success": False,
                    "message": "Student not in your department"
                }), 403

        # 1. Delete daily quiz answers & attempts, and assignment quiz marks
        #    for every year (Y1-Y4)
        for y in (1, 2, 3, 4):
            cur.execute(f"""
                DELETE FROM daily_quiz_answers_y{y}
                WHERE attempt_id IN (SELECT id FROM daily_quiz_attempts_y{y} WHERE uid = %s)
            """, (uid,))
            cur.execute(f"DELETE FROM daily_quiz_attempts_y{y} WHERE uid = %s", (uid,))
            cur.execute(f"DELETE FROM assignment_quiz_marks_y{y} WHERE uid = %s", (uid,))

        # 4. Delete from branchquiz
        cur.execute("DELETE FROM branchquiz WHERE uid_number = %s", (uid,))

        # 5. Delete from quiz_results
        cur.execute("DELETE FROM quiz_results WHERE uid_number = %s", (uid,))

        # 6. Delete the student record
        cur.execute("DELETE FROM students WHERE uid = %s", (uid,))

        conn.commit()
        return jsonify({
            "success": True,
            "message": "Student and all associated records deleted successfully"
        }), 200

    except Exception as e:
        if conn:
            conn.rollback()
        return generic_error_response(e)
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


@app.route("/api/admin/student/<uid>/update", methods=["POST", "OPTIONS"])
@admin_token_required
@role_required("super_admin", "admin", "hod")
def update_student(admin, uid):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.get_json() or {}

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        cur.execute(
            "SELECT uid, name, email, branch, year, dept_id FROM students WHERE uid=%s",
            (uid,)
        )
        target = cur.fetchone()
        if not target:
            return jsonify({"success": False, "message": "Student not found"}), 404

        if "year" in data:
            try:
                requested_year = int(data["year"])
            except (TypeError, ValueError):
                return jsonify({"success": False, "message": "Invalid year"}), 400
            if requested_year not in (1, 2, 3, 4):
                return jsonify({"success": False, "message": "Invalid year"}), 400

        name = data.get("name", target["name"])
        email = data.get("email", target["email"])
        branch = target["branch"]
        year = target["year"]
        dept_id = target["dept_id"]

        if admin["role"] == "hod":
            if target["dept_id"] != admin["dept_id"]:
                return jsonify({"success": False, "message": "Student not in your department"}), 403
            if "branch" in data and data["branch"] != target["branch"]:
                return jsonify({"success": False, "message": "HOD cannot change a student's branch"}), 400
            # HOD may advance/correct a student's year within their own
            # department (e.g. end-of-year promotion) - branch/department
            # transfer still requires super_admin.
            year = data.get("year", target["year"])
        else:
            # super_admin / admin may change any field
            branch = data.get("branch", target["branch"])
            year = data.get("year", target["year"])
            if branch != target["branch"]:
                dept_id = BRANCH_TO_DEPT_ID.get(branch, target["dept_id"])

        if email != target["email"]:
            cur.execute("SELECT uid FROM students WHERE email=%s AND uid != %s", (email, uid))
            if cur.fetchone():
                return jsonify({"success": False, "message": "Email already registered"}), 409

        cur.execute(
            "UPDATE students SET name=%s, email=%s, branch=%s, year=%s, dept_id=%s WHERE uid=%s",
            (name, email, branch, year, dept_id, uid)
        )
        conn.commit()
        return jsonify({"success": True, "message": "Student updated"}), 200

    except Exception as e:
        if conn:
            conn.rollback()
        return generic_error_response(e)
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()



@app.route("/api/admin/daily-quiz/topic", methods=["POST", "OPTIONS"])
@admin_token_required
@role_required("super_admin", "admin", "hod", "faculty")
def insert_daily_quiz_topic(admin):

    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.get_json() or {}

    year = data.get("year")
    quiz_date = data.get("quiz_date")
    quiz_type = data.get("quiz_type")
    topic = data.get("topic")
    difficulty = data.get("difficulty")

    subject = data.get("subject", "")
    questions_per_student = data.get("questions_per_student", 10)
    duration_minutes = data.get("duration_minutes", 10)
    quiz_start_time = data.get("quiz_start_time", "00:00")
    quiz_end_time = data.get("quiz_end_time", "23:59")

    # Department resolution: hod/faculty are locked to their own
    # department regardless of client input; super_admin/admin must
    # explicitly pick one (no more silent "AI" default).
    if admin["role"] in ("hod", "faculty"):
        dept_id = admin["dept_id"]
    else:
        dept_id = data.get("dept_id")

    department = DEPT_ID_TO_BRANCH.get(dept_id)
    if not department:
        return jsonify({"error": "This department is not yet configured for daily quizzes"}), 400

    # 🔒 VALIDATIONS
    if year not in [1, 2, 3, 4]:
        return jsonify({"error": "Invalid year"}), 400

    if quiz_type not in ["placement", "technical"]:
        return jsonify({"error": "Invalid quiz type"}), 400

    if difficulty not in ["basic", "easy", "medium", "hard", "very hard"]:
        return jsonify({"error": "Invalid difficulty"}), 400

    if not quiz_date or not topic or not subject:
        return jsonify({"error": "Subject, Date and Topic are required"}), 400

    if not isinstance(questions_per_student, int) or not (1 <= questions_per_student <= DAILY_QUIZ_MAX_QUESTIONS):
        return jsonify({"error": f"Number of questions must be between 1 and {DAILY_QUIZ_MAX_QUESTIONS}"}), 400

    if not isinstance(duration_minutes, int) or not (1 <= duration_minutes <= DAILY_QUIZ_MAX_DURATION_MINUTES):
        return jsonify({"error": f"Time limit must be between 1 and {DAILY_QUIZ_MAX_DURATION_MINUTES} minutes"}), 400

    # 🔒 15 MINUTE BUFFER FOR PUBLISHING
    try:
        now_ist = datetime.now(IST)
        start_time_clean = quiz_start_time.split(" ")[0]
        if len(start_time_clean.split(":")) == 2:
            start_dt = datetime.strptime(f"{quiz_date} {start_time_clean}", "%Y-%m-%d %H:%M")
        else:
            start_dt = datetime.strptime(f"{quiz_date} {start_time_clean}", "%Y-%m-%d %H:%M:%S")
        start_dt = IST.localize(start_dt)
        if start_dt - now_ist < timedelta(minutes=15):
            return jsonify({"error": "Quiz start time must be at least 15 minutes in the future from now."}), 400
    except Exception as e:
        print("BUFFER CHECK ERROR:", e)

    table = f"daily_quiz_topics_y{year}"

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        # 🔒 CALC STUDENT COUNT
        student_count = 0
        try:
            cur.execute(
                "SELECT COUNT(*) as count FROM students WHERE branch=%s AND year=%s",
                (department, str(year))
            )
            student_count = cur.fetchone()["count"]
        except Exception as e:
            print("Error fetching student count:", e)

        # Dynamically set total_sets equal to student_count for that class/department
        total_sets = max(1, student_count)

        # 🔒 INSERT TOPIC
        # created_by is derived server-side from the authenticated caller
        # (never trust a client-supplied creator) so the Questions
        # Generated view can be scoped to "my quizzes only" below.
        cur.execute(f"""
            INSERT INTO {table}
            (subject, topic, department, difficulty, status, total_students,
             question_per_set, total_sets_required, generated_sets, generated_questions, failed_sets, quiz_date, total_questions, quiz_type,
             quiz_start_time, quiz_end_time, duration_minutes, created_by)
            VALUES (%s, %s, %s, %s, 'GENERATING', %s, %s, %s, 0, 0, 0, %s, %s, %s, %s, %s, %s, %s)
        """, (
            subject, topic, department, difficulty,
            student_count, questions_per_student, total_sets,
            quiz_date, questions_per_student, quiz_type,
            quiz_start_time, quiz_end_time, duration_minutes, admin["email"]
        ))
        quiz_id = cur.lastrowid
        conn.commit()

        # Clean up any existing queue/sets for this specific quiz_id
        cur.execute("DELETE FROM daily_quiz_generation_queue WHERE quiz_id = %s", (quiz_id,))
        cur.execute("DELETE FROM daily_quiz_sets WHERE quiz_id = %s", (quiz_id,))
        conn.commit()

        # Enqueue set generation jobs
        for set_num in range(1, total_sets + 1):
            cur.execute("""
                INSERT INTO daily_quiz_generation_queue (year, quiz_date, quiz_id, set_number, status)
                VALUES (%s, %s, %s, %s, 'PENDING')
            """, (year, quiz_date, quiz_id, set_num))
        conn.commit()

        # FCFS: If another quiz is generating, this one starts as QUEUED
        initial_status = 'GENERATING'
        if generation_lock.locked():
            initial_status = 'QUEUED'
            cur.execute(f"UPDATE {table} SET status = 'QUEUED' WHERE id = %s", (quiz_id,))
            conn.commit()

        # Spawn background worker thread (worker acquires generation_lock internally)
        import threading
        t = threading.Thread(
            target=run_daily_quiz_worker,
            args=(year, quiz_date, topic, difficulty, questions_per_student, quiz_id)
        )
        t.daemon = True
        t.start()

        return jsonify({
            "success": True,
            "message": "Daily Quiz Published Successfully. Generating sets..."
        }), 201

    except Exception as e:
        return generic_error_response(e)

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()   # 🔥 return to pool


@app.route("/api/admin/daily-quiz/topic/delete", methods=["POST", "OPTIONS"])
@admin_token_required
@role_required("super_admin", "admin", "hod", "faculty")
def delete_daily_quiz_topic(admin):

    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.get_json(silent=True) or {}

    year = data.get("year")
    quiz_date = data.get("quiz_date")
    quiz_id = data.get("quiz_id")

    if year not in [1, 2, 3, 4]:
        return jsonify({"error": "Invalid year"}), 400

    if not quiz_id and not quiz_date:
        return jsonify({"error": "quiz_id or quiz_date required"}), 400

    # Department resolution — same rule as creation: hod/faculty are
    # locked to their own department; super_admin/admin may scope to a
    # specific department (recommended when more than one department
    # has a quiz on the same date) or omit it to target all of them.
    if admin["role"] in ("hod", "faculty"):
        department = DEPT_ID_TO_BRANCH.get(admin["dept_id"])
        if not department:
            return jsonify({"error": "Your department is not yet configured for daily quizzes"}), 400
    else:
        dept_id = data.get("dept_id")
        department = DEPT_ID_TO_BRANCH.get(dept_id) if dept_id else None

    table = f"daily_quiz_topics_y{year}"

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        if quiz_id:
            if department:
                cur.execute(f"SELECT id FROM {table} WHERE id=%s AND department=%s", (quiz_id, department))
            else:
                cur.execute(f"SELECT id FROM {table} WHERE id=%s", (quiz_id,))
            match = cur.fetchone()
            if not match:
                return jsonify({"error": "No quiz found with this ID"}), 404
            target_ids = [match["id"]]
        else:
            if department:
                cur.execute(f"SELECT id FROM {table} WHERE quiz_date=%s AND department=%s", (quiz_date, department))
            else:
                cur.execute(f"SELECT id FROM {table} WHERE quiz_date=%s", (quiz_date,))
            matches = cur.fetchall()
            if not matches:
                return jsonify({"error": "No quiz found for this date"}), 404
            target_ids = [m["id"] for m in matches]

        # Cascade delete each matched quiz by id — scoping to specific
        # ids (rather than a bare year+date sweep) keeps deletion from
        # bleeding into other departments' quizzes on the same date.
        for tid in target_ids:
            cur.execute(f"DELETE FROM {table} WHERE id=%s", (tid,))
            cur.execute("DELETE FROM daily_quiz_questions_pregenerated WHERE quiz_id = %s", (tid,))
            cur.execute("DELETE FROM daily_quiz_generation_queue WHERE quiz_id = %s", (tid,))
            cur.execute("DELETE FROM daily_quiz_sets WHERE quiz_id = %s", (tid,))
            cur.execute("DELETE FROM daily_quiz_student_mapping WHERE quiz_id = %s", (tid,))
            cur.execute("DELETE FROM daily_quiz_autosave WHERE quiz_id = %s", (tid,))
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Quiz topic removed successfully"
        }), 200

    except Exception as e:
        return generic_error_response(e)

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()   # 🔥 return to pool



import csv
from io import TextIOWrapper

def jaccard_similarity(str1, str2):
    words1 = set(re.findall(r"\w+", str1.lower()))
    words2 = set(re.findall(r"\w+", str2.lower()))
    if not words1 or not words2:
        return 0.0
    intersection = words1.intersection(words2)
    union = words1.union(words2)
    return len(intersection) / len(union)

def is_duplicate_question(new_q_text, existing_qs):
    return False

def build_daily_mcq_prompt(topics, difficulty, set_number, num_questions):
    rand_seed = random.randint(10000, 99999)
    
    difficulties = ["basic", "easy", "medium", "hard", "very hard"]
    try:
        base_idx = difficulties.index(difficulty.lower())
    except ValueError:
        base_idx = 2
        
    shift = (set_number % 3) - 1  # Shifts: -1, 0, 1
    target_idx = max(0, min(len(difficulties) - 1, base_idx + shift))
    set_difficulty = difficulties[target_idx]
    
    difficulty_nuances = {
        "basic": [
            "very simple definition and fundamental direct questions",
            "elementary beginner conceptual questions",
            "straightforward fundamental recall questions requiring basic awareness"
        ],
        "easy": [
            "basic conceptual questions",
            "beginner-friendly simple questions",
            "fundamental core questions"
        ],
        "medium": [
            "moderate exam-style questions",
            "conceptual intermediate questions",
            "standard placement level questions"
        ],
        "hard": [
            "tricky and analytical questions",
            "advanced placement-style questions",
            "challenging conceptual questions"
        ],
        "very hard": [
            "extremely difficult trap-based questions",
            "complex industry-style problems",
            "highly competitive scenario-based questions"
        ]
    }
    
    nuance_list = difficulty_nuances.get(set_difficulty, difficulty_nuances["medium"])
    set_nuance = nuance_list[set_number % len(nuance_list)]
    
    return f"""
Act as an elite AI placement MCQ generator for engineering students.

Generate exactly {num_questions} multiple choice questions.

Topics strictly limited to:
{topics}

Target Difficulty Level: {set_difficulty.upper()}

Unique seed code to prevent duplicates: set-{set_number}-{rand_seed}

To ensure high diversity and uniqueness across sets, the questions in this set (set {set_number}) must be designed as: {set_nuance}.

Rules:
- One correct option only
- Options must be stored in option_a, option_b, option_c, option_d (without A or B prefixes)
- Correct answer must be A, B, C, or D
- No explanations
- Questions must strictly match the difficulty level:
  * BASIC: Extremely simple, direct definition and elementary recall questions suitable for absolute beginners.
  * EASY: Fundamental conceptual questions requiring basic understanding.
  * MEDIUM: Standard placement level conceptual and application questions.
  * HARD: Tricky, analytical, and advanced placement-style questions.
  * VERY HARD: Expert-level complex scenarios, trap-based edge cases, and industry problems.
- Avoid repetition or cliché questions; make them fresh and accurate.
- Output STRICT JSON ONLY

Format:
[
  {{
    "question": "string",
    "option_a": "string",
    "option_b": "string",
    "option_c": "string",
    "option_d": "string",
    "answer": "A"
  }}
]
"""

def generate_daily_set_mcqs(year, quiz_date, set_number, topics, difficulty, num_questions, existing_questions):
    prompt = build_daily_mcq_prompt(topics, difficulty, set_number, num_questions)
    
    shuffled_keys = list(GEMINI_KEYS)
    random.shuffle(shuffled_keys)
    
    last_error = None
    for key in shuffled_keys:
        try:
            client_opts = ClientOptions(api_key=key)
            my_client = glm.GenerativeServiceClient(client_options=client_opts)
            
            model_name = "gemma-4-31b-it"
            model = genai.GenerativeModel(model_name)
            model._client = my_client
            
            response = model.generate_content(
                prompt,
                generation_config={"temperature": 0.95, "top_p": 0.95}
            )
            
            questions = None
            raw = response.text
            search_start = 0
            while True:
                idx = raw.find("[", search_start)
                if idx == -1:
                    break
                try:
                    decoder = json.JSONDecoder()
                    parsed, end = decoder.raw_decode(raw[idx:])
                    if isinstance(parsed, list) and len(parsed) == num_questions:
                        if all(all(k in q for k in ["question", "option_a", "option_b", "option_c", "option_d", "answer"]) for q in parsed):
                            questions = parsed
                            break
                except (json.JSONDecodeError, ValueError):
                    pass
                search_start = idx + 1
                
            if questions is None:
                text = re.sub(r"```json|```", "", raw.strip())
                try:
                    parsed = json.loads(text)
                    if isinstance(parsed, list) and len(parsed) == num_questions:
                        questions = parsed
                except:
                    pass
                    
            if not questions or len(questions) != num_questions:
                raise Exception(f"Invalid AI format response (parsed {len(questions) if questions else 0} questions)")
                
            valid_questions = []
            for q in questions:
                q_text = q["question"]
                if is_duplicate_question(q_text, existing_questions + [vq["question"] for vq in valid_questions]):
                    raise Exception("Duplicate question detected across sets")
                valid_questions.append(q)
                
            return valid_questions
            
        except Exception as e:
            last_error = e
            print(f"Daily Set {set_number} generation failed with key {key[:10]}...: {e}")
            cooldown = 10 if ("429" in str(e) or "quota" in str(e).lower()) else 4
            time.sleep(cooldown)
            
    raise Exception(f"All keys exhausted for Daily Set {set_number}. Last error: {last_error}")

def run_daily_set_generation_worker(year, quiz_date, set_number, topics, difficulty, num_questions, quiz_id=None):
    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        
        if quiz_id:
            queue_where = "quiz_id = %s"
            queue_params = (quiz_id, set_number)
        else:
            queue_where = "year = %s AND quiz_date = %s"
            queue_params = (year, quiz_date, set_number)

        cur.execute(f"""
            UPDATE daily_quiz_generation_queue 
            SET status = 'PROCESSING', attempts = attempts + 1
            WHERE {queue_where} AND set_number = %s
        """, queue_params)
        conn.commit()
        
        if quiz_id:
            cur.execute("""
                SELECT question FROM daily_quiz_questions_pregenerated 
                WHERE quiz_id = %s
            """, (quiz_id,))
        else:
            cur.execute("""
                SELECT question FROM daily_quiz_questions_pregenerated 
                WHERE year = %s AND quiz_date = %s
            """, (year, quiz_date))
        existing_questions = [r["question"] for r in cur.fetchall()]
        cur.close()
        conn.close()
        
        questions = generate_daily_set_mcqs(year, quiz_date, set_number, topics, difficulty, num_questions, existing_questions)
        
        conn = get_db()
        conn.begin()
        cur = conn.cursor()
        
        for q in questions:
            cur.execute("""
                INSERT INTO daily_quiz_questions_pregenerated 
                (year, quiz_date, quiz_id, set_number, question, option_a, option_b, option_c, option_d, correct_option)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                year, quiz_date, quiz_id, set_number, q["question"], 
                q["option_a"], q["option_b"], q["option_c"], q["option_d"],
                q["answer"]
            ))
            
        cur.execute("""
            INSERT INTO daily_quiz_sets (year, quiz_date, quiz_id, set_number, status)
            VALUES (%s, %s, %s, %s, 'AVAILABLE')
        """, (year, quiz_date, quiz_id, set_number))
        
        cur.execute(f"""
            UPDATE daily_quiz_generation_queue
            SET status = 'COMPLETED'
            WHERE {queue_where} AND set_number = %s
        """, queue_params)
        
        table = f"daily_quiz_topics_y{year}"
        if quiz_id:
            cur.execute(f"""
                UPDATE {table} 
                SET generated_sets = generated_sets + 1,
                    generated_questions = generated_questions + %s
                WHERE id = %s
            """, (num_questions, quiz_id))
        else:
            cur.execute(f"""
                UPDATE {table} 
                SET generated_sets = generated_sets + 1,
                    generated_questions = generated_questions + %s
                WHERE quiz_date = %s
            """, (num_questions, quiz_date))
        
        conn.commit()
        cur.close()
        conn.close()
        print(f"Daily Set {set_number} for Year {year} Date {quiz_date} generated successfully.")
        return True
        
    except Exception as e:
        print(f"Error processing Daily Set {set_number}: {e}")
        try:
            conn = get_db()
            cur = conn.cursor(pymysql.cursors.DictCursor)
            
            if quiz_id:
                cur.execute("""
                    SELECT attempts FROM daily_quiz_generation_queue 
                    WHERE quiz_id = %s AND set_number = %s
                """, (quiz_id, set_number))
            else:
                cur.execute("""
                    SELECT attempts FROM daily_quiz_generation_queue 
                    WHERE year = %s AND quiz_date = %s AND set_number = %s
                """, (year, quiz_date, set_number))
            row = cur.fetchone()
            attempts = row["attempts"] if row else 1
            
            if attempts >= 3:
                status_to_set = 'FAILED'
                table = f"daily_quiz_topics_y{year}"
                if quiz_id:
                    cur.execute(f"""
                        UPDATE {table} 
                        SET failed_sets = failed_sets + 1
                        WHERE id = %s
                    """, (quiz_id,))
                else:
                    cur.execute(f"""
                        UPDATE {table} 
                        SET failed_sets = failed_sets + 1
                        WHERE quiz_date = %s
                    """, (quiz_date,))
            else:
                status_to_set = 'PENDING'
                
            cur.execute(f"""
                UPDATE daily_quiz_generation_queue 
                SET status = %s, error_message = %s
                WHERE {queue_where} AND set_number = %s
            """, (status_to_set, str(e)) + queue_params)
            conn.commit()
            cur.close()
            conn.close()
        except Exception as db_ex:
            print("Failed to save daily error status:", db_ex)
        return False

import threading
queue_lock = threading.Lock()
generation_lock = threading.Lock()

def pop_pending_set(year, quiz_date, quiz_id=None):
    with queue_lock:
        conn = None
        cur = None
        try:
            conn = get_db()
            cur = conn.cursor(pymysql.cursors.DictCursor)
            if quiz_id:
                cur.execute("""
                    SELECT set_number FROM daily_quiz_generation_queue 
                    WHERE quiz_id = %s AND status = 'PENDING'
                    ORDER BY set_number ASC
                    LIMIT 1
                """, (quiz_id,))
            else:
                cur.execute("""
                    SELECT set_number FROM daily_quiz_generation_queue 
                    WHERE year = %s AND quiz_date = %s AND status = 'PENDING'
                    ORDER BY set_number ASC
                    LIMIT 1
                """, (year, quiz_date))
            row = cur.fetchone()
            if not row:
                cur.close()
                conn.close()
                return None
            
            set_number = row["set_number"]
            if quiz_id:
                cur.execute("""
                    UPDATE daily_quiz_generation_queue 
                    SET status = 'PROCESSING'
                    WHERE quiz_id = %s AND set_number = %s
                """, (quiz_id, set_number))
            else:
                cur.execute("""
                    UPDATE daily_quiz_generation_queue 
                    SET status = 'PROCESSING'
                    WHERE year = %s AND quiz_date = %s AND set_number = %s
                """, (year, quiz_date, set_number))
            conn.commit()
            cur.close()
            conn.close()
            return set_number
        except Exception as e:
            print("[pop_pending_set] Error:", e)
            if conn:
                conn.rollback()
            return None

def thread_worker_func(year, quiz_date, topics, difficulty, num_questions, quiz_id=None):
    while True:
        set_number = pop_pending_set(year, quiz_date, quiz_id)
        if set_number is None:
            break
        try:
            run_daily_set_generation_worker(year, quiz_date, set_number, topics, difficulty, num_questions, quiz_id)
        except Exception as e:
            print(f"[Thread Worker] Error on set {set_number}:", e)

def run_daily_quiz_worker(year, quiz_date, topics, difficulty, num_questions, quiz_id=None):
    # FCFS: acquire generation_lock so only one quiz generates at a time
    with generation_lock:
        # Update status from QUEUED to GENERATING now that we have the lock
        try:
            conn_status = get_db()
            cur_status = conn_status.cursor()
            table = f"daily_quiz_topics_y{year}"
            if quiz_id:
                cur_status.execute(f"UPDATE {table} SET status = 'GENERATING' WHERE id = %s AND status = 'QUEUED'", (quiz_id,))
            conn_status.commit()
            cur_status.close()
            conn_status.close()
        except Exception as e:
            print(f"[Daily Worker] Failed to update status to GENERATING: {e}")

        print(f"[Daily Worker] Starting background generation with 18 threads for Year {year} Date {quiz_date} Quiz ID {quiz_id}...")
        time.sleep(1)
        
        threads = []
        for i in range(18):
            t = threading.Thread(
                target=thread_worker_func,
                args=(year, quiz_date, topics, difficulty, num_questions, quiz_id)
            )
            t.start()
            threads.append(t)
            time.sleep(0.1)
            
        for t in threads:
            t.join()
            
        print(f"[Daily Worker] All 18 threads finished for Year {year} Date {quiz_date} Quiz ID {quiz_id}.")
            
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        table = f"daily_quiz_topics_y{year}"
        
        if quiz_id:
            cur.execute(f"""
                SELECT total_sets_required, generated_sets, failed_sets
                FROM {table} 
                WHERE id = %s
            """, (quiz_id,))
        else:
            cur.execute(f"""
                SELECT total_sets_required, generated_sets, failed_sets
                FROM {table} 
                WHERE quiz_date = %s
            """, (quiz_date,))
            
        master = cur.fetchone()
        
        if master:
            if master["generated_sets"] + master["failed_sets"] >= master["total_sets_required"]:
                final_status = 'READY' if master["failed_sets"] == 0 else 'FAILED'
                if quiz_id:
                    cur.execute(f"""
                        UPDATE {table} 
                        SET status = %s
                        WHERE id = %s
                    """, (final_status, quiz_id))
                else:
                    cur.execute(f"""
                        UPDATE {table} 
                        SET status = %s
                        WHERE quiz_date = %s
                    """, (final_status, quiz_date))
                conn.commit()
                print(f"[Daily Worker] Daily Quiz finished. Final Status: {final_status}")
        cur.close()
        conn.close()
    except Exception as e:
        print("[Daily Worker] Failed to update final status:", e)


def recover_interrupted_daily_quizzes():
    # On startup, resume any daily quiz left QUEUED or GENERATING when the
    # server last stopped (dev restart, crash, deploy). The per-set queue
    # is durable (DB-backed), but a thread killed by a process restart
    # leaves its claimed set stuck at PROCESSING forever - pop_pending_set
    # only ever picks up PENDING rows, so without this those sets (and the
    # whole quiz) would just hang at whatever count they were on. This is a
    # fresh process start, so any PROCESSING row here is guaranteed
    # orphaned - safe to reclaim and re-run.
    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        for year in (1, 2, 3, 4):
            table = f"daily_quiz_topics_y{year}"
            cur.execute(f"""
                SELECT id, quiz_date, topic, difficulty, question_per_set
                FROM {table}
                WHERE status IN ('QUEUED', 'GENERATING')
            """)
            stuck = cur.fetchall()
            for row in stuck:
                quiz_id = row["id"]
                cur.execute("""
                    UPDATE daily_quiz_generation_queue
                    SET status = 'PENDING'
                    WHERE quiz_id = %s AND status = 'PROCESSING'
                """, (quiz_id,))
                conn.commit()

                print(f"[Recovery] Resuming daily quiz id={quiz_id} (year={year}, date={row['quiz_date']})")
                t = threading.Thread(
                    target=run_daily_quiz_worker,
                    args=(year, row["quiz_date"], row["topic"], row["difficulty"], row["question_per_set"], quiz_id)
                )
                t.daemon = True
                t.start()
    except Exception as e:
        print("[Recovery] Failed to recover interrupted daily quizzes:", e)
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


# ============================================================
# DAILY QUIZ MAINTENANCE: CSV report emailing + storage cleanup
# ============================================================
#
# We're on Render's free tier, which sleeps the whole process after ~15
# minutes of no HTTP traffic - any thread, timer, or scheduled job dies
# right along with it. So none of this can be "wait until end_time, then
# fire" or "sleep N hours, then purge" - anything time-based like that
# is silently lost the moment the dyno sleeps.
#
# Instead everything here is a wall-clock comparison ("is this quiz's
# end_time already in the past?", "is this quiz_date more than 2 days
# ago?") re-checked opportunistically: once at process startup, and again
# on a throttle whenever any real request comes in (which is also exactly
# what wakes the dyno back up). Whatever became due while we were asleep
# just gets caught on the next check - nothing needs to fire at an exact
# moment.

# Same palette/text as the admin app's Full Class Report PDF
# (admin_app/lib/daily_quiz_full_class_page.dart generatePdf()) so the
# emailed report looks identical to the one the app itself can export.
_PDF_NAVY = colors.HexColor("#1E293B")
_PDF_LIGHT_BG = colors.HexColor("#F8FAFC")
_PDF_BORDER_GREY = colors.HexColor("#E2E8F0")
_PDF_BLUE = colors.HexColor("#2563EB")
_PDF_TEXT_DARK = colors.HexColor("#0F172A")
_PDF_GREY400 = colors.HexColor("#BDBDBD")
_PDF_GREY600 = colors.HexColor("#757575")
_PDF_GREY700 = colors.HexColor("#616161")
_PDF_GREY300 = colors.HexColor("#E0E0E0")
_PDF_AMBER300 = colors.HexColor("#FFD54F")

# Mirrors resolveDepartmentName() in daily_quiz_full_class_page.dart exactly,
# so "AI" in the DB renders as the same full name the app shows.
_PDF_DEPT_FULL_NAMES = {
    "AI": "Artificial Intelligence",
    "DS": "Computer Science & Engineering (Data Science)",
    "CSE": "Computer Science & Engineering",
    "IT": "Information Technology",
    "ETC": "Electronics & Telecommunication",
    "MECH": "Mechanical Engineering",
    "CIVIL": "Civil Engineering",
    "EE": "Electrical Engineering",
    "CS-CY": "Computer Science & Engineering (Cyber Security)",
    "CSBS": "Computer Science & Business Systems",
    "IIOT": "Industrial Internet of Things",
    "RAI": "Robotics & Artificial Intelligence",
}


def _pdf_resolve_dept_name(code):
    if not code or not str(code).strip():
        return "Artificial Intelligence"
    return _PDF_DEPT_FULL_NAMES.get(str(code).strip().upper(), code)


class _ReportCanvas(canvas.Canvas):
    # Two-pass canvas so the footer can show "Page X of Y" - reportlab only
    # knows the total page count once every page has already been drawn.
    def __init__(self, *args, **kwargs):
        self._report_meta = kwargs.pop("report_meta")
        canvas.Canvas.__init__(self, *args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        total_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self._draw_chrome(total_pages)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

    def _draw_chrome(self, total_pages):
        meta = self._report_meta
        page_w, page_h = A4
        margin = 16 * mm
        self.saveState()

        header_h = 15 * mm
        header_y = page_h - margin - header_h
        self.setFillColor(_PDF_NAVY)
        self.roundRect(margin, header_y, page_w - 2 * margin, header_h, 4, fill=1, stroke=0)
        self.setFillColor(colors.white)
        self.setFont("Helvetica-Bold", 12)
        self.drawString(margin + 10, header_y + header_h - 17, meta["title"])
        self.setFillColor(_PDF_GREY400)
        self.setFont("Helvetica", 8)
        self.drawString(margin + 10, header_y + 6, meta["subtitle"])
        self.setFillColor(_PDF_AMBER300)
        self.setFont("Helvetica-Bold", 8)
        self.drawRightString(page_w - margin - 10, header_y + header_h / 2 - 3, f"Generated: {meta['generated']}")

        self.setStrokeColor(_PDF_GREY300)
        self.setLineWidth(0.5)
        self.line(margin, margin, page_w - margin, margin)
        self.setFillColor(_PDF_GREY600)
        self.setFont("Helvetica", 7)
        self.drawString(margin, margin - 12, "Skill Sphere Official Analytics")
        self.drawRightString(page_w - margin, margin - 12, f"Page {self._pageNumber} of {total_pages}")

        self.restoreState()


def build_marks_pdf(quiz, quiz_id, marks_rows):
    # Mirrors admin_app/lib/daily_quiz_full_class_page.dart's generatePdf()
    # layout/colors exactly: dark navy header bar, light metadata card,
    # dark-header marks table, footer with page count.
    buf = io.BytesIO()

    generated_dt = datetime.now(IST)
    generated_str = generated_dt.strftime("%d-%m-%Y  %H:%M")
    meta = {
        "title": "SKILL SPHERE - AI DAILY QUIZ CLASS REPORT",
        "subtitle": "Full Class Daily Target Analytics",
        "generated": generated_str,
    }

    doc = SimpleDocTemplate(
        buf, pagesize=A4,
        topMargin=16 * mm + 15 * mm + 6 * mm,
        bottomMargin=16 * mm + 10 * mm,
        leftMargin=16 * mm, rightMargin=16 * mm
    )

    styles = getSampleStyleSheet()
    dept_style = ParagraphStyle("Dept", parent=styles["Normal"], fontSize=11, fontName="Helvetica-Bold", textColor=_PDF_TEXT_DARK, spaceAfter=3)
    topic_style = ParagraphStyle("Topic", parent=styles["Normal"], fontSize=10, fontName="Helvetica-Bold", textColor=_PDF_BLUE, spaceAfter=3)
    meta_style = ParagraphStyle("Meta", parent=styles["Normal"], fontSize=9, textColor=_PDF_GREY700, spaceAfter=3)
    year_style = ParagraphStyle("Year", parent=styles["Normal"], fontSize=10, fontName="Helvetica-Bold", textColor=_PDF_BLUE, alignment=2, spaceAfter=3)
    total_style = ParagraphStyle("Total", parent=styles["Normal"], fontSize=9, textColor=_PDF_GREY700, alignment=2)

    quiz_date = quiz.get("quiz_date")
    quiz_date_str = quiz_date.strftime("%d-%m-%Y") if hasattr(quiz_date, "strftime") else str(quiz_date or "")
    start_time = str(quiz.get("quiz_start_time") or "").rsplit(":", 1)[0] if quiz.get("quiz_start_time") else ""
    end_time = str(quiz.get("quiz_end_time") or "").rsplit(":", 1)[0] if quiz.get("quiz_end_time") else ""
    duration = quiz.get("duration_minutes")
    department_code = quiz.get("department") or ""

    left_col = [Paragraph(f"Department: {_pdf_resolve_dept_name(department_code)}", dept_style)]
    left_col.append(Paragraph(f"Topic: {quiz.get('topic') or ''}", topic_style))
    left_col.append(Paragraph(f"Date: {quiz_date_str}", meta_style))
    if start_time or end_time:
        left_col.append(Paragraph(f"Timings: {start_time or '--'} - {end_time or '--'} ({duration} mins)", meta_style))
    if quiz.get("difficulty"):
        left_col.append(Paragraph(f"Difficulty: {quiz['difficulty']}", meta_style))
    if quiz.get("created_by_name"):
        left_col.append(Paragraph(f"Organised by: {quiz['created_by_name']}", meta_style))
    if department_code:
        left_col.append(Paragraph(f"Department: {department_code}", meta_style))

    right_col = [
        Paragraph(f"Year: Year {quiz.get('year') or ''}", year_style),
        Paragraph(f"Total Students: {len(marks_rows)}", total_style),
    ]

    meta_table = Table([[left_col, right_col]], colWidths=[120 * mm, 42 * mm])
    meta_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), _PDF_LIGHT_BG),
        ("BOX", (0, 0), (-1, -1), 0.75, _PDF_BORDER_GREY),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("ALIGN", (1, 0), (1, 0), "RIGHT"),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 10),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
    ]))

    elements = [meta_table, Spacer(1, 14)]

    table_data = [["UID", "Student Name", "Marks Obtained"]]
    for r in marks_rows:
        attempted = r["attempt_status"] == "Attempted"
        if attempted and r.get("score") is not None and r.get("total") is not None:
            mark_text = f"{r['score']} / {r['total']}"
        else:
            mark_text = "ABSENT / NOT ATTEMPTED"
        table_data.append([str(r["uid"]), r["name"] or "", mark_text])

    marks_table = Table(table_data, colWidths=[30 * mm, 82 * mm, 50 * mm], repeatRows=1)
    marks_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), _PDF_NAVY),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("GRID", (0, 0), (-1, -1), 0.5, _PDF_BORDER_GREY),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("ALIGN", (0, 0), (0, -1), "LEFT"),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    elements.append(marks_table)

    doc.build(
        elements,
        canvasmaker=lambda *a, **kw: _ReportCanvas(*a, report_meta=meta, **kw)
    )
    return buf.getvalue()


def build_and_send_quiz_csv_report(year, quiz_id):
    # Emails every generated set's questions for one quiz to whoever
    # created it, then marks csv_sent so it's never re-sent. Failures
    # (bad API key, Brevo down, etc.) leave csv_sent=0, so the next
    # maintenance pass just retries it automatically.
    #
    # The actual generated question content (with options + correct
    # answer) lives in daily_quiz_questions_pregenerated, one row per
    # question per set - daily_quiz_questions_bank_y{year} is a
    # per-student copy that only gets populated once a student actually
    # starts an attempt, so it's the wrong source for "all sets of qs".
    table = f"daily_quiz_topics_y{year}"
    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        # FOR UPDATE + an explicit transaction closes the race that let two
        # overlapping maintenance passes (e.g. the startup thread and the
        # first before_request-triggered pass firing back to back on a
        # restart) both see csv_sent=0 and both send the report before
        # either commits - the second caller now blocks on this row lock
        # until the first transaction commits csv_sent=1, then bails out.
        conn.begin()
        cur.execute(
            f"""
            SELECT title, subject, topic, department, difficulty,
                   quiz_date, quiz_start_time, quiz_end_time, duration_minutes,
                   created_by, csv_sent
            FROM {table} WHERE id=%s FOR UPDATE
            """,
            (quiz_id,)
        )
        quiz = cur.fetchone()
        if not quiz or not quiz.get("created_by") or quiz.get("csv_sent"):
            conn.rollback()
            return

        cur.execute("SELECT name FROM admins WHERE email=%s", (quiz["created_by"],))
        creator_row = cur.fetchone()
        quiz["created_by_name"] = creator_row["name"] if creator_row else quiz["created_by"]

        cur.execute(
            """
            SELECT set_number, question, option_a, option_b, option_c, option_d, correct_option
            FROM daily_quiz_questions_pregenerated
            WHERE quiz_id = %s
            ORDER BY set_number, id
            """,
            (quiz_id,)
        )
        rows = cur.fetchall()
        if not rows:
            # Nothing generated (e.g. a FAILED quiz) - nothing to attach.
            cur.execute(f"UPDATE {table} SET csv_sent=1 WHERE id=%s", (quiz_id,))
            conn.commit()
            return

        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(["Set Number", "Question", "Option A", "Option B", "Option C", "Option D", "Correct Option"])
        for r in rows:
            writer.writerow([
                r["set_number"], r["question"], r["option_a"], r["option_b"],
                r["option_c"], r["option_d"], r["correct_option"]
            ])
        questions_csv_bytes = buf.getvalue().encode("utf-8")

        # Student marks roster - same department+year scoping and LEFT JOIN
        # pattern as the in-app Full Class Report (admin_daily_quiz_full_class),
        # so every student in the quiz's department appears even if they
        # never attempted, not just the ones who have an attempts row.
        # Rendered as a PDF (build_marks_pdf) to match the look of the
        # Performance Analytics tab's Full Class Report, not a plain CSV.
        attempts_table = f"daily_quiz_attempts_y{year}"
        quiz_dept_id = BRANCH_TO_DEPT_ID.get(quiz["department"])
        marks_pdf_bytes = None
        if quiz_dept_id is not None:
            cur.execute(
                f"""
                SELECT s.uid, s.name, a.score, a.total,
                       CASE WHEN a.uid IS NULL THEN 'Not Attempted' ELSE 'Attempted' END AS attempt_status
                FROM students s
                LEFT JOIN {attempts_table} a
                    ON s.uid = a.uid AND a.quiz_id = %s
                WHERE CAST(s.year AS UNSIGNED) = %s AND s.dept_id = %s
                ORDER BY s.uid
                """,
                (quiz_id, year, quiz_dept_id)
            )
            marks_rows = cur.fetchall()
            if marks_rows:
                quiz["year"] = year
                marks_pdf_bytes = build_marks_pdf(quiz, quiz_id, marks_rows)

        subject = f"Quiz Report - {quiz['title'] or quiz['topic']} ({quiz['quiz_date']})"
        html_body = f"""
            <p>Attached are the reports for the daily quiz you created:</p>
            <p><strong>Topic:</strong> {quiz['topic']}<br>
            <strong>Subject:</strong> {quiz['subject']}<br>
            <strong>Department:</strong> {quiz['department']}<br>
            <strong>Date:</strong> {quiz['quiz_date']}</p>
            <p><strong>quiz_{quiz_id}_questions.csv</strong> - every question, its options, and
            the correct answer across all {len(set(r['set_number'] for r in rows))} generated
            set(s).</p>
            {"<p><strong>quiz_" + str(quiz_id) + "_marks.pdf</strong> - every student in this department's marks (or Not Attempted), same format as the Performance Analytics Full Class Report.</p>" if marks_pdf_bytes else ""}
            <p>This report exists because the underlying question data gets cleared from the
            database 2 days after the quiz date; marks remain available in the app regardless.</p>
        """

        attachments = [(questions_csv_bytes, f"quiz_{quiz_id}_questions.csv")]
        if marks_pdf_bytes:
            attachments.append((marks_pdf_bytes, f"quiz_{quiz_id}_marks.pdf"))

        send_email_with_attachments(quiz["created_by"], subject, html_body, attachments)

        cur.execute(f"UPDATE {table} SET csv_sent=1 WHERE id=%s", (quiz_id,))
        conn.commit()
        print(f"[Maintenance] Emailed CSV report for quiz id={quiz_id} (year={year}) to {quiz['created_by']}")
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"[Maintenance] CSV report failed for quiz id={quiz_id} (year={year}):", e)
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


def purge_old_daily_quiz_data():
    # Deletes only the bulky, regenerable-or-already-emailed data: the
    # per-student generated question bank, per-question answer rows, and
    # the generation bookkeeping tables. daily_quiz_attempts_y{year} (the
    # actual marks: uid/score/total) and daily_quiz_topics_y{year} (quiz
    # metadata) are never touched here.
    #
    # Gated on csv_sent=1 as a safety net - if the report email hasn't
    # gone out yet for some reason, we don't destroy the only copy of
    # the question/answer data.
    cutoff = today_ist() - timedelta(days=2)
    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        for year in (1, 2, 3, 4):
            topics_table = f"daily_quiz_topics_y{year}"
            bank_table = f"daily_quiz_questions_bank_y{year}"
            attempts_table = f"daily_quiz_attempts_y{year}"
            answers_table = f"daily_quiz_answers_y{year}"

            cur.execute(
                f"SELECT id FROM {topics_table} WHERE quiz_date <= %s AND csv_sent = 1",
                (cutoff,)
            )
            quiz_ids = [r["id"] for r in cur.fetchall()]
            if not quiz_ids:
                continue

            placeholders = ",".join(["%s"] * len(quiz_ids))

            # The actual generated question content (per set) - this is
            # what the CSV report was built from, so it's safe to drop
            # now that it's been emailed.
            cur.execute(
                f"DELETE FROM daily_quiz_questions_pregenerated WHERE quiz_id IN ({placeholders})",
                quiz_ids
            )
            # Per-student copies of questions + their selected answers.
            cur.execute(f"DELETE FROM {bank_table} WHERE quiz_id IN ({placeholders})", quiz_ids)
            cur.execute(
                f"""
                DELETE a FROM {answers_table} a
                JOIN {attempts_table} att ON a.attempt_id = att.id
                WHERE att.quiz_id IN ({placeholders})
                """,
                quiz_ids
            )
            # These three are shared across all years (year is a column,
            # not a suffix) - quiz_id alone isn't unique across years, so
            # year must be included too.
            cur.execute(
                f"DELETE FROM daily_quiz_sets WHERE quiz_id IN ({placeholders}) AND year=%s",
                quiz_ids + [year]
            )
            cur.execute(
                f"DELETE FROM daily_quiz_student_mapping WHERE quiz_id IN ({placeholders}) AND year=%s",
                quiz_ids + [year]
            )
            cur.execute(
                f"DELETE FROM daily_quiz_generation_queue WHERE quiz_id IN ({placeholders}) AND year=%s",
                quiz_ids + [year]
            )
            cur.execute(f"DELETE FROM daily_quiz_autosave WHERE quiz_id IN ({placeholders})", quiz_ids)
            conn.commit()
            print(f"[Maintenance] Purged bulky data for {len(quiz_ids)} year-{year} quiz(zes) on/before {cutoff}")
    except Exception as e:
        if conn:
            conn.rollback()
        print("[Maintenance] Purge failed:", e)
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


_maintenance_run_lock = threading.Lock()

# Grace period added on top of the quiz's own duration before the CSV
# report is sent. A student can legally start right up until quiz_end_time
# and still gets the full duration to finish, so "quiz has ended" for
# reporting purposes really means end_time + duration + a small buffer for
# the last starter's submit request to land - not end_time itself.
CSV_REPORT_GRACE_MINUTES = 2


def auto_finalize_abandoned_daily_quizzes():
    # A student can close the tab mid-quiz (or the browser can be killed
    # outright) without a submit request ever reaching the server - a
    # beforeunload warning can't guarantee that request completes. But every
    # answer they picked is already safely in daily_quiz_autosave the moment
    # they picked it, so once the quiz's end_time + duration + grace has
    # passed, whatever's still stuck in status='started' can be scored from
    # autosave and finalized here - the reliable backstop for "auto-submit on
    # close", independent of whether the client ever got a chance to call
    # /api/quiz/submit itself.
    try:
        now_ist = datetime.now(IST)
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        for year in (1, 2, 3, 4):
            attempts_table = f"daily_quiz_attempts_y{year}"
            topics_table = f"daily_quiz_topics_y{year}"
            bank_table = f"daily_quiz_questions_bank_y{year}"
            cur.execute(f"""
                SELECT a.uid, a.quiz_id, a.quiz_date, t.quiz_end_time, t.duration_minutes
                FROM {attempts_table} a
                JOIN {topics_table} t ON t.id = a.quiz_id
                WHERE a.status = 'started'
            """)
            for row in cur.fetchall():
                end_dt = IST.localize(datetime.combine(row["quiz_date"], dt_time.min) + row["quiz_end_time"])
                duration_minutes = row.get("duration_minutes") or 10
                cutoff_dt = end_dt + timedelta(minutes=duration_minutes + CSV_REPORT_GRACE_MINUTES)
                if now_ist <= cutoff_dt:
                    continue

                uid, quiz_id, quiz_date = row["uid"], row["quiz_id"], row["quiz_date"]
                try:
                    conn.begin()
                    cur.execute(
                        f"SELECT id, correct_answer FROM {bank_table} WHERE uid=%s AND quiz_date=%s AND quiz_id=%s",
                        (uid, quiz_date, quiz_id)
                    )
                    correct_map = {r["id"]: r["correct_answer"] for r in cur.fetchall()}
                    total_questions = len(correct_map)

                    cur.execute(
                        "SELECT question_id, selected_answer FROM daily_quiz_autosave WHERE uid=%s AND quiz_date=%s AND quiz_id=%s",
                        (uid, quiz_date, quiz_id)
                    )
                    score = 0
                    for a in cur.fetchall():
                        qid, selected = a["question_id"], a["selected_answer"]
                        cur.execute(
                            f"UPDATE {bank_table} SET student_answer=%s WHERE id=%s AND uid=%s AND quiz_date=%s",
                            (selected, qid, uid, quiz_date)
                        )
                        if selected and selected == correct_map.get(qid):
                            score += 1

                    cur.execute(
                        f"""
                        UPDATE {attempts_table}
                        SET score=%s, total=%s, status='submitted', time_taken_seconds=%s
                        WHERE uid=%s AND quiz_date=%s AND quiz_id=%s AND status='started'
                        """,
                        (score, total_questions, duration_minutes * 60, uid, quiz_date, quiz_id)
                    )
                    conn.commit()
                    print(f"[Maintenance] Auto-finalized abandoned daily quiz: uid={uid} quiz_id={quiz_id} year={year} score={score}/{total_questions}")
                except Exception as e:
                    conn.rollback()
                    print(f"[Maintenance] Daily quiz auto-finalize failed uid={uid} quiz_id={quiz_id}:", e)
        cur.close()
        conn.close()
    except Exception as e:
        print("[Maintenance] Daily quiz auto-finalize scan failed:", e)


def auto_finalize_abandoned_faculty_quizzes():
    # Same backstop as auto_finalize_abandoned_daily_quizzes, for faculty
    # quizzes - scores whatever's in faculty_quiz_autosave once the quiz's
    # end_time + duration + grace has passed and the attempt is still
    # 'started'.
    try:
        now_ist = datetime.now(IST)
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        cur.execute("""
            SELECT fa.uid, fa.quiz_id, m.quiz_date, m.quiz_end_time, m.duration_minutes, m.year, m.created_by
            FROM faculty_quiz_attempts fa
            JOIN faculty_quiz_master m ON m.quiz_id = fa.quiz_id
            WHERE fa.status = 'started'
        """)
        rows = cur.fetchall()
        if rows:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS faculty_quiz_student_answers (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    uid INT NOT NULL,
                    quiz_id INT NOT NULL,
                    question_id INT NOT NULL,
                    selected_answer VARCHAR(255),
                    UNIQUE KEY uk_std_q (uid, quiz_id, question_id)
                )
            """)
        for row in rows:
            end_dt = IST.localize(datetime.combine(row["quiz_date"], dt_time.min) + row["quiz_end_time"])
            duration_minutes = row.get("duration_minutes") or 10
            cutoff_dt = end_dt + timedelta(minutes=duration_minutes + CSV_REPORT_GRACE_MINUTES)
            if now_ist <= cutoff_dt:
                continue

            uid, quiz_id, year = row["uid"], row["quiz_id"], row["year"]
            marks_table = f"assignment_quiz_marks_y{year}"
            try:
                conn.begin()
                cur.execute(f"SELECT id FROM {marks_table} WHERE uid=%s AND quiz_id=%s FOR UPDATE", (uid, quiz_id))
                if cur.fetchone():
                    # Already submitted through the normal flow between the
                    # scan above and this lock - just fix the stale flag.
                    cur.execute("UPDATE faculty_quiz_attempts SET status='submitted' WHERE uid=%s AND quiz_id=%s", (uid, quiz_id))
                    conn.commit()
                    continue

                cur.execute("SELECT id, correct_option FROM faculty_quiz_questions_new WHERE quiz_id=%s", (quiz_id,))
                correct_map = {r["id"]: r["correct_option"] for r in cur.fetchall()}
                total_questions = len(correct_map)

                cur.execute("SELECT question_id, selected_answer FROM faculty_quiz_autosave WHERE uid=%s AND quiz_id=%s", (uid, quiz_id))
                score = 0
                for a in cur.fetchall():
                    qid, selected = a["question_id"], a["selected_answer"]
                    if correct_map.get(qid) == selected:
                        score += 1
                    cur.execute("""
                        INSERT INTO faculty_quiz_student_answers (uid, quiz_id, question_id, selected_answer)
                        VALUES (%s, %s, %s, %s)
                        ON DUPLICATE KEY UPDATE selected_answer = VALUES(selected_answer)
                    """, (uid, quiz_id, qid, selected))

                cur.execute(
                    f"""
                    INSERT INTO {marks_table} (uid, quiz_id, quiz_date, total_questions, score, created_by)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    """,
                    (uid, quiz_id, today_ist(), total_questions, score, row.get("created_by") or "Admin")
                )
                cur.execute("UPDATE faculty_quiz_attempts SET status='submitted' WHERE uid=%s AND quiz_id=%s", (uid, quiz_id))
                conn.commit()
                print(f"[Maintenance] Auto-finalized abandoned faculty quiz: uid={uid} quiz_id={quiz_id} score={score}/{total_questions}")
            except Exception as e:
                conn.rollback()
                print(f"[Maintenance] Faculty quiz auto-finalize failed uid={uid} quiz_id={quiz_id}:", e)
        cur.close()
        conn.close()
    except Exception as e:
        print("[Maintenance] Faculty quiz auto-finalize scan failed:", e)


def run_daily_quiz_maintenance():
    # Guards against two overlapping passes (the startup thread and the
    # first before_request-triggered pass land within milliseconds of each
    # other on a restart, since _last_maintenance_run starts unset). The
    # FOR UPDATE lock in build_and_send_quiz_csv_report already prevents a
    # duplicate send even if this were somehow bypassed, but skipping the
    # redundant scan entirely is cheaper and avoids a duplicate purge run.
    if not _maintenance_run_lock.acquire(blocking=False):
        return
    try:
        now_ist = datetime.now(IST)
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        for year in (1, 2, 3, 4):
            table = f"daily_quiz_topics_y{year}"
            cur.execute(
                f"""
                SELECT id, quiz_date, quiz_end_time, duration_minutes FROM {table}
                WHERE csv_sent = 0 AND status IN ('READY', 'FAILED')
                """
            )
            for row in cur.fetchall():
                end_dt_naive = datetime.combine(row["quiz_date"], dt_time.min) + row["quiz_end_time"]
                end_dt = IST.localize(end_dt_naive)
                duration_minutes = row.get("duration_minutes") or 10
                cutoff_dt = end_dt + timedelta(minutes=duration_minutes + CSV_REPORT_GRACE_MINUTES)
                if now_ist > cutoff_dt:
                    build_and_send_quiz_csv_report(year, row["id"])
        cur.close()
        conn.close()
    except Exception as e:
        print("[Maintenance] CSV-report scan failed:", e)
    finally:
        _maintenance_run_lock.release()

    auto_finalize_abandoned_daily_quizzes()
    auto_finalize_abandoned_faculty_quizzes()
    purge_old_daily_quiz_data()


_last_maintenance_run = None
_maintenance_lock = threading.Lock()
MAINTENANCE_THROTTLE_SECONDS = 60  # 1 minute - keeps CSV-report timing close
# to the intended end_time + duration + grace cutoff. The scan itself is
# 4 cheap indexed-ish SELECTs, so checking once a minute (only while real
# traffic is flowing in - this piggybacks on before_request, same as
# before) is not a meaningful cost, and 10 minutes was letting reports go
# out up to ~10 minutes later than the cutoff implied they should.


def maybe_run_maintenance():
    global _last_maintenance_run
    now = datetime.utcnow()
    with _maintenance_lock:
        if _last_maintenance_run and (now - _last_maintenance_run).total_seconds() < MAINTENANCE_THROTTLE_SECONDS:
            return
        _last_maintenance_run = now
    t = threading.Thread(target=run_daily_quiz_maintenance)
    t.daemon = True
    t.start()


@app.before_request
def _daily_quiz_maintenance_hook():
    # Piggybacks on real traffic - the same traffic that wakes a sleeping
    # Render free-tier dyno back up - so due work always gets caught
    # shortly after startup even if no request happens to land at the
    # exact moment something becomes due.
    maybe_run_maintenance()


DAILY_QUIZ_MAX_QUESTIONS = 20
DAILY_QUIZ_MAX_DURATION_MINUTES = 30

FACULTY_QUIZ_REQUIRED_CSV_COLUMNS = {
    "question", "option_a", "option_b", "option_c", "option_d", "correct_option"
}
FACULTY_QUIZ_MAX_QUESTIONS = 30
FACULTY_QUIZ_MAX_DURATION_MINUTES = 30


def _validate_faculty_quiz_csv(file_storage):
    """Parses + fully validates a faculty-quiz CSV before any DB write.
    Returns (rows, errors) - rows is a list of cleaned dicts ready to
    insert when errors is empty; otherwise rows is None."""
    try:
        csv_file = TextIOWrapper(file_storage.stream, encoding="utf-8-sig")
        reader = csv.DictReader(csv_file)
    except Exception as e:
        return None, [f"Could not read CSV file: {e}"]

    if not reader.fieldnames:
        return None, ["CSV file appears to be empty"]

    headers = {h.strip().lower() for h in reader.fieldnames if h}
    missing = FACULTY_QUIZ_REQUIRED_CSV_COLUMNS - headers
    if missing:
        return None, [f"Missing required column(s): {', '.join(sorted(missing))}"]

    raw_rows = list(reader)
    if len(raw_rows) == 0:
        return None, ["CSV file has no question rows"]
    if len(raw_rows) > FACULTY_QUIZ_MAX_QUESTIONS:
        return None, [f"Too many questions: {len(raw_rows)} (max {FACULTY_QUIZ_MAX_QUESTIONS})"]

    errors = []
    cleaned = []
    for i, raw in enumerate(raw_rows, start=2):  # row 1 is the header
        row = {(k.strip().lower() if k else k): (v.strip() if v else v) for k, v in raw.items()}
        row_errors = []
        for col in ("question", "option_a", "option_b", "option_c", "option_d", "correct_option"):
            if not row.get(col):
                row_errors.append(f"row {i}: '{col}' is empty")
        correct_option = (row.get("correct_option") or "").upper()
        if row.get("correct_option") and correct_option not in ("A", "B", "C", "D"):
            row_errors.append(f"row {i}: correct_option '{row.get('correct_option')}' must be A, B, C or D")
        if row_errors:
            errors.extend(row_errors)
            continue
        cleaned.append({
            "question": row["question"],
            "option_a": row["option_a"],
            "option_b": row["option_b"],
            "option_c": row["option_c"],
            "option_d": row["option_d"],
            "correct_option": correct_option,
        })

    if errors:
        return None, errors
    return cleaned, []


@app.route("/api/admin/faculty-quiz/validate-csv", methods=["POST", "OPTIONS"])
@admin_token_required
@role_required("super_admin", "admin", "hod", "faculty")
def validate_faculty_quiz_csv_route(admin):
    """Dry-run check: runs the same CSV validation as quiz creation but
    never writes anything, so the uploader can fix problems before
    committing to a quiz name/schedule."""
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    if "file" not in request.files:
        return jsonify({"error": "A CSV file of questions is required"}), 400
    file = request.files["file"]
    if not file.filename.lower().endswith(".csv"):
        return jsonify({"error": "Only .csv files are allowed"}), 400

    rows, errors = _validate_faculty_quiz_csv(file)
    if errors:
        return jsonify({"success": False, "error": "CSV validation failed", "details": errors}), 400

    return jsonify({"success": True, "total_questions": len(rows)}), 200


@app.route("/api/admin/faculty-quiz/create", methods=["POST", "OPTIONS"])
@admin_token_required
@role_required("super_admin", "admin", "hod", "faculty")
def create_faculty_quiz(admin):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    quiz_name = (request.form.get("quiz_name") or "").strip()
    quiz_date = request.form.get("quiz_date")
    quiz_start_time = request.form.get("quiz_start_time")
    quiz_end_time = request.form.get("quiz_end_time")
    year = request.form.get("year", type=int)
    duration_minutes = request.form.get("duration_minutes", type=int)

    if not quiz_name or not quiz_date or not quiz_start_time or not quiz_end_time or not year:
        return jsonify({"error": "Quiz name, date, start/end time and year are all required"}), 400
    if year not in (1, 2, 3, 4):
        return jsonify({"error": "Invalid year"}), 400
    if quiz_end_time <= quiz_start_time:
        return jsonify({"error": "End time must be after start time"}), 400
    if not duration_minutes or not (1 <= duration_minutes <= FACULTY_QUIZ_MAX_DURATION_MINUTES):
        return jsonify({"error": f"Duration must be between 1 and {FACULTY_QUIZ_MAX_DURATION_MINUTES} minutes"}), 400

    # 🔒 5 MINUTE BUFFER FOR PUBLISHING (mirrors the Ai Quiz's 15-minute rule)
    try:
        now_ist = datetime.now(IST)
        start_time_clean = quiz_start_time.split(" ")[0]
        fmt = "%Y-%m-%d %H:%M" if len(start_time_clean.split(":")) == 2 else "%Y-%m-%d %H:%M:%S"
        start_dt = IST.localize(datetime.strptime(f"{quiz_date} {start_time_clean}", fmt))
        if start_dt - now_ist < timedelta(minutes=5):
            return jsonify({"error": "Quiz start time must be at least 5 minutes in the future from now."}), 400
    except ValueError:
        return jsonify({"error": "Invalid date/time format"}), 400

    # Department resolution: hod/faculty are locked to their own department
    # regardless of client input; super_admin/admin must explicitly pick one
    # (same convention as the Ai Quiz's insert_daily_quiz_topic).
    if admin["role"] in ("hod", "faculty"):
        dept_id = admin["dept_id"]
    else:
        dept_id = request.form.get("dept_id", type=int)

    department = DEPT_ID_TO_BRANCH.get(dept_id)
    if not department:
        return jsonify({"error": "This department is not yet configured for faculty quizzes"}), 400

    if "file" not in request.files:
        return jsonify({"error": "A CSV file of questions is required"}), 400
    file = request.files["file"]
    if not file.filename.lower().endswith(".csv"):
        return jsonify({"error": "Only .csv files are allowed"}), 400

    rows, errors = _validate_faculty_quiz_csv(file)
    if errors:
        return jsonify({"error": "CSV validation failed", "details": errors}), 400

    # created_by is always the authenticated caller, never client-supplied.
    created_by = admin["email"]

    conn = None
    cur = None
    try:
        conn = get_db()
        conn.begin()
        cur = conn.cursor()

        cur.execute("""
            INSERT INTO faculty_quiz_master
            (quiz_name, quiz_date, quiz_start_time, quiz_end_time, duration_minutes, year, created_by, department)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (quiz_name, quiz_date, quiz_start_time, quiz_end_time, duration_minutes, year, created_by, department))
        quiz_id = cur.lastrowid

        for row in rows:
            cur.execute("""
                INSERT INTO faculty_quiz_questions_new
                (quiz_id, question, option_a, option_b, option_c, option_d, correct_option)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (
                quiz_id, row["question"], row["option_a"], row["option_b"],
                row["option_c"], row["option_d"], row["correct_option"]
            ))

        conn.commit()
        return jsonify({
            "success": True,
            "quiz_id": quiz_id,
            "quiz_name": quiz_name,
            "total_questions": len(rows)
        }), 201
    except Exception as e:
        if conn:
            conn.rollback()
        return generic_error_response(e)
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


@app.route("/api/admin/daily-quiz/progress/<int:year>/<string:quiz_date>", methods=["GET", "OPTIONS"])
@admin_token_required
def get_daily_quiz_progress(admin, year, quiz_date):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    table = f"daily_quiz_topics_y{year}"
    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        # Scoped to the caller's own quizzes only - one admin/hod/faculty's
        # generation status is never visible to any other account, per role.
        cur.execute(f"""
            SELECT id, title, subject, topic, department, status, total_sets_required, generated_sets, failed_sets, quiz_start_time, quiz_end_time
            FROM {table}
            WHERE quiz_date = %s AND quiz_type = 'placement' AND created_by = %s
            ORDER BY id ASC
        """, (quiz_date, admin["email"]))
        rows = cur.fetchall()
        
        if not rows:
            return jsonify({"error": "No quizzes found for this date"}), 404
            
        def format_time_to_str(t):
            if not t:
                return "00:00:00"
            if isinstance(t, str):
                return t
            if isinstance(t, timedelta):
                return str(t)
            if type(t).__name__ == 'time':
                return t.strftime("%H:%M:%S")
            return str(t)

        quizzes = []
        for row in rows:
            percentage = 0
            if row["total_sets_required"] > 0:
                percentage = int((row["generated_sets"] + row["failed_sets"]) / row["total_sets_required"] * 100)
            quizzes.append({
                "id": row["id"],
                "title": row["title"],
                "subject": row["subject"],
                "topic": row["topic"],
                "department": row.get("department", ""),
                "status": row["status"],
                "generated_sets": row["generated_sets"],
                "failed_sets": row["failed_sets"],
                "total_sets_required": row["total_sets_required"],
                "quiz_start_time": format_time_to_str(row["quiz_start_time"]),
                "quiz_end_time": format_time_to_str(row["quiz_end_time"]),
                "percentage": percentage
            })

        # Backwards-compatible: also return first quiz fields at top level
        first = quizzes[0] if quizzes else {}
        resp = {
            "success": True,
            "quizzes": quizzes,
            # Legacy single-quiz fields (from first quiz)
            "title": first.get("title", ""),
            "subject": first.get("subject", ""),
            "topic": first.get("topic", ""),
            "status": first.get("status", ""),
            "generated_sets": first.get("generated_sets", 0),
            "failed_sets": first.get("failed_sets", 0),
            "total_sets_required": first.get("total_sets_required", 0),
            "quiz_start_time": first.get("quiz_start_time", "00:00:00"),
            "quiz_end_time": first.get("quiz_end_time", "23:59:59"),
            "percentage": first.get("percentage", 0)
        }
        return jsonify(resp), 200
    except Exception as e:
        return generic_error_response(e)
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


@app.route("/api/admin/daily-quiz/edit-time", methods=["POST", "OPTIONS"])
@admin_token_required
def edit_daily_quiz_time(admin):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.get_json() or {}
    year = data.get("year")
    quiz_date = data.get("quiz_date")
    quiz_id = data.get("quiz_id")
    quiz_start_time = data.get("quiz_start_time")
    quiz_end_time = data.get("quiz_end_time")

    if year not in [1, 2, 3, 4] or not quiz_start_time or not quiz_end_time:
        return jsonify({"error": "year, quiz_start_time and quiz_end_time are required"}), 400

    if not quiz_id and not quiz_date:
        return jsonify({"error": "quiz_id or quiz_date is required"}), 400

    table = f"daily_quiz_topics_y{year}"

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        if quiz_id:
            cur.execute(f"SELECT status, created_by FROM {table} WHERE id=%s", (quiz_id,))
        else:
            cur.execute(f"SELECT status, created_by FROM {table} WHERE quiz_date=%s AND quiz_type='placement'", (quiz_date,))
        row = cur.fetchone()
        if not row:
            return jsonify({"error": "No placement quiz found"}), 404

        # Same rule as the Questions Generated view: only the quiz's own
        # creator may touch it, regardless of role.
        if row.get("created_by") != admin["email"]:
            return jsonify({"error": "You can only edit quizzes you created"}), 403

        if row["status"] != "READY":
            return jsonify({"error": "Quiz timings can only be updated when status is READY"}), 400

        if quiz_id:
            cur.execute(f"""
                UPDATE {table}
                SET quiz_start_time=%s, quiz_end_time=%s
                WHERE id=%s
            """, (quiz_start_time, quiz_end_time, quiz_id))
        else:
            cur.execute(f"""
                UPDATE {table}
                SET quiz_start_time=%s, quiz_end_time=%s
                WHERE quiz_date=%s AND quiz_type='placement'
            """, (quiz_start_time, quiz_end_time, quiz_date))
        conn.commit()

        return jsonify({"success": True, "message": "Quiz timings updated successfully"}), 200
    except Exception as e:
        return generic_error_response(e)
    finally:
        if cur: cur.close()
        if conn: conn.close()


@app.route("/api/daily_quiz/autosave", methods=["POST", "OPTIONS"])
@token_required
def daily_quiz_autosave(current_user):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.json or {}
    quiz_date = data.get("quiz_date")
    quiz_id = data.get("quiz_id")
    question_id = data.get("question_id")
    selected_answer = data.get("selected_answer")

    if not all([quiz_date, question_id, selected_answer is not None]):
        return jsonify({"error": "quiz_date, question_id, and selected_answer are required"}), 400

    uid = current_user["uid"]

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO daily_quiz_autosave (uid, quiz_date, quiz_id, question_id, selected_answer)
            VALUES (%s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE selected_answer = %s, quiz_id = %s
        """, (uid, quiz_date, quiz_id, question_id, selected_answer, selected_answer, quiz_id))
        conn.commit()
        return jsonify({"success": True, "message": "Answer autosaved"}), 200
    except Exception as e:
        return generic_error_response(e)
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


import csv



@app.route("/api/admin/faculty-quiz/search", methods=["GET", "OPTIONS"])
@admin_token_required
def search_faculty_quiz(admin):

    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    quiz_id = request.args.get("quiz_id")

    if not quiz_id:
        return jsonify({"quizzes": []}), 200

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        # 🔥 NOTE: %% is REQUIRED (escape for PyMySQL)
        cur.execute("""
            SELECT
                quiz_id,
                DATE_FORMAT(quiz_date, '%%Y-%%m-%%d') AS quiz_date,
                TIME_FORMAT(quiz_start_time, '%%H:%%i') AS quiz_start_time,
                TIME_FORMAT(quiz_end_time, '%%H:%%i') AS quiz_end_time,
                year,
                created_by
            FROM faculty_quiz_master
            WHERE quiz_id = %s
        """, (quiz_id,))

        row = cur.fetchone()

        if row and not can_access_quiz(admin, row["created_by"], cur):
            row = None

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()   # 🔥 return to pool

    if not row:
        return jsonify({"quizzes": []}), 200

    # ✅ Already strings → JSON safe
    return jsonify({
        "quizzes": [row]
    }), 200




@app.route("/api/admin/faculty-quiz/sample-csv", methods=["GET"])
def faculty_quiz_sample_csv():
    # Public on purpose: this is a generic CSV template with no real quiz
    # content, and making it public lets clients open it as a plain URL
    # (external browser / native "open" intent) instead of needing to
    # attach an Authorization header, which isn't possible when the OS
    # handles the download outside the app (e.g. on mobile).
    return send_from_directory(
        os.path.join(os.path.dirname(__file__), "static"),
        "faculty_quiz_sample.csv",
        as_attachment=True,
        download_name="faculty_quiz_sample.csv"
    )


@app.route("/api/admin/faculty-quiz/list", methods=["GET", "OPTIONS"])
@admin_token_required
def list_faculty_quizzes(admin):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    year = request.args.get("year", type=int)
    quiz_date = request.args.get("quiz_date")
    dept_id = request.args.get("dept_id", type=int)

    where = []
    params = []
    if year in (1, 2, 3, 4):
        where.append("m.year = %s")
        params.append(year)

    if quiz_date:
        where.append("m.quiz_date = %s")
        params.append(quiz_date)

    # Only super_admin/admin may narrow by department - faculty/hod are
    # already scoped to their own department via created_by below.
    if dept_id and admin["role"] in ("super_admin", "admin"):
        department = DEPT_ID_TO_BRANCH.get(dept_id)
        if department:
            where.append("m.department = %s")
            params.append(department)

    if admin["role"] == "faculty":
        where.append("m.created_by = %s")
        params.append(admin["email"])
    elif admin["role"] == "hod":
        where.append("m.created_by IN (SELECT email FROM admins WHERE dept_id=%s AND role IN ('faculty','hod'))")
        params.append(admin["dept_id"])
    # super_admin/admin: unrestricted

    where_sql = ("WHERE " + " AND ".join(where)) if where else ""

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        cur.execute(f"""
            SELECT
                m.quiz_id, m.quiz_name, m.quiz_date, m.department,
                TIME_FORMAT(m.quiz_start_time, '%%H:%%i') AS quiz_start_time,
                TIME_FORMAT(m.quiz_end_time, '%%H:%%i') AS quiz_end_time,
                m.duration_minutes, m.year, m.created_by, a.name AS created_by_name,
                (SELECT COUNT(*) FROM faculty_quiz_questions_new q WHERE q.quiz_id = m.quiz_id) AS question_count
            FROM faculty_quiz_master m
            LEFT JOIN admins a ON a.email = m.created_by
            {where_sql}
            ORDER BY m.quiz_date DESC, m.quiz_id DESC
        """, params)
        quizzes = cur.fetchall()
        for q in quizzes:
            q["quiz_date"] = str(q["quiz_date"])
        return jsonify({"success": True, "quizzes": quizzes}), 200
    except Exception as e:
        return generic_error_response(e)
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


@app.route("/api/admin/faculty-quiz/delete", methods=["DELETE", "OPTIONS"])
@admin_token_required
def delete_faculty_quiz(admin):

    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.json or {}
    quiz_id = data.get("quiz_id")

    if not quiz_id:
        return jsonify({
            "success": False,
            "message": "quiz_id required"
        }), 400

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        cur.execute("SELECT created_by FROM faculty_quiz_master WHERE quiz_id = %s", (quiz_id,))
        quiz = cur.fetchone()
        if not quiz:
            return jsonify({"success": False, "message": "Quiz not found"}), 404
        if not can_access_quiz(admin, quiz["created_by"], cur):
            return jsonify({"success": False, "message": "Access denied"}), 403

        # 1️⃣ Delete questions
        cur.execute(
            "DELETE FROM faculty_quiz_questions_new WHERE quiz_id = %s",
            (quiz_id,)
        )

        # 2️⃣ Delete quiz master
        cur.execute(
            "DELETE FROM faculty_quiz_master WHERE quiz_id = %s",
            (quiz_id,)
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Quiz deleted from master and questions table"
        }), 200

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()   # 🔥 return to pool



@app.route("/api/admin/faculty-quiz/delete-search", methods=["GET", "OPTIONS"])
@admin_token_required
def delete_search_faculty_quiz(admin):

    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    quiz_id = request.args.get("quiz_id")

    if not quiz_id:
        return jsonify({
            "success": True,
            "quiz": None
        }), 200

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        cur.execute("""
            SELECT
                quiz_id, quiz_name,
                DATE_FORMAT(quiz_date, '%%Y-%%m-%%d') AS quiz_date,
                TIME_FORMAT(quiz_start_time, '%%H:%%i') AS quiz_start_time,
                TIME_FORMAT(quiz_end_time, '%%H:%%i') AS quiz_end_time,
                year,
                created_by
            FROM faculty_quiz_master
            WHERE quiz_id = %s
        """, (quiz_id,))

        quiz = cur.fetchone()

        if quiz and not can_access_quiz(admin, quiz["created_by"], cur):
            quiz = None

        return jsonify({
            "success": True,
            "quiz": quiz
        }), 200

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()   # 🔥 return to pool



@app.route("/api/admin/faculty-quiz/view", methods=["GET", "OPTIONS"])
@admin_token_required
def view_faculty_quiz(admin):

    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    quiz_id = request.args.get("quiz_id")

    if not quiz_id:
        return jsonify({
            "success": False,
            "message": "quiz_id required"
        }), 400

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        # 1️⃣ Quiz Master
        cur.execute("""
            SELECT
                quiz_id, quiz_name,
                quiz_date,
                quiz_start_time, quiz_end_time,
                duration_minutes,
                year,
                created_by
            FROM faculty_quiz_master
            WHERE quiz_id = %s
        """, (quiz_id,))

        quiz = cur.fetchone()

        if not quiz:
            return jsonify({
                "success": False,
                "message": "Quiz not found"
            }), 404

        if not can_access_quiz(admin, quiz["created_by"], cur):
            return jsonify({
                "success": False,
                "message": "Access denied"
            }), 403

        # Only the quiz's own creator sees correct answers before the quiz
        # ends - everyone else (super admin/hod/other staff) sees the
        # questions/options but not the answer key until quiz_end_time.
        is_creator = quiz["created_by"] == admin["email"]
        end_time = parse_time_field(quiz["quiz_end_time"])
        is_finished = False
        if end_time:
            deadline = IST.localize(datetime.combine(quiz["quiz_date"], end_time))
            is_finished = datetime.now(IST) > deadline
        answers_visible = is_creator or is_finished

        quiz["quiz_date"] = str(quiz["quiz_date"])
        quiz["quiz_start_time"] = str(quiz["quiz_start_time"])
        quiz["quiz_end_time"] = str(quiz["quiz_end_time"])

        # 2️⃣ Questions
        cur.execute("""
            SELECT
                id,
                question,
                option_a,
                option_b,
                option_c,
                option_d,
                correct_option
            FROM faculty_quiz_questions_new
            WHERE quiz_id = %s
            ORDER BY id
        """, (quiz_id,))

        questions = cur.fetchall()
        if not answers_visible:
            for q in questions:
                q["correct_option"] = None

        return jsonify({
            "success": True,
            "quiz": quiz,
            "questions": questions,
            "answers_hidden": not answers_visible
        }), 200

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()   # 🔥 return to pool


@app.route("/api/admin/daily-quiz/single-student", methods=["GET"])
@admin_token_required
def admin_daily_quiz_single_student(current_admin):

    uid = request.args.get("uid", type=int)
    year = request.args.get("year", type=int)

    if not uid:
        return jsonify({
            "success": False,
            "message": "uid required"
        }), 400

    conn = get_db()
    cur = conn.cursor(pymysql.cursors.DictCursor)

    try:
        # STUDENT DETAILS
        cur.execute(
            "SELECT name, email, year, dept_id FROM students WHERE uid = %s",
            (uid,)
        )
        student = cur.fetchone()
        if not student:
            return jsonify({
                "success": False,
                "message": "Student not found"
            }), 404

        if current_admin["role"] in ("hod", "faculty") and student.get("dept_id") != current_admin["dept_id"]:
            return jsonify({
                "success": False,
                "message": "You can only view students in your own department"
            }), 403

        if not year:
            try:
                year = int(student.get("year") or 2)
            except Exception:
                year = 2

        attempts_table = f"daily_quiz_attempts_y{year}"

        # DAILY QUIZ MARKS
        cur.execute(
            f"""
            SELECT quiz_date, score, total
            FROM {attempts_table}
            WHERE uid = %s
            ORDER BY quiz_date DESC
            """,
            (uid,)
        )

        records = cur.fetchall()

        # ✅ FIX DATE FORMAT
        for r in records:
            if r["quiz_date"]:
                r["quiz_date"] = r["quiz_date"].strftime("%Y-%m-%d")

        return jsonify({
            "success": True,
            "student": {
                "name": student["name"],
                "email": student["email"]
            },
            "data": records
        }), 200

    finally:
        cur.close()
        conn.close()


@app.route("/api/admin/daily-quiz/list", methods=["GET", "OPTIONS"])
@admin_token_required
def list_daily_quizzes_for_date(admin):
    # Step 1 of the marks-search flow: "how many quizzes were taken on
    # this date" - a department can now have its own quiz on the same
    # date, so the caller picks one of these before drilling into marks.
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    year = request.args.get("year", type=int)
    quiz_date = request.args.get("date")
    dept_id = request.args.get("dept_id", type=int)

    if year not in (1, 2, 3, 4) or not quiz_date:
        return jsonify({"success": False, "message": "year and date required"}), 400

    # hod/faculty are scoped to their own department; super_admin/admin
    # may optionally narrow by department via dept_id. Faculty is further
    # narrowed to only the quizzes they personally created - hod still
    # sees every quiz in the department (its own + all its faculty's).
    if admin["role"] in ("hod", "faculty"):
        department = DEPT_ID_TO_BRANCH.get(admin["dept_id"])
    else:
        department = DEPT_ID_TO_BRANCH.get(dept_id) if dept_id else None

    table = f"daily_quiz_topics_y{year}"
    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        # Joined with admins so admin/hod can see which faculty/hod
        # generated each quiz (faculty only ever sees their own, so the
        # name is redundant there but harmless to include).
        select_cols = """
            t.id, t.subject, t.topic, t.department, t.difficulty, t.total_questions, t.status,
            t.created_by, a.name AS created_by_name
        """
        if admin["role"] == "faculty":
            cur.execute(f"""
                SELECT {select_cols}
                FROM {table} t
                LEFT JOIN admins a ON a.email = t.created_by
                WHERE t.quiz_date = %s AND t.quiz_type = 'placement' AND t.created_by = %s
                ORDER BY t.id ASC
            """, (quiz_date, admin["email"]))
        elif department:
            cur.execute(f"""
                SELECT {select_cols}
                FROM {table} t
                LEFT JOIN admins a ON a.email = t.created_by
                WHERE t.quiz_date = %s AND t.quiz_type = 'placement' AND t.department = %s
                ORDER BY t.id ASC
            """, (quiz_date, department))
        else:
            cur.execute(f"""
                SELECT {select_cols}
                FROM {table} t
                LEFT JOIN admins a ON a.email = t.created_by
                WHERE t.quiz_date = %s AND t.quiz_type = 'placement'
                ORDER BY t.id ASC
            """, (quiz_date,))
        quizzes = cur.fetchall()
        return jsonify({"success": True, "quizzes": quizzes}), 200
    except Exception as e:
        return generic_error_response(e)
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


@app.route("/api/admin/daily-quiz/full-class", methods=["GET"])
@admin_token_required
def admin_daily_quiz_full_class(current_admin):
    # Step 2 of the marks-search flow: the specific quiz (picked from the
    # /daily-quiz/list step) and its student roster + marks, uid-ascending.

    year = request.args.get("year", type=int)
    quiz_id = request.args.get("quiz_id", type=int)

    if year not in (1, 2, 3, 4) or not quiz_id:
        return jsonify({
            "success": False,
            "message": "year and quiz_id required"
        }), 400

    attempts_table = f"daily_quiz_attempts_y{year}"
    topics_table = f"daily_quiz_topics_y{year}"

    conn = get_db()
    cur = conn.cursor(pymysql.cursors.DictCursor)

    try:
        # ---------------- QUIZ META ----------------
        cur.execute(
            f"""
            SELECT t.id, t.subject, t.topic, t.difficulty, t.total_questions, t.quiz_date, t.department,
                   t.quiz_start_time, t.quiz_end_time, t.duration_minutes,
                   t.created_by, a.name AS created_by_name
            FROM {topics_table} t
            LEFT JOIN admins a ON a.email = t.created_by
            WHERE t.id = %s
            """,
            (quiz_id,)
        )
        quiz = cur.fetchone()

        if not quiz:
            return jsonify({
                "success": False,
                "message": "Quiz not found"
            }), 404

        # hod may only view its own department's quizzes; faculty is
        # further narrowed to only the quizzes they personally created.
        if current_admin["role"] in ("hod", "faculty"):
            own_department = DEPT_ID_TO_BRANCH.get(current_admin["dept_id"])
            if quiz["department"] != own_department:
                return jsonify({"success": False, "message": "Quiz not in your department"}), 403
        if current_admin["role"] == "faculty" and quiz["created_by"] != current_admin["email"]:
            return jsonify({"success": False, "message": "You can only view quizzes you created"}), 403

        # ---------------- STUDENTS + MARKS ----------------
        # Scoped to the quiz's own department - a quiz only ever went out
        # to that department's students, so cross-department names never
        # belong in this roster.
        quiz_dept_id = BRANCH_TO_DEPT_ID.get(quiz["department"])
        cur.execute(
            f"""
            SELECT
                s.uid,
                s.name,
                a.score AS marks,
                a.score,
                a.total,
                CASE
                    WHEN a.uid IS NULL THEN FALSE
                    ELSE TRUE
                END AS attempted
            FROM students s
            LEFT JOIN {attempts_table} a
                ON s.uid = a.uid
               AND a.quiz_id = %s
            WHERE CAST(s.year AS UNSIGNED) = %s AND s.dept_id = %s
            ORDER BY s.uid
            """,
            (quiz_id, year, quiz_dept_id)
        )

        students = cur.fetchall()

        return jsonify({
            "success": True,
            "quiz": {
                "id": quiz["id"],
                "date": str(quiz["quiz_date"]),
                "year": year,
                "subject": quiz.get("subject") or "",
                "topic": quiz["topic"],
                "difficulty": quiz["difficulty"],
                "total_marks": quiz["total_questions"],
                "department": quiz["department"],
                "quiz_start_time": str(quiz.get("quiz_start_time")) if quiz.get("quiz_start_time") else "",
                "quiz_end_time": str(quiz.get("quiz_end_time")) if quiz.get("quiz_end_time") else "",
                "duration_minutes": quiz.get("duration_minutes") or 10,
                "created_by": quiz["created_by"],
                "created_by_name": quiz.get("created_by_name") or quiz["created_by"] or "Admin",
                "can_reset": quiz["created_by"] == current_admin["email"]
            },
            "students": students
        }), 200

    finally:
        cur.close()
        conn.close()


@app.route("/api/admin/daily-quiz/reset-student", methods=["POST", "OPTIONS"])
@admin_token_required
def reset_daily_quiz_for_student(admin):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.get_json() or {}
    year = data.get("year")
    quiz_id = data.get("quiz_id")
    uid = data.get("uid")

    if year not in (1, 2, 3, 4) or not quiz_id or not uid:
        return jsonify({"success": False, "message": "year, quiz_id and uid are required"}), 400

    topics_table = f"daily_quiz_topics_y{year}"
    attempts_table = f"daily_quiz_attempts_y{year}"

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        cur.execute(f"SELECT created_by FROM {topics_table} WHERE id=%s", (quiz_id,))
        quiz = cur.fetchone()
        if not quiz:
            return jsonify({"success": False, "message": "Quiz not found"}), 404

        # Same rule as Questions Generated / edit-time: only the quiz's own
        # creator may reset a student's attempt on it.
        if quiz.get("created_by") != admin["email"]:
            return jsonify({"success": False, "message": "Only the quiz creator can reset a student's attempt"}), 403

        conn.begin()
        # Attempt row cascades to daily_quiz_answers_y{year} via FK ON DELETE CASCADE.
        cur.execute(f"DELETE FROM {attempts_table} WHERE uid=%s AND quiz_id=%s", (uid, quiz_id))
        cur.execute("DELETE FROM daily_quiz_student_mapping WHERE uid=%s AND quiz_id=%s", (uid, quiz_id))
        cur.execute("DELETE FROM daily_quiz_autosave WHERE uid=%s AND quiz_id=%s", (uid, quiz_id))
        cur.execute(f"DELETE FROM daily_quiz_questions_y{year} WHERE uid=%s AND quiz_id=%s", (uid, quiz_id))
        cur.execute(f"DELETE FROM daily_quiz_questions_bank_y{year} WHERE uid=%s AND quiz_id=%s", (uid, quiz_id))

        # Sets are marked DONE once handed to a first-time student (see
        # get_daily_quiz) so nobody else draws the same set. A reset student
        # is the one deliberate exception - they should be free to draw any
        # set at random, including ones already marked DONE - so record this
        # uid+quiz_id here for get_daily_quiz's set picker to recognize.
        cur.execute("""
            CREATE TABLE IF NOT EXISTS daily_quiz_reset_students (
                id INT AUTO_INCREMENT PRIMARY KEY,
                uid INT NOT NULL,
                quiz_id INT NOT NULL,
                reset_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uq_uid_quiz (uid, quiz_id)
            )
        """)
        cur.execute("""
            INSERT INTO daily_quiz_reset_students (uid, quiz_id)
            VALUES (%s, %s)
            ON DUPLICATE KEY UPDATE reset_at = CURRENT_TIMESTAMP
        """, (uid, quiz_id))
        conn.commit()

        return jsonify({"success": True, "message": "Student's quiz attempt has been reset"}), 200

    except Exception as e:
        if conn:
            conn.rollback()
        return generic_error_response(e)
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


@app.route("/api/faculty/student/quiz-marks", methods=["GET", "OPTIONS"])
@admin_token_required
def student_quiz_wise_marks(current_user):

    # ---------------- CORS ----------------
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    # ---------------- PARAMS ----------------
    uid = request.args.get("uid", type=int)
    year = request.args.get("year", type=int)

    if not uid:
        return jsonify({
            "success": False,
            "message": "uid required"
        }), 400

    conn = get_db()
    cur = conn.cursor(pymysql.cursors.DictCursor)

    try:
        # ==================================================
        # 1️⃣ FETCH STUDENT INFO
        # ==================================================
        cur.execute("""
            SELECT name, email, year, dept_id
            FROM students
            WHERE uid = %s
        """, (uid,))
        student = cur.fetchone()

        if student and current_user["role"] in ("hod", "faculty") and student.get("dept_id") != current_user["dept_id"]:
            return jsonify({
                "success": False,
                "message": "You can only view students in your own department"
            }), 403

        if not year:
            if student and student.get("year"):
                try:
                    year = int(student["year"])
                except Exception:
                    year = 2
            else:
                year = 2

        marks_table = f"assignment_quiz_marks_y{year}"

        # ---------------- ROLE SCOPING ----------------
        # faculty: only quizzes they created. hod: only quizzes created by
        # faculty/hod in their own department. super_admin/admin: unrestricted.
        scope_sql = ""
        scope_params = []
        if current_user["role"] == "faculty":
            scope_sql = "AND q.created_by = %s"
            scope_params = [current_user["email"]]
        elif current_user["role"] == "hod":
            scope_sql = "AND q.created_by IN (SELECT email FROM admins WHERE dept_id=%s AND role IN ('faculty','hod'))"
            scope_params = [current_user["dept_id"]]

        student_name = (
            student["name"]
            if student and student.get("name")
            else "NOT GIVEN"
        )
        student_email = (
            student["email"]
            if student and student.get("email")
            else "NOT GIVEN"
        )

        # ==================================================
        # 2️⃣ FETCH QUIZ + MARKS (CORRECT JOIN DIRECTION)
        # ==================================================
        cur.execute(f"""
            SELECT
                q.quiz_id,
                q.quiz_date,
                q.quiz_start_time,
                q.quiz_end_time,
                q.created_by,

                m.score,
                m.total_questions,
                m.submitted_at,

                fa.started_at

            FROM faculty_quiz_master q
            LEFT JOIN {marks_table} m
                ON q.quiz_id = m.quiz_id
                AND m.uid = %s
            LEFT JOIN faculty_quiz_attempts fa
                ON q.quiz_id = fa.quiz_id
                AND fa.uid = %s

            WHERE q.year = %s
            {scope_sql}

            ORDER BY
                q.quiz_date DESC,
                q.quiz_id DESC
        """, tuple([uid, uid, year] + scope_params))

        rows = cur.fetchall()
        data = []

        # ==================================================
        # 3️⃣ FINAL LOGIC
        # ==================================================
        for r in rows:

            # MARKS RULE (IMPORTANT)
            if r["score"] is None:
                marks_value = "NOT GIVEN"
                total_value = None
            else:
                marks_value = r["score"]
                total_value = r["total_questions"]

            time_taken_seconds = None
            if r["started_at"] and r["submitted_at"]:
                time_taken_seconds = int((r["submitted_at"] - r["started_at"]).total_seconds())

            data.append({
                "quiz_id": r["quiz_id"],

                # MARKS
                "marks": marks_value,
                "total_marks": total_value,

                # QUIZ INFO (ALWAYS FROM QUIZ MASTER)
                "quiz_date": r["quiz_date"],
                "start_time": (
                    str(r["quiz_start_time"])
                    if r["quiz_start_time"] else None
                ),
                "end_time": (
                    str(r["quiz_end_time"])
                    if r["quiz_end_time"] else None
                ),
                "created_by": r["created_by"],
                "can_reset": r["created_by"] == current_user["email"],

                # TIMING (test-start, test-submitted, total time taken)
                "started_at": str(r["started_at"]) if r["started_at"] else None,
                "submitted_at": str(r["submitted_at"]) if r["submitted_at"] else None,
                "time_taken_seconds": time_taken_seconds,
            })

        # ==================================================
        # 4️⃣ RESPONSE
        # ==================================================
        return jsonify({
            "success": True,
            "uid": uid,
            "year": year,
            "student_name": student_name,
            "email": student_email,
            "total_quizzes": len(data),
            "data": data
        })

    finally:
        cur.close()
        conn.close()

@app.route("/api/faculty/quiz/marks", methods=["GET", "OPTIONS"])
@admin_token_required
def particular_quiz_marks(current_user):

    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    quiz_id = request.args.get("quiz_id", type=int)
    year = request.args.get("year", type=int)

    if not quiz_id or year not in (1, 2, 3, 4):
        return jsonify({
            "success": False,
            "message": "quiz_id and valid year (2 or 3) required"
        }), 400

    marks_table = (
        f"assignment_quiz_marks_y{year}"
    )

    conn = get_db()
    cur = conn.cursor(pymysql.cursors.DictCursor)

    try:
        # =========================
        # QUIZ DETAILS
        # =========================
        cur.execute("""
            SELECT fqm.quiz_name, fqm.quiz_date, fqm.quiz_start_time, fqm.quiz_end_time,
                   fqm.created_by, fqm.department,
                   d.name as dept_name
            FROM faculty_quiz_master fqm
            LEFT JOIN departments d ON d.name = fqm.department
            WHERE fqm.quiz_id = %s AND fqm.year = %s
        """, (quiz_id, year))

        quiz = cur.fetchone()

        if not quiz:
            return jsonify({
                "success": False,
                "message": "Quiz not found"
            }), 404

        if not can_access_quiz(current_user, quiz["created_by"], cur):
            return jsonify({
                "success": False,
                "message": "Access denied"
            }), 403

        # =========================
        # STUDENTS + MARKS
        # =========================
        cur.execute(f"""
            SELECT
                s.uid,
                s.name,

                m.score,
                m.total_questions,
                m.submitted_at,

                fa.started_at

            FROM students s
            LEFT JOIN {marks_table} m
                ON s.uid = m.uid
                AND m.quiz_id = %s
            LEFT JOIN faculty_quiz_attempts fa
                ON s.uid = fa.uid
                AND fa.quiz_id = %s

            WHERE s.year = %s
            ORDER BY s.uid ASC
        """, (quiz_id, quiz_id, year))

        rows = cur.fetchall()
        data = []

        for r in rows:
            if r["score"] is None:
                marks = "NOT GIVEN"
                total = None
            else:
                marks = r["score"]
                total = r["total_questions"]

            time_taken_seconds = None
            if r["started_at"] and r["submitted_at"]:
                time_taken_seconds = int((r["submitted_at"] - r["started_at"]).total_seconds())

            data.append({
                "uid": r["uid"],
                "name": r["name"],
                "marks": marks,
                "total_marks": total,
                "started_at": str(r["started_at"]) if r["started_at"] else None,
                "submitted_at": str(r["submitted_at"]) if r["submitted_at"] else None,
                "time_taken_seconds": time_taken_seconds,
            })

        return jsonify({
            "success": True,
            "quiz_id": quiz_id,
            "year": year,
            "quiz_name": quiz["quiz_name"],
            "quiz_date": quiz["quiz_date"],
            "start_time": str(quiz["quiz_start_time"]) if quiz["quiz_start_time"] else None,
            "end_time": str(quiz["quiz_end_time"]) if quiz["quiz_end_time"] else None,
            "created_by": quiz["created_by"],
            "department": quiz.get("department") or "",
            "dept_name": quiz.get("dept_name") or quiz.get("department") or "",
            "can_reset": quiz["created_by"] == current_user["email"],
            "total_students": len(data),
            "data": data
        })

    finally:
        cur.close()
        conn.close()


@app.route("/api/admin/faculty-quiz/reset-student", methods=["POST", "OPTIONS"])
@admin_token_required
def reset_faculty_quiz_for_student(admin):
    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    data = request.get_json() or {}
    quiz_id = data.get("quiz_id")
    uid = data.get("uid")

    if not quiz_id or not uid:
        return jsonify({"success": False, "message": "quiz_id and uid are required"}), 400

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)

        cur.execute("SELECT year, created_by FROM faculty_quiz_master WHERE quiz_id=%s", (quiz_id,))
        quiz = cur.fetchone()
        if not quiz:
            return jsonify({"success": False, "message": "Quiz not found"}), 404

        # Same rule as the Ai Quiz's reset: only the quiz's own creator may
        # reset a student's attempt on it.
        if quiz.get("created_by") != admin["email"]:
            return jsonify({"success": False, "message": "Only the quiz creator can reset a student's attempt"}), 403

        marks_table = f"assignment_quiz_marks_y{quiz['year']}"

        conn.begin()
        cur.execute(f"DELETE FROM {marks_table} WHERE uid=%s AND quiz_id=%s", (uid, quiz_id))
        cur.execute("DELETE FROM faculty_quiz_attempts WHERE uid=%s AND quiz_id=%s", (uid, quiz_id))
        cur.execute("DELETE FROM faculty_quiz_autosave WHERE uid=%s AND quiz_id=%s", (uid, quiz_id))
        conn.commit()

        return jsonify({"success": True, "message": "Student's quiz attempt has been reset"}), 200
    except Exception as e:
        if conn:
            conn.rollback()
        return generic_error_response(e)
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


@app.route("/api/admin/leaderboard/daily", methods=["GET", "OPTIONS"])
@admin_token_required
def admin_daily_quiz_leaderboard(current_user):

    if request.method == "OPTIONS":
        return jsonify({"success": True}), 200

    year = request.args.get("year")
    lb_type = request.args.get("type", "all")
    month = request.args.get("month")
    dept_id = request.args.get("dept_id", type=int)

    if year not in ["1", "2", "3", "4"]:
        return jsonify({"success": False, "message": "Invalid year"}), 400

    if lb_type not in ["month", "all"]:
        return jsonify({"success": False, "message": "Invalid type"}), 400

    # hod/faculty are scoped to their own department; super_admin/admin
    # may optionally narrow by department via dept_id.
    if current_user["role"] in ("hod", "faculty"):
        dept_id = current_user["dept_id"]

    attempts_table = f"daily_quiz_attempts_y{year}"
    marks_table = f"assignment_quiz_marks_y{year}"

    date_filter = ""
    params = [year]

    if lb_type == "month":
        if not month:
            return jsonify({"success": False, "message": "Month required"}), 400
        date_filter = "AND MONTH(combined.quiz_date) = %s"
        params.append(month)

    dept_filter = "AND s.dept_id = %s" if dept_id else ""

    conn = get_db()
    cur = conn.cursor(pymysql.cursors.DictCursor)

    query = """
        SELECT
            s.uid,
            s.name,
            SUM(combined.score) AS total_marks,
            SUM(combined.total) AS total_out_of
        FROM (
            SELECT uid, score, total, quiz_date FROM {attempts_table}
            UNION ALL
            SELECT uid, score, total_questions AS total, quiz_date FROM {marks_table}
        ) combined
        JOIN students s ON s.uid = combined.uid
        WHERE s.year = %s
        {date_filter}
        {dept_filter}
        GROUP BY s.uid, s.name
        ORDER BY total_marks DESC
    """.format(attempts_table=attempts_table, marks_table=marks_table, date_filter=date_filter, dept_filter=dept_filter)
    if dept_id:
        params.append(dept_id)
    cur.execute(query, params)

    rows = cur.fetchall()

    cur.close()
    conn.close()

    return jsonify({
        "success": True,
        "data": rows
    }), 200


import sys
print("=== REGISTERED ROUTES (EOF) ===", file=sys.stderr)
for rule in app.url_map.iter_rules():
    print(f"  {rule.rule} {list(rule.methods)}", file=sys.stderr)
print("==============================", file=sys.stderr)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print("=== STARTING SERVER - REGISTERED ROUTES ===")
    for rule in app.url_map.iter_rules():
        print(f"  {rule.rule} {list(rule.methods)}")
    recover_interrupted_daily_quizzes()
    threading.Thread(target=run_daily_quiz_maintenance, daemon=True).start()
    app.run(
        host="0.0.0.0",
        port=port,
        threaded=True  # without this, Flask's dev server handles one
                        # request at a time - with 18 Gemini worker threads
                        # and real concurrent students hitting the API, that
                        # serializes everything behind whatever request (or
                        # background DB query) is currently running.
    )
