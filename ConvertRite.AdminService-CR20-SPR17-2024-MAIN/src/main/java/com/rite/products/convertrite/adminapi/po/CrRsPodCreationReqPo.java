package com.rite.products.convertrite.adminapi.po;

import lombok.Data;

@Data
public class CrRsPodCreationReqPo {
    private Long podId;
    private String podName;
    private String url;
    private String databaseUserName;
    private String databasePassword;
    private String tablespaceSize;
//    private Long licenseId;
    private Long clientId;
}
