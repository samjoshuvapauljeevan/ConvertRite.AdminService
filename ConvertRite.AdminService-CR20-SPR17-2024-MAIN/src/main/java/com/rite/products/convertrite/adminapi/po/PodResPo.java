package com.rite.products.convertrite.adminapi.po;

public class PodResPo {
    private Long podId;
    private String podName;
    private String databaseUserName;
    private String databasePassword;
    private String tablespaceSize;
    private String scheduledJobFlag;
    private LicenseResPo license;
    private ClientResPo client;

    public String getScheduledJobFlag() {
        return scheduledJobFlag;
    }

    public void setScheduledJobFlag(String scheduledJobFlag) {
        this.scheduledJobFlag = scheduledJobFlag;
    }

    public Long getPodId() {
        return podId;
    }

    public void setPodId(Long podId) {
        this.podId = podId;
    }

    public String getPodName() {
        return podName;
    }

    public void setPodName(String podName) {
        this.podName = podName;
    }

    public String getDatabaseUserName() {
        return databaseUserName;
    }

    public void setDatabaseUserName(String databaseUserName) {
        this.databaseUserName = databaseUserName;
    }

    public String getDatabasePassword() {
        return databasePassword;
    }

    public void setDatabasePassword(String databasePassword) {
        this.databasePassword = databasePassword;
    }

    public String getTablespaceSize() {
        return tablespaceSize;
    }

    public void setTablespaceSize(String tablespaceSize) {
        this.tablespaceSize = tablespaceSize;
    }

    public LicenseResPo getLicense() {
        return license;
    }

    public void setLicense(LicenseResPo license) {
        this.license = license;
    }

    public ClientResPo getClient() {
        return client;
    }

    public void setClient(ClientResPo client) {
        this.client = client;
    }
}
