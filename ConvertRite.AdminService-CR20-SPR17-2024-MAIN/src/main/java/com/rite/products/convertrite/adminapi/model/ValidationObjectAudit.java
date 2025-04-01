package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;

import java.util.Date;

@Entity
@Table(name = "CR_VAL_PKG_EXEC_AUDIT")
public class ValidationObjectAudit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "AUDIT_ID")
    private Long auditId;

    @Column(name = "OBJECT_ID")
    private Long objectId;

    @ManyToOne
    @JoinColumn(name = "VAL_OBJECT_ID")
    private ValidationObject validationObject;

    @Column(name = "POD_ID")
    private Long podId;

    @Column(name = "IS_SUCCESS")
    private Boolean isSuccess;

    @Column(name = "ERROR_MESSAGE")
    private String errorMessage;

    @Column(name = "CREATION_DATE")
    private Date creationDate;

    @Column(name = "CREATED_BY")
    private String createdBy;

    // Getters and Setters
    public Long getAuditId() {
        return auditId;
    }

    public void setAuditId(Long auditId) {
        this.auditId = auditId;
    }

    public Long getObjectId() {
        return objectId;
    }

    public void setObjectId(Long objectId) {
        this.objectId = objectId;
    }




    public Long getPodId() {
        return podId;
    }

    public void setPodId(Long podId) {
        this.podId = podId;
    }

    public Boolean getSuccess() {
        return isSuccess;
    }

    public void setSuccess(Boolean success) {
        this.isSuccess = success;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
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

    public ValidationObject getValidationObject() {
        return validationObject;
    }

    public void setValidationObject(ValidationObject validationObject) {
        this.validationObject = validationObject;
    }

}
