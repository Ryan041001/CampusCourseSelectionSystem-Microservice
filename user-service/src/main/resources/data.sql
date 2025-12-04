-- User Service Initial Test Data
-- Database: user_db

-- Insert test users (only if not exists)
INSERT IGNORE INTO users (id, student_id, name, major, grade, email, deleted, created_at) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'S2024001', '张三', '计算机科学与技术', 2024, 'zhangsan@zjgsu.edu.cn', FALSE, NOW()),
('550e8400-e29b-41d4-a716-446655440002', 'S2024002', '李四', '软件工程', 2024, 'lisi@zjgsu.edu.cn', FALSE, NOW()),
('550e8400-e29b-41d4-a716-446655440003', 'S2024003', '王五', '信息安全', 2024, 'wangwu@zjgsu.edu.cn', FALSE, NOW()),
('550e8400-e29b-41d4-a716-446655440004', 'S2023001', '赵六', '计算机科学与技术', 2023, 'zhaoliu@zjgsu.edu.cn', FALSE, NOW()),
('550e8400-e29b-41d4-a716-446655440005', 'S2023002', '孙七', '软件工程', 2023, 'sunqi@zjgsu.edu.cn', FALSE, NOW()),
('550e8400-e29b-41d4-a716-446655440006', 'S2023003', '周八', '数据科学', 2023, 'zhouba@zjgsu.edu.cn', FALSE, NOW()),
('550e8400-e29b-41d4-a716-446655440007', 'S2022001', '吴九', '计算机科学与技术', 2022, 'wujiu@zjgsu.edu.cn', FALSE, NOW()),
('550e8400-e29b-41d4-a716-446655440008', 'S2022002', '郑十', '人工智能', 2022, 'zhengshi@zjgsu.edu.cn', FALSE, NOW());
