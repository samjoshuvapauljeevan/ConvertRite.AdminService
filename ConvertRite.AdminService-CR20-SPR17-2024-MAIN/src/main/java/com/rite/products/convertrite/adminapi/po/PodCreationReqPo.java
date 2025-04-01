package com.rite.products.convertrite.adminapi.po;

import lombok.Data;

@Data
public class PodCreationReqPo {
    private Long podId;
    private String podName;
    private String databaseUserName;
    private String databasePassword;
    private String tablespaceSize;
    private Long licenseId;
    private Long clientId;
    private String scheduledJobFlag;

}
