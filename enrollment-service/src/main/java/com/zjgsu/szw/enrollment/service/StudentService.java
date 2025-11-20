package com.zjgsu.szw.enrollment.service;

import com.zjgsu.szw.enrollment.exception.ResourceNotFoundException;
import com.zjgsu.szw.enrollment.model.Student;
import com.zjgsu.szw.enrollment.repository.EnrollmentRepository;
import com.zjgsu.szw.enrollment.repository.StudentRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * 学生业务逻辑层
 */
@Service
public class StudentService {
    private final StudentRepository studentRepository;
    private final EnrollmentRepository enrollmentRepository;
    private static final Pattern EMAIL_PATTERN = Pattern.compile("^[A-Za-z0-9+_.-]+@(.+)$");

    public StudentService(StudentRepository studentRepository, EnrollmentRepository enrollmentRepository) {
        this.studentRepository = studentRepository;
        this.enrollmentRepository = enrollmentRepository;
    }

    /**
     * 查询所有学生
     */
    public List<Student> findAll() {
        return studentRepository.findAll();
    }

    /**
     * 根据ID查询学生（优先使用学号查询，兼容UUID）
     */
    public Optional<Student> findById(String id) {
        // 先尝试用学号查询
        Optional<Student> byStudentId = studentRepository.findByStudentId(id);
        if (byStudentId.isPresent()) {
            return byStudentId;
        }
        // 如果找不到，再尝试用UUID查询（向后兼容）
        return studentRepository.findById(id);
    }

    /**
     * 创建学生
     */
    public Student createStudent(Student student) {
        // 验证必填字段
        validateStudent(student);

        // 检查学号是否已存在
        if (studentRepository.existsByStudentId(student.getStudentId())) {
            throw new IllegalArgumentException("Student ID already exists: " + student.getStudentId());
        }

        // 检查邮箱是否已存在
        if (studentRepository.existsByEmail(student.getEmail())) {
            throw new IllegalArgumentException("Email already exists: " + student.getEmail());
        }

        // 验证邮箱格式
        if (!EMAIL_PATTERN.matcher(student.getEmail()).matches()) {
            throw new IllegalArgumentException("Invalid email format: " + student.getEmail());
        }

        // 生成UUID作为主键ID
        student.setId(UUID.randomUUID().toString());
        return studentRepository.save(student);
    }

    /**
     * 更新学生信息
     */
    @Transactional
    public Student updateStudent(String id, Student student) {
        // 先查找学生（支持学号或UUID）
        Optional<Student> existingOpt = findById(id);
        if (!existingOpt.isPresent()) {
            throw new ResourceNotFoundException("Student not found with id: " + id);
        }
        Student existing = existingOpt.get();

        // 验证必填字段
        validateStudent(student);

        // 检查学号是否与其他学生重复
        Optional<Student> duplicateCheck = studentRepository.findByStudentId(student.getStudentId());
        if (duplicateCheck.isPresent() && !duplicateCheck.get().getId().equals(existing.getId())) {
            throw new IllegalArgumentException("Student ID already exists: " + student.getStudentId());
        }

        // 检查邮箱是否与其他学生重复
        Optional<Student> emailCheck = studentRepository.findByEmail(student.getEmail());
        if (emailCheck.isPresent() && !emailCheck.get().getId().equals(existing.getId())) {
            throw new IllegalArgumentException("Email already exists: " + student.getEmail());
        }

        // 验证邮箱格式
        if (!EMAIL_PATTERN.matcher(student.getEmail()).matches()) {
            throw new IllegalArgumentException("Invalid email format: " + student.getEmail());
        }

        // 使用原有的UUID
        student.setId(existing.getId());
        return studentRepository.save(student);
    }

    /**
     * 删除学生
     */
    @Transactional
    public void deleteStudent(String id) {
        // 先查找学生（支持学号或UUID）
        Optional<Student> studentOpt = findById(id);
        if (!studentOpt.isPresent()) {
            throw new ResourceNotFoundException("Student not found with id: " + id);
        }
        Student student = studentOpt.get();

        // 检查是否有选课记录（用学号查询选课记录）
        if (!enrollmentRepository.findByStudentId(student.getStudentId()).isEmpty()) {
            throw new IllegalArgumentException("无法删除: 该学生存在选课记录");
        }

        // 用UUID删除
        studentRepository.deleteById(student.getId());
    }

    /**
     * 检查学生是否存在
     */
    public boolean existsById(String id) {
        return studentRepository.existsById(id);
    }

    /**
     * 验证学生必填字段
     */
    private void validateStudent(Student student) {
        if (student.getStudentId() == null || student.getStudentId().trim().isEmpty()) {
            throw new IllegalArgumentException("Student ID is required");
        }
        if (student.getName() == null || student.getName().trim().isEmpty()) {
            throw new IllegalArgumentException("Name is required");
        }
        if (student.getMajor() == null || student.getMajor().trim().isEmpty()) {
            throw new IllegalArgumentException("Major is required");
        }
        if (student.getGrade() == null) {
            throw new IllegalArgumentException("Grade is required");
        }
        if (student.getEmail() == null || student.getEmail().trim().isEmpty()) {
            throw new IllegalArgumentException("Email is required");
        }
    }
}
