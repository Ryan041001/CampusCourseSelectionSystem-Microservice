package com.zjgsu.szw.enrollment.repository;

import com.zjgsu.szw.enrollment.model.Enrollment;
import com.zjgsu.szw.enrollment.model.EnrollmentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * 选课记录数据访问层
 * 使用 Spring Data JPA
 */
@Repository
public interface EnrollmentRepository extends JpaRepository<Enrollment, String> {

    /**
     * 根据课程ID查询选课记录
     */
    List<Enrollment> findByCourseId(String courseId);

    /**
     * 根据学生ID查询选课记录
     */
    List<Enrollment> findByStudentId(String studentId);

    /**
     * 检查学生是否已选某门课程
     */
    boolean existsByCourseIdAndStudentId(String courseId, String studentId);

    /**
     * 统计某课程的选课人数
     */
    long countByCourseId(String courseId);

    /**
     * 按状态查询选课记录
     */
    List<Enrollment> findByStatus(EnrollmentStatus status);

    /**
     * 按课程ID和状态查询选课记录
     */
    List<Enrollment> findByCourseIdAndStatus(String courseId, EnrollmentStatus status);

    /**
     * 按学生ID和状态查询选课记录
     */
    List<Enrollment> findByStudentIdAndStatus(String studentId, EnrollmentStatus status);

    /**
     * 统计某课程活跃选课人数（状态为ACTIVE）
     */
    @Query("SELECT COUNT(e) FROM Enrollment e WHERE e.courseId = ?1 AND e.status = 'ACTIVE'")
    long countActiveByCourseId(String courseId);
}
