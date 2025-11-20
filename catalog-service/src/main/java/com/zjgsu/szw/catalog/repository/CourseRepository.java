package com.zjgsu.szw.catalog.repository;

import com.zjgsu.szw.catalog.model.Course;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 课程数据访问层
 * 使用 Spring Data JPA
 */
@Repository
public interface CourseRepository extends JpaRepository<Course, String> {

    /**
     * 根据课程代码查询课程
     */
    Optional<Course> findByCode(String code);

    /**
     * 根据讲师ID查询课程
     */
    @Query("SELECT c FROM Course c WHERE c.instructor.id = :instructorId")
    List<Course> findByInstructorId(@Param("instructorId") String instructorId);

    /**
     * 查询有剩余容量的课程
     */
    @Query("SELECT c FROM Course c WHERE c.enrolled < c.capacity")
    List<Course> findAvailableCourses();

    /**
     * 按标题关键字模糊查询
     */
    List<Course> findByTitleContaining(String keyword);
}
