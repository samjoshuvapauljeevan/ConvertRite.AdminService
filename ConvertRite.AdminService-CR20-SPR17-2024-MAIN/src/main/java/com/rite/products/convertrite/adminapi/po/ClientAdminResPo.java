package com.rite.products.convertrite.adminapi.po;

import java.util.List;

public class ClientAdminResPo {
    private Long clientAdminId;
    private ClientResPo client;
    private String clientAdminName;
    private String clientAdminUserName;
    private String clientAdminPassword;

    private List<PodBasicResPo> pods;

    public Long getClientAdminId() {
        return clientAdminId;
    }

    public void setClientAdminId(Long clientAdminId) {
        this.clientAdminId = clientAdminId;
    }

    public ClientResPo getClient() {
        return client;
    }

    public void setClient(ClientResPo client) {
        this.client = client;
    }

    public String getClientAdminName() {
        return clientAdminName;
    }

    public void setClientAdminName(String clientAdminName) {
        this.clientAdminName = clientAdminName;
    }

    public String getClientAdminUserName() {
        return clientAdminUserName;
    }

    public void setClientAdminUserName(String clientAdminUserName) {
        this.clientAdminUserName = clientAdminUserName;
    }

    public String getClientAdminPassword() {
        return clientAdminPassword;
    }

    public void setClientAdminPassword(String clientAdminPassword) {
        this.clientAdminPassword = clientAdminPassword;
    }

    public List<PodBasicResPo> getPods() {
        return pods;
    }

    public void setPods(List<PodBasicResPo> pods) {
        this.pods = pods;
    }
}
