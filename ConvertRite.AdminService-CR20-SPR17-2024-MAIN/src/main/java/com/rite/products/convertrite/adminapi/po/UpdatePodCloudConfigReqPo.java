package com.rite.products.convertrite.adminapi.po;

import lombok.Data;

import java.util.List;

@Data
public class UpdatePodCloudConfigReqPo {
    public Long credentialId;
    public Long clientId;
    public Long podId;
    public String url;
    public String moduleCode;
    public String userName;
    public String password;
    public List<Long> objectIds;
}
