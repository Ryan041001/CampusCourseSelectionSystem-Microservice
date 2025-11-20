-- Catalog DB initialization
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

CREATE DATABASE IF NOT EXISTS catalog_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE catalog_db;

-- Create/ensure table for courses (similar to monolith courses table)
CREATE TABLE IF NOT EXISTS courses (
    id VARCHAR(36) PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    title VARCHAR(300) NOT NULL,
    instructor_id VARCHAR(36),
    instructor_name VARCHAR(100) NOT NULL,
    instructor_email VARCHAR(100),
    day_of_week ENUM('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY','SUNDAY'),
    start_time VARCHAR(10),
    end_time VARCHAR(10),
    expected_attendance INT DEFAULT 0,
    capacity INT NOT NULL,
    enrolled INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample courses
INSERT INTO courses (id, code, title, instructor_id, instructor_name, instructor_email, day_of_week, start_time, end_time, expected_attendance, capacity, enrolled)
VALUES
  ('course-uuid-001', 'CS101', '数据结构与算法', 'instructor-001', '张教授', 'zhang@zjgsu.edu.cn', 'MONDAY', '08:00', '10:00', 50, 60, 5),
  ('course-uuid-002', 'CS102', '操作系统原理', 'instructor-002', '李教授', 'li@zjgsu.edu.cn', 'TUESDAY', '10:00', '12:00', 45, 50, 2),
  ('course-uuid-003', 'CS201', '计算机网络', 'instructor-003', '王老师', 'wang@zjgsu.edu.cn', 'WEDNESDAY', '14:00', '16:00', 40, 55, 1)
ON DUPLICATE KEY UPDATE title=VALUES(title), instructor_name=VALUES(instructor_name), capacity=VALUES(capacity), enrolled=VALUES(enrolled);
