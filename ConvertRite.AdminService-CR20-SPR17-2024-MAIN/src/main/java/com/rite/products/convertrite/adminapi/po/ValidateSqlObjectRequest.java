package com.rite.products.convertrite.adminapi.po;

import org.springframework.web.multipart.MultipartFile;

public class ValidateSqlObjectRequest {


    private Long objectId;
    private String objectType;

    private String dependantTables;
    private String filename;
    private MultipartFile file;
    private Long podId; // Optional

    // Getters and Setters





    public String getDependantTables() {
        return dependantTables;
    }

    public void setDependantTables(String dependantTables) {
        this.dependantTables = dependantTables;
    }

    public Long getObjectId() {
        return objectId;
    }

    public void setObjectId(Long objectId) {
        this.objectId = objectId;
    }

    public String getObjectType() {
        return objectType;
    }

    public void setObjectType(String objectType) {
        this.objectType = objectType;
    }

    public String getFilename() {
        return filename;
    }

    public void setFilename(String filename) {
        this.filename = filename;
    }

    public MultipartFile getFile() {
        return file;
    }

    public void setFile(MultipartFile file) {
        this.file = file;
    }

    public Long getPodId() {
        return podId;
    }

    public void setPodId(Long podId) {
        this.podId = podId;
    }
}