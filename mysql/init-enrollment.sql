-- Enrollment DB initialization
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

CREATE DATABASE IF NOT EXISTS enrollment_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE enrollment_db;

-- Students table
CREATE TABLE IF NOT EXISTS students (
    id VARCHAR(36) PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    major VARCHAR(200),
    grade INT,
    email VARCHAR(100) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Enrollments table
CREATE TABLE IF NOT EXISTS enrollments (
    id VARCHAR(36) PRIMARY KEY,
    course_id VARCHAR(36) NOT NULL,
    student_id VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_course_student (course_id, student_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sample students
INSERT INTO students (id, student_id, name, major, grade, email) VALUES
    ('student-uuid-001', 'S2024001', '张三', '计算机科学', 2024, 'zhangsan@student.zjgsu.edu.cn'),
    ('student-uuid-002', 'S2024002', '李四', '软件工程', 2024, 'lisi@student.zjgsu.edu.cn')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Sample enrollments
INSERT INTO enrollments (id, course_id, student_id, status) VALUES
    ('enrollment-001', 'course-uuid-001', 'S2024001', 'ACTIVE'),
    ('enrollment-002', 'course-uuid-001', 'S2024002', 'ACTIVE')
ON DUPLICATE KEY UPDATE enrolled_at=CURRENT_TIMESTAMP;

