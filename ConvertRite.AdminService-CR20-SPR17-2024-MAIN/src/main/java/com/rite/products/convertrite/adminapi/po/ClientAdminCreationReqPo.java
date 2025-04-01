package com.rite.products.convertrite.adminapi.po;

import lombok.Data;

import java.util.List;

@Data
public class ClientAdminCreationReqPo {
    private Long clientAdminId;
    private Long clientId;
    private String clientAdminName;
    private String clientAdminUserName;
    private String clientAdminPassword;
    private List<Long> podIds;
}
