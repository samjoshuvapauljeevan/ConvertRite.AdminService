package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.Column;
import lombok.Data;
import jakarta.persistence.*;

import java.util.Date;


@Entity
@Table(name = "CR_VALIDATION_OBJECTS")
@Data
public class ValidationObject {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "VAL_OBJECT_ID")
    private Long validationObjectId;


    @Enumerated(EnumType.STRING)
    @Column(name = "VAL_OBJECT_SOURCE")
    private ObjectSource objectSource;
    @Enumerated(EnumType.STRING)
    @Column(name = "VAL_OBJECT_TYPE")
    private ObjectType objectType;


    @Column(name = "OBJECT_ID")
    private Long objectId;

    @Column(name = "VAL_SYNC_TABLES")
    private String syncDependentTables;
    @Column(name = "VAL_OBJECT_NAME")
    private String filename;


    @Column(name = "CREATED_BY")
    private String createdBy;

    @Column(name = "CREATED_AT")
    private Date createdAt ;

    @Column(name = "UPDATED_BY")
    private String updatedBy;

    @Column(name = "UPDATED_AT")
    private Date updatedAt;

    //getters and setters

    public ObjectSource getObjectSource() {
        return objectSource;
    }

    public void setObjectSource(ObjectSource objectSource) {
        this.objectSource = objectSource;
    }

    public String getSyncDependentTables() {
        return syncDependentTables;
    }

    public void setSyncDependentTables(String syncDependentTables) {
        this.syncDependentTables = syncDependentTables;
    }


    public Long getValidationObjectId() {
        return validationObjectId;
    }

    public void setValidationObjectId(Long validationObjectId) {
        this.validationObjectId = validationObjectId;
    }

    public String getObjectType() {
        return objectType.name();
    }

    public void setObjectType(String objectType) {
        // convert string to enum
        if (objectType != null) {
            this.objectType = ObjectType.valueOf(objectType.toUpperCase());
        }
    }



    public Long getObjectId() {
        return objectId;
    }

    public void setObjectId(Long objectId) {
        this.objectId = objectId;
    }

    public String getFilename() {
        return filename;
    }

    public void setFilename(String filename) {
        this.filename = filename;
    }



    public String getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(String createdBy) {
        this.createdBy = createdBy;
    }

    public Date getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Date createdAt) {
        this.createdAt = createdAt;
    }

    public String getUpdatedBy() {
        return updatedBy;
    }

    public void setUpdatedBy(String updatedBy) {
        this.updatedBy = updatedBy;
    }

    public Date getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Date updatedAt) {
        this.updatedAt = updatedAt;
    }

}