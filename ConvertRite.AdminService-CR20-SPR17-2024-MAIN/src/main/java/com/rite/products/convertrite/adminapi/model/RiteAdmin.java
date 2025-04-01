package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;

import java.sql.Date;

@Entity
@Table(name = "cr_admin_login")
public class RiteAdmin {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id", columnDefinition = "serial")
    private Long riteAdminId;

    @Column(name = "user_name")
    private String riteAdminUserName;

    @Column(name = "password")
    private String riteAdminPassword;

    @Column(name = "creation_date")
    private Date creationDate;
    @Column(name = "created_by")
    private String createdBy;
    @Column(name = "last_update_date")
    private Date lastUpdatedDate;
    @Column(name = "last_update_by")
    private String lastUpdatedBy;

    public Long getRiteAdminId() {
        return riteAdminId;
    }

    public void setRiteAdminId(Long rightAdminId) {
        this.riteAdminId = riteAdminId;
    }

    public String getRiteAdminUserName() {
        return riteAdminUserName;
    }

    public void setRiteAdminUserName(String riteAdminUserName) {
        this.riteAdminUserName = riteAdminUserName;
    }

    public String getRiteAdminPassword() {
        return riteAdminPassword;
    }

    public void setRiteAdminPassword(String riteAdminPassword) {
        this.riteAdminPassword = riteAdminPassword;
    }

    public Date getCreationDate() {
        return creationDate;
    }

    public void setCreationDate(Date creationDate) {
        this.creationDate = creationDate;
    }

    public String getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(String createdBy) {
        this.createdBy = createdBy;
    }

    public Date getLastUpdatedDate() {
        return lastUpdatedDate;
    }

    public void setLastUpdatedDate(Date lastUpdatedDate) {
        this.lastUpdatedDate = lastUpdatedDate;
    }

    public String getLastUpdatedBy() {
        return lastUpdatedBy;
    }

    public void setLastUpdatedBy(String lastUpdatedBy) {
        this.lastUpdatedBy = lastUpdatedBy;
    }
}
