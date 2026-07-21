import os
import json
import csv
import pymysql
from dotenv import load_dotenv

# Load environment
dotenv_path = os.path.join(os.path.dirname(__file__), ".env")
load_dotenv(dotenv_path)

# DB config
MYSQL_HOST = os.getenv("MYSQL_HOST")
MYSQL_USER = os.getenv("MYSQL_USER")
MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD")
MYSQL_DB = os.getenv("MYSQL_DB")

def get_db():
    return pymysql.connect(
        host=MYSQL_HOST,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
        database=MYSQL_DB,
        cursorclass=pymysql.cursors.DictCursor
    )

def main():
    conn = get_db()
    cur = conn.cursor()
    
    # Select all pregenerated questions
    cur.execute("SELECT uid, quiz_type, questions_json FROM test_pregenerated_questions")
    rows = cur.fetchall()
    
    csv_file_path = os.path.join(os.path.dirname(__file__), "data_warehousing_questions.csv")
    
    # CSV Columns: Question, Option A, Option B, Option C, Option D, Correct Answer, Topic
    headers = ["student_uid", "topic", "question", "option_a", "option_b", "option_c", "option_d", "correct_answer"]
    
    question_count = 0
    with open(csv_file_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        
        for row in rows:
            uid = row["uid"]
            topic = row["quiz_type"]
            try:
                questions = json.loads(row["questions_json"])
                for q in questions:
                    options = q.get("options", ["", "", "", ""])
                    
                    # Clean up option prefixes (A), B), etc. if present)
                    opt_a = re_clean_prefix(options[0]) if len(options) > 0 else ""
                    opt_b = re_clean_prefix(options[1]) if len(options) > 1 else ""
                    opt_c = re_clean_prefix(options[2]) if len(options) > 2 else ""
                    opt_d = re_clean_prefix(options[3]) if len(options) > 3 else ""
                    
                    writer.writerow([
                        uid,
                        topic,
                        q.get("question", ""),
                        opt_a,
                        opt_b,
                        opt_c,
                        opt_d,
                        q.get("answer", "")
                    ])
                    question_count += 1
            except Exception as e:
                print(f"Error parsing JSON for uid {uid}: {e}")
                
    cur.close()
    conn.close()
    print(f"Successfully exported {question_count} questions to '{csv_file_path}'.")

def re_clean_prefix(option_text):
    # Removes A), B), A., B. prefixes if they exist
    return re.sub(r"^[A-D][\.\)\-]\s*", "", option_text).strip()

import re

if __name__ == '__main__':
    main()
