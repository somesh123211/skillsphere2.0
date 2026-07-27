import random
import jwt
import datetime
from locust import HttpUser, task, constant

# Import app's actual JWT SECRET_KEY to sign valid student tokens
from app import SECRET_KEY

# Target live Render URL
LIVE_HOST = "https://skillsphere-2-qanz.onrender.com"

# Generate a pool of 50 student JWT tokens for realistic load simulation
STUDENT_TOKENS = []
for i in range(1001, 1051):
    payload = {
        "uid": i,
        "email": f"student{i}@stvincentngp.edu.in",
        "year": "3",
        "branch": "AI",
        "exp": datetime.datetime.utcnow() + datetime.timedelta(days=30)
    }
    t = jwt.encode(payload, SECRET_KEY, algorithm="HS256")
    STUDENT_TOKENS.append(t)


class HighConcurrencyQuizUser(HttpUser):
    host = LIVE_HOST
    wait_time = constant(0)  # Maximum throughput stress testing (0s delay)

    def on_start(self):
        token = random.choice(STUDENT_TOKENS)
        self.student_headers = {
            "Authorization": f"Bearer {token}"
        }

    @task(5)
    def fetch_daily_quiz_status(self):
        """Simulate student checking quiz status on dashboard"""
        self.client.get("/api/quiz/today/status", headers=self.student_headers, name="GET /api/quiz/today/status")

    @task(10)
    def fetch_daily_quiz_cached(self):
        """Simulate instant RAM cache quiz retrieval (Quiz ID 30)"""
        self.client.get("/daily_quiz?quiz_id=30", headers=self.student_headers, name="GET /daily_quiz (RAM Cache)")

    @task(3)
    def submit_daily_quiz_batch(self):
        """Simulate single-batch SQL quiz submission"""
        payload = {
            "quiz_id": 30,
            "time_taken_seconds": random.randint(120, 300),
            "answers": [
                {"question_id": 498 + i, "selected_answer": random.choice(["A", "B", "C", "D"])}
                for i in range(10)
            ]
        }
        with self.client.post("/api/quiz/submit", json=payload, headers=self.student_headers, name="POST /api/quiz/submit (Batch SQL)", catch_response=True) as response:
            if response.status_code in (200, 409):
                response.success()
            else:
                response.failure(f"Unexpected status code: {response.status_code}")

    @task(2)
    def fetch_faculty_quiz_list(self):
        """Simulate fetching faculty quiz list"""
        self.client.get("/faculty_quiz/list", headers=self.student_headers, name="GET /faculty_quiz/list")
