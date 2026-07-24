from locust import HttpUser, task, between, constant

ADMIN_JWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhZG1pbl91aWQiOiJiZDExMGNjMi04NjJiLTQyODEtYjcxZS0zOGI4YWYxNjAxNWQiLCJ0eXBlIjoiYWRtaW4iLCJyb2xlIjoic3VwZXJfYWRtaW4iLCJkZXB0X2lkIjpudWxsLCJleHAiOjE4MTY0MjE5MTl9.DBu0OAiWEQA7V_dxiP1xk0-FDqOPz8Oqo7_GtK2NwNQ"
STUDENT_JWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOjE1MSwiZW1haWwiOiJiYXB1ODc4NDhAZ21haWwuY29tIiwieWVhciI6IjIiLCJleHAiOjE4MTY0MjE5MTl9.wq3xC9A2b1DCoPqxr_OvtNW3nPQUDfpzRiKHggqnb9Q"

class SkillSphereUser(HttpUser):
    wait_time = constant(0)

    def on_start(self):
        self.admin_headers = {
            "Authorization": f"Bearer {ADMIN_JWT}"
        }
        self.student_headers = {
            "Authorization": f"Bearer {STUDENT_JWT}"
        }

    # ==============================
    # 1. PUBLIC ENDPOINTS (Zero Auth)
    # ==============================
    @task(3)
    def public_departments(self):
        self.client.get("/api/public/departments", name="GET /api/public/departments")

    # ==============================
    # 2. STUDENT APP ENDPOINTS
    # ==============================
    @task(4)
    def student_profile(self):
        self.client.get("/get_student_profile", headers=self.student_headers, name="GET /get_student_profile")

    @task(4)
    def student_today_quizzes(self):
        self.client.get("/api/profile/today/quizzes", headers=self.student_headers, name="GET /api/profile/today/quizzes")

    @task(3)
    def student_today_status(self):
        self.client.get("/api/quiz/today/status", headers=self.student_headers, name="GET /api/quiz/today/status")

    # ==============================
    # 3. ADMIN DASHBOARD ENDPOINTS
    # ==============================
    @task(3)
    def admin_students_list(self):
        self.client.get("/api/admin/students?year=2", headers=self.admin_headers, name="GET /api/admin/students?year=2")

    @task(3)
    def admin_faculty_quizzes(self):
        self.client.get("/api/admin/faculty-quiz/list", headers=self.admin_headers, name="GET /api/admin/faculty-quiz/list")

    @task(2)
    def admin_leaderboard(self):
        self.client.get("/api/admin/leaderboard/daily?year=2&type=all", headers=self.admin_headers, name="GET /api/admin/leaderboard/daily")
