-- User DB initialization
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

CREATE DATABASE IF NOT EXISTS user_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE user_db;

CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    major VARCHAR(200),
    grade INT,
    email VARCHAR(120) UNIQUE,
    deleted TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO users (id, student_id, name, major, grade, email, deleted)
VALUES
    ('user-uuid-001', '2024001', '张三', '计算机科学', 2024, 'zhangsan@student.zjgsu.edu.cn', 0),
    ('user-uuid-002', '2024002', '李四', '软件工程', 2024, 'lisi@student.zjgsu.edu.cn', 0)
ON DUPLICATE KEY UPDATE name = VALUES(name);

