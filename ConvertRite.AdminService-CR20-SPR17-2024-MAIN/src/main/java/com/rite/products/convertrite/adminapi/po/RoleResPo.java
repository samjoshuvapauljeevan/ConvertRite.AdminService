package com.rite.products.convertrite.adminapi.po;

import java.util.List;

public class RoleResPo {
    private Long roleId;
    private String roleName;
    private String description;
    private ClientResPo client;
    private PodBasicResPo pod;
    private List<Long> objectIds;

    public Long getRoleId() {
        return roleId;
    }

    public void setRoleId(Long roleId) {
        this.roleId = roleId;
    }

    public String getRoleName() {
        return roleName;
    }

    public void setRoleName(String roleName) {
        this.roleName = roleName;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
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
