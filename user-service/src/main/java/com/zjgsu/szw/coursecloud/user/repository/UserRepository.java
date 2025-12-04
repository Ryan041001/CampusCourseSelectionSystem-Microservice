package com.zjgsu.szw.coursecloud.user.repository;

import com.zjgsu.szw.coursecloud.user.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, String> {

    Optional<User> findByStudentId(String studentId);

    Optional<User> findByEmail(String email);

    boolean existsByStudentId(String studentId);

    boolean existsByEmail(String email);

    List<User> findByMajor(String major);

    List<User> findByGrade(Integer grade);
}

