package com.zjgsu.szw.coursecloud.catalog.model;

import jakarta.persistence.*;

/**
 * 教师信息（嵌入式对象）
 * 作为 Course 实体的一部分，不单独建表
 */
@Embeddable
public class Instructor {
    @Column(name = "instructor_id", length = 36)
    private String id;

    @Column(name = "instructor_name", nullable = false, length = 100)
    private String name;

    @Column(name = "instructor_email", length = 100)
    private String email;

    public Instructor() {
    }

    public Instructor(String id, String name, String email) {
        this.id = id;
        this.name = name;
        this.email = email;
    }

    // Getters and Setters
    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }
}
