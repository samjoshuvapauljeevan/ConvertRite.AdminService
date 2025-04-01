package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;

import java.util.Date;

@Entity
@Table(name = "cr_data_sync_execution_log")
public class DataSyncExecutionLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long syncId;

    @Column(name = "client_id")
    private Long clientId;

    @Column(name = "pod_id")
    private Long podId;

    @Column(name = "table_name")
    private String tableName;

    @Column(name = "creation_date")
    private Date creationDate;

    @Column(name = "success")
    private Boolean success;

    @Column(name = "error_msg")
    private String errorMsg;

    // getters and setters

    public Long getSyncId() {
        return syncId;
    }

    public void setSyncId(Long syncId) {
        this.syncId = syncId;
    }

    public Long getClientId() {
        return clientId;
    }

    public void setClientId(Long clientId) {
        this.clientId = clientId;
    }

    public Long getPodId() {
        return podId;
    }

    public void setPodId(Long podId) {
        this.podId = podId;
    }

    public String getTableName() {
        return tableName;
    }

    public void setTableName(String tableName) {
        this.tableName = tableName;
    }

    public Date getCreationDate() {
        return creationDate;
    }

    public void setCreationDate(Date creationDate) {
        this.creationDate = creationDate;
    }

    public Boolean getSuccess() {
        return success;
    }

    public void setSuccess(Boolean success) {
        this.success = success;
    }

    public String getErrorMsg() {
        return errorMsg;
    }

    public void setErrorMsg(String errorMsg) {
        this.errorMsg = errorMsg;
    }


}
