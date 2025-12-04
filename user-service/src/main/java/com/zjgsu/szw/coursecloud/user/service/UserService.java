package com.zjgsu.szw.coursecloud.user.service;

import com.zjgsu.szw.coursecloud.user.exception.ResourceNotFoundException;
import com.zjgsu.szw.coursecloud.user.model.User;
import com.zjgsu.szw.coursecloud.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Pattern;

@Service
public class UserService {

    private static final Pattern EMAIL_PATTERN = Pattern.compile("^[A-Za-z0-9+_.-]+@(.+)$");

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public List<User> findAll() {
        return userRepository.findAll();
    }

    public Optional<User> findByStudentId(String studentId) {
        return userRepository.findByStudentId(studentId);
    }

    public Optional<User> findByIdOrStudentId(String idOrStudentId) {
        Optional<User> byStudentId = userRepository.findByStudentId(idOrStudentId);
        if (byStudentId.isPresent()) {
            return byStudentId;
        }
        return userRepository.findById(idOrStudentId);
    }

    public User getRequiredByStudentId(String studentId) {
        return userRepository.findByStudentId(studentId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with studentId: " + studentId));
    }

    public User createUser(User user) {
        validateUser(user);

        if (userRepository.existsByStudentId(user.getStudentId())) {
            throw new IllegalArgumentException("Student ID already exists: " + user.getStudentId());
        }

        if (user.getEmail() != null && userRepository.existsByEmail(user.getEmail())) {
            throw new IllegalArgumentException("Email already exists: " + user.getEmail());
        }

        // 保证主键存在
        if (user.getId() == null || user.getId().isEmpty()) {
            user.setId(UUID.randomUUID().toString());
        }
        user.setDeleted(Boolean.FALSE);
        return userRepository.save(user);
    }

    @Transactional
    public User updateUser(String idOrStudentId, User user) {
        User existing = findByIdOrStudentId(idOrStudentId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + idOrStudentId));

        validateUser(user);

        Optional<User> duplicateStudent = userRepository.findByStudentId(user.getStudentId());
        if (duplicateStudent.isPresent() && !duplicateStudent.get().getId().equals(existing.getId())) {
            throw new IllegalArgumentException("Student ID already exists: " + user.getStudentId());
        }

        if (user.getEmail() != null && !user.getEmail().isEmpty()) {
            Optional<User> duplicateEmail = userRepository.findByEmail(user.getEmail());
            if (duplicateEmail.isPresent() && !duplicateEmail.get().getId().equals(existing.getId())) {
                throw new IllegalArgumentException("Email already exists: " + user.getEmail());
            }
        }

        if (user.getEmail() != null && !EMAIL_PATTERN.matcher(user.getEmail()).matches()) {
            throw new IllegalArgumentException("Invalid email format: " + user.getEmail());
        }

        user.setId(existing.getId());
        user.setCreatedAt(existing.getCreatedAt());
        user.setDeleted(Boolean.FALSE);
        return userRepository.save(user);
    }

    @Transactional
    public void deleteUser(String idOrStudentId) {
        User existing = findByIdOrStudentId(idOrStudentId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + idOrStudentId));
        userRepository.delete(existing);
    }

    public boolean existsByStudentId(String studentId) {
        return userRepository.existsByStudentId(studentId);
    }

    private void validateUser(User user) {
        if (user.getStudentId() == null || user.getStudentId().trim().isEmpty()) {
            throw new IllegalArgumentException("Student ID is required");
        }
        if (user.getName() == null || user.getName().trim().isEmpty()) {
            throw new IllegalArgumentException("Name is required");
        }
        if (user.getMajor() == null || user.getMajor().trim().isEmpty()) {
            throw new IllegalArgumentException("Major is required");
        }
        if (user.getGrade() == null) {
            throw new IllegalArgumentException("Grade is required");
        }
        if (user.getEmail() == null || user.getEmail().trim().isEmpty()) {
            throw new IllegalArgumentException("Email is required");
        }
        if (!EMAIL_PATTERN.matcher(user.getEmail()).matches()) {
            throw new IllegalArgumentException("Invalid email format: " + user.getEmail());
        }
    }
}

