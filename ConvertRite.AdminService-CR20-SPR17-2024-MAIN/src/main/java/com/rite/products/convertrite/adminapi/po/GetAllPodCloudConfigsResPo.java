package com.rite.products.convertrite.adminapi.po;

import java.util.List;

import lombok.Data;

@Data
public class GetAllPodCloudConfigsResPo {

    public Long credentialId;
    public Long clientId;
    public Long podId;
    public String podName;
    public String podDbUserName;
    public String tableSpace;
    public String url;
    public String username;
    public String password;
    public String moduleCode;
    public List<Long> objectIds;
}
