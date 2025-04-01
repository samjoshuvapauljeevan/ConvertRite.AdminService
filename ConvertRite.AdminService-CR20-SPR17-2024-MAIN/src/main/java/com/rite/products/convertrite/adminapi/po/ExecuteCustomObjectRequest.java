package com.rite.products.convertrite.adminapi.po;

import java.util.List;

public class ExecuteCustomObjectRequest {
    private List<Long> objectIds;

    private Long projectId;
    private Long podId;

    // Getters and setters

    public Long getProjectId() {
        return projectId;
    }

    public void setProjectId(Long projectId) {
        this.projectId = projectId;
    }
    public List<Long> getObjectIds() {
        return objectIds;
    }

    public void setObjectIds(List<Long> objectIds) {
        this.objectIds = objectIds;
    }



    public Long getPodId() {
        return podId;
    }

    public void setPodId(Long podId) {
        this.podId = podId;
    }
}
