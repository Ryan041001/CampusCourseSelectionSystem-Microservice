package com.zjgsu.szw.coursecloud.enrollment.repository;

import com.zjgsu.szw.coursecloud.enrollment.model.Student;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 学生数据访问层
 * 使用 Spring Data JPA
 */
@Repository
public interface StudentRepository extends JpaRepository<Student, String> {

    /**
     * 根据学号查询学生
     */
    Optional<Student> findByStudentId(String studentId);

    /**
     * 检查学号是否已存在
     */
    boolean existsByStudentId(String studentId);

    /**
     * 检查邮箱是否已存在
     */
    boolean existsByEmail(String email);

    /**
     * 根据邮箱查询学生
     */
    Optional<Student> findByEmail(String email);

    /**
     * 按专业查询学生
     */
    List<Student> findByMajor(String major);

    /**
     * 按年级查询学生
     */
    List<Student> findByGrade(Integer grade);

    /**
     * 按专业和年级查询学生
     */
    List<Student> findByMajorAndGrade(String major, Integer grade);
}
