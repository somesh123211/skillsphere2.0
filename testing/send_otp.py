import os
import random
import datetime
import smtplib
from email.mime.text import MIMEText

# ---------------- CONFIG ----------------
SMTP_SERVER = "smtp-relay.brevo.com"
SMTP_PORT = 587
SMTP_USER = "9da39b001@smtp-brevo.com"   # provided login
# Put your Brevo SMTP password/key into env var BREVO_SMTP_PASS
SMTP_PASS = os.environ.get("BREVO_SMTP_PASS")

FROM_EMAIL = "techpallotine@gmail.com"    # change if you verified a different FROM address
OTP_TTL_SECONDS = 5 * 60  # 5 minutes
MAX_ATTEMPTS = 3
# ----------------------------------------

# in-memory store: email -> {otp, expires_at(datetime), attempts}
otp_store = {}

def generate_otp():
    return f"{random.randint(100000, 999999):06d}"

def load_template(otp, template_path="otp_template.html"):
    if not os.path.exists(template_path):
        raise FileNotFoundError(f"{template_path} not found. Put the template in the same folder.")
    with open(template_path, "r", encoding="utf-8") as f:
        html = f.read()
    html = html.replace("{{otp}}", otp).replace("{{year}}", str(datetime.datetime.now().year))
    return html

def send_email_smtp(to_email, subject, html_body):
    if not SMTP_PASS:
        raise EnvironmentError("BREVO_SMTP_PASS not set in environment. Set it before running.")
    msg = MIMEText(html_body, "html")
    msg["Subject"] = subject
    msg["From"] = FROM_EMAIL
    msg["To"] = to_email

    with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(SMTP_USER, SMTP_PASS)
        server.send_message(msg)

def send_otp_email(to_email):
    otp = generate_otp()
    html = load_template(otp)
    plain = f"Your OTP is {otp}. It expires in 5 minutes."

    # Send
    send_email_smtp(to_email, "Your Verification Code — Placement Portal", html)

    # store with expiry & attempts
    expires_at = datetime.datetime.utcnow() + datetime.timedelta(seconds=OTP_TTL_SECONDS)
    otp_store[to_email.lower()] = {"otp": otp, "expires_at": expires_at, "attempts": 0}

    # debug: print(otp) — remove in production
    print("OTP sent (for testing only):", otp)
    return otp

def is_expired(entry):
    return datetime.datetime.utcnow() > entry["expires_at"]

def verify_otp(email, entered):
    key = email.lower()
    if key not in otp_store:
        return False, "No OTP found for this email. Request a new OTP."
    entry = otp_store[key]
    if is_expired(entry):
        del otp_store[key]
        return False, "OTP expired. Request a new one."
    if entry["attempts"] >= MAX_ATTEMPTS:
        del otp_store[key]
        return False, "Maximum attempts exceeded. Request a new OTP."

    entry["attempts"] += 1
    if entered.strip() == entry["otp"]:
        del otp_store[key]
        return True, "OTP verified successfully."
    else:
        remaining = MAX_ATTEMPTS - entry["attempts"]
        if remaining <= 0:
            del otp_store[key]
            return False, "Invalid OTP. No attempts left — request a new OTP."
        else:
            return False, f"Invalid OTP. {remaining} attempt(s) left."

def terminal_flow():
    print("=== Placement Portal — OTP (terminal) ===")
    if not SMTP_PASS:
        print("ERROR: BREVO_SMTP_PASS not set. In PowerShell run:")
        print('$Env:BREVO_SMTP_PASS = "YOUR_NEW_SMTP_KEY"')
        return

    email = input("Enter your email address: ").strip()
    try:
        send_otp_email(email)
        print(f"OTP sent to {email}. It will expire in 5 minutes.")
    except Exception as e:
        print("Failed to send OTP —", e)
        return

    while True:
        action = input("\nEnter 'v' to verify, 'r' to resend, 'q' to quit: ").strip().lower()
        if action == "v":
            entered = input("Enter the OTP you received: ").strip()
            ok, msg = verify_otp(email, entered)
            if ok:
                print("\n✅", msg)
                break
            else:
                print("\n❌", msg)
                if "expired" in msg.lower() or "request a new" in msg.lower():
                    yn = input("Resend new OTP? (y/n): ").strip().lower()
                    if yn == "y":
                        try:
                            send_otp_email(email)
                            print("New OTP sent.")
                        except Exception as e:
                            print("Failed to resend —", e)
                            break
                    else:
                        break
        elif action == "r":
            try:
                send_otp_email(email)
                print("New OTP sent.")
            except Exception as e:
                print("Failed to resend —", e)
                break
        elif action == "q":
            print("Exiting.")
            break
        else:
            print("Unknown option. Type 'v', 'r', or 'q'.")

if __name__ == "__main__":
    terminal_flow()
