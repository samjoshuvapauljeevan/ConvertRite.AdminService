package com.rite.products.convertrite.adminapi.po;

import java.util.List;

public class ProjectResPo {
    private Long projectId;
    private String projectName;
    private String projectCode;
    private ClientResPo client;
    private PodBasicResPo pod;
    private List<Long> objectIds;

    public Long getProjectId() {
        return projectId;
    }

    public void setProjectId(Long projectId) {
        this.projectId = projectId;
    }

    public String getProjectName() {
        return projectName;
    }

    public void setProjectName(String projectName) {
        this.projectName = projectName;
    }

    public String getProjectCode() {
        return projectCode;
    }

    public void setProjectCode(String projectCode) {
        this.projectCode = projectCode;
    }

    public ClientResPo getClient() {
        return client;
    }

    public void setClient(ClientResPo client) {
        this.client = client;
    }

    public PodBasicResPo getPod() {
        return pod;
    }

    public void setPod(PodBasicResPo pod) {
        this.pod = pod;
    }

    public List<Long> getObjectIds() {
        return objectIds;
    }

    public void setObjectIds(List<Long> objectIds) {
        this.objectIds = objectIds;
    }
}
