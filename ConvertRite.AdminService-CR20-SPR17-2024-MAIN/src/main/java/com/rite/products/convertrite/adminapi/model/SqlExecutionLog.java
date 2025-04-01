package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;

import java.util.Date;

@Entity
@Table(name = "cr_sql_execution_log")
public class SqlExecutionLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "client_id")
    private Long clientId;

    @Column(name = "pod_id")
    private Long podId;

    @Column(name = "sql_file_path")
    private String sqlFilePath;

    @Column(name = "created_time")
    private Date createdTime;

    @Column(name = "success")
    private Boolean success;


    // Getters and setters

    public Long getId() {
        return id;
    }

    public Long getClientId() {
        return clientId;
    }

    public Long getPodId() {
        return podId;
    }

    public String getSqlFilePath() {
        return sqlFilePath;
    }

    public Date getCreatedTime() {
        return createdTime;
    }

    // Setters
    public void setId(Long id) {
        this.id = id;
    }

    public void setClientId(Long clientId) {
        this.clientId = clientId;
    }

    public void setPodId(Long podId) {
        this.podId = podId;
    }

    public void setSqlFilePath(String sqlFilePath) {
        this.sqlFilePath = sqlFilePath;
    }

    public void setCreatedTime(Date createdTime) {
        this.createdTime = createdTime;
    }

    public void setSuccess(Boolean success) {
        this.success = success;
    }

    public Boolean getSuccess() {
        return success;
    }
}
