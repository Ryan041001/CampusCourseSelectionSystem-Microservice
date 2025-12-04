-- Enrollment DB initialization
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

CREATE DATABASE IF NOT EXISTS enrollment_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE enrollment_db;

-- Enrollments table
CREATE TABLE IF NOT EXISTS enrollments (
    id VARCHAR(36) PRIMARY KEY,
    course_id VARCHAR(36) NOT NULL,
    student_id VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_course_student (course_id, student_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sample enrollments
INSERT INTO enrollments (id, course_id, student_id, status) VALUES
    ('enrollment-001', 'course-uuid-001', '2024001', 'ACTIVE'),
    ('enrollment-002', 'course-uuid-001', '2024002', 'ACTIVE')
ON DUPLICATE KEY UPDATE enrolled_at=CURRENT_TIMESTAMP;

