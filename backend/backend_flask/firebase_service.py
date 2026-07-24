import os
import json
import firebase_admin
from firebase_admin import credentials, messaging
from db import get_db
import pymysql.cursors

BRANCH_TO_DEPT_ID = {
    "AI": 7, "DS": 8, "CSE": 2, "IT": 5, "ETC": 3, "MECH": 6,
    "CIVIL": 1, "EE": 4, "CS-CY": 10, "CSBS": 11, "IIOT": 9, "RAI": 12
}

_firebase_initialized = False

def init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return True
        
    env_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
    if env_json:
        try:
            raw_str = env_json.strip()
            if (raw_str.startswith("'") and raw_str.endswith("'")) or (raw_str.startswith('"') and raw_str.endswith('"')):
                raw_str = raw_str[1:-1].strip()
            
            try:
                cert_dict = json.loads(raw_str)
            except Exception:
                # Fallback: try base64 decoding if user pasted base64
                import base64
                decoded_bytes = base64.b64decode(raw_str)
                cert_dict = json.loads(decoded_bytes.decode('utf-8'))
                
            if isinstance(cert_dict, str):
                cert_dict = json.loads(cert_dict)
                
            if isinstance(cert_dict, dict) and "private_key" in cert_dict:
                pk = cert_dict["private_key"]
                if isinstance(pk, str):
                    pk = pk.replace("\\n", "\n").replace("\r\n", "\n")
                    cert_dict["private_key"] = pk
                    
            cred = credentials.Certificate(cert_dict)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            print("[FCM] Firebase Admin SDK initialized from environment variable.")
            return True
        except Exception as e:
            print(f"[FCM] Error loading from FIREBASE_SERVICE_ACCOUNT_JSON env var: {e}")

    key_path = os.path.join(os.path.dirname(__file__), "firebase-service-account.json")
    if os.path.exists(key_path):
        try:
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            print("[FCM] Firebase Admin SDK initialized from local file.")
            return True
        except Exception as e:
            print(f"[FCM] Failed to initialize Firebase Admin SDK: {e}")
            return False
            
    print("[FCM] No Firebase service account found in env or local file.")
    return False


def get_student_fcm_tokens(year=None, department=None):
    conn = None
    cur = None
    tokens = []
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        
        query = "SELECT fcm_token FROM students WHERE fcm_token IS NOT NULL AND fcm_token != ''"
        params = []
        
        if year:
            query += " AND CAST(year AS CHAR) = %s"
            params.append(str(year).strip())
            
        if department and str(department).upper() != "ALL":
            dept_id = BRANCH_TO_DEPT_ID.get(department)
            if dept_id:
                query += " AND (branch = %s OR dept_id = %s)"
                params.extend([department, dept_id])
            else:
                query += " AND branch = %s"
                params.append(department)
            
        cur.execute(query, tuple(params))
        rows = cur.fetchall()
        tokens = [r["fcm_token"] for r in rows if r.get("fcm_token")]
    except Exception as e:
        print(f"[FCM] Error fetching student tokens: {e}")
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()
    return list(set(tokens))


def get_student_fcm_tokens_by_uids(uids):
    if not uids:
        return []
    conn = None
    cur = None
    tokens = []
    try:
        conn = get_db()
        cur = conn.cursor(pymysql.cursors.DictCursor)
        placeholders = ",".join(["%s"] * len(uids))
        query = f"SELECT fcm_token FROM students WHERE uid IN ({placeholders}) AND fcm_token IS NOT NULL AND fcm_token != ''"
        cur.execute(query, list(uids))
        rows = cur.fetchall()
        tokens = [r["fcm_token"] for r in rows if r.get("fcm_token")]
    except Exception as e:
        print(f"[FCM] Error fetching tokens by UIDs: {e}")
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()
    return list(set(tokens))


def send_fcm_notification(fcm_tokens, title, body, data=None):
    if not fcm_tokens:
        return 0
    if not init_firebase():
        return 0
    
    clean_tokens = list(set([t for t in fcm_tokens if t and isinstance(t, str)]))
    if not clean_tokens:
        return 0
    
    batch_size = 500
    total_sent = 0
    
    for i in range(0, len(clean_tokens), batch_size):
        batch = clean_tokens[i:i + batch_size]
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            tokens=batch,
        )
        try:
            response = messaging.send_each_for_multicast(message)
            total_sent += response.success_count
            print(f"[FCM] Sent batch of {len(batch)} notifications: {response.success_count} succeeded, {response.failure_count} failed.")
            if response.failure_count > 0:
                for idx, resp in enumerate(response.responses):
                    if not resp.success:
                        print(f"[FCM Failure Detail] Token index {idx} error: {resp.exception}")
        except Exception as e:
            print(f"[FCM] Error sending multicast batch: {e}")
            
    return total_sent


def format_time_str(time_str):
    if not time_str or not isinstance(time_str, str):
        return time_str
    try:
        parts = time_str.split(':')
        if len(parts) >= 2:
            hh = int(parts[0])
            mm = int(parts[1])
            ampm = "AM" if hh < 12 else "PM"
            hh12 = hh % 12
            if hh12 == 0:
                hh12 = 12
            return f"{hh12:02d}:{mm:02d} {ampm}"
    except Exception:
        pass
    return time_str


# 📢 TYPE 1: Quiz Published (Daily & Faculty)
def notify_quiz_published(year, department, subject_name, start_time_str, is_faculty_quiz=False, quiz_title=None):
    tokens = get_student_fcm_tokens(year, department)
    if not tokens:
        return
    formatted_start = format_time_str(start_time_str)
    if is_faculty_quiz:
        title = "📚 New Faculty Quiz Published"
        body = f"'{quiz_title or subject_name}' ({subject_name}) is published! Starts at {formatted_start}."
    else:
        title = "📚 New Daily Quiz Published"
        body = f"{subject_name} quiz is scheduled for today at {formatted_start}. Get ready!"
    
    send_fcm_notification(tokens, title, body, data={"type": "quiz_published", "year": str(year)})


# 🚀 TYPE 2: Quiz Started
def notify_quiz_started(year, department, subject_name):
    tokens = get_student_fcm_tokens(year, department)
    if not tokens:
        return
    title = "🚀 Quiz is Live Now!"
    body = f"{subject_name} quiz has started! Open SkillSphere to attempt your quiz."
    send_fcm_notification(tokens, title, body, data={"type": "quiz_started", "year": str(year)})


# ⏳ TYPE 6: 10 Minutes Before Quiz Starts
def notify_quiz_starting_soon(year, department, subject_name, target_uids):
    tokens = get_student_fcm_tokens_by_uids(target_uids)
    if not tokens:
        return
    title = "⏳ Quiz Starting in 10 Minutes!"
    body = f"{subject_name} quiz starts in 10 minutes! Get ready to attempt."
    send_fcm_notification(tokens, title, body, data={"type": "quiz_starting_soon", "year": str(year)})


# ⚠️ TYPE 3: 10 Minutes Before Quiz Ends (Unattempted Students Only)
def notify_quiz_expiring_soon(year, department, subject_name, unattempted_uids):
    tokens = get_student_fcm_tokens_by_uids(unattempted_uids)
    if not tokens:
        return
    title = "⏰ 10 Minutes Remaining!"
    body = f"You have not attempted the {subject_name} quiz yet. Only 10 minutes left before it closes!"
    send_fcm_notification(tokens, title, body, data={"type": "quiz_expiring_soon", "year": str(year)})


# 📝 TYPE 4: Faculty Quiz Answer Key Released
def notify_answer_key_released(year, department, quiz_title):
    tokens = get_student_fcm_tokens(year, department)
    if not tokens:
        return
    title = "📝 Quiz Answers Released"
    body = f"Answer key & results for '{quiz_title}' are now available in SkillSphere."
    send_fcm_notification(tokens, title, body, data={"type": "answer_key_released", "year": str(year)})


# 🔄 TYPE 5: Quiz Timing Resetted / Updated
def notify_quiz_time_updated(year, department, subject_name, start_time_str, end_time_str):
    tokens = get_student_fcm_tokens(year, department)
    if not tokens:
        return
    formatted_start = format_time_str(start_time_str)
    formatted_end = format_time_str(end_time_str)
    title = "⏳ Quiz Timing Updated"
    body = f"{subject_name} quiz timing has been updated to {formatted_start} - {formatted_end}."
    send_fcm_notification(tokens, title, body, data={"type": "time_updated", "year": str(year)})
