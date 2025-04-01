package com.rite.products.convertrite.adminapi.po;

import java.util.List;

import lombok.Data;

@Data
public class PodCloudConfigReqPo {
    public Long credentialId;
    public Long clientId;
    public Long podId;
    public String podName;
    public String podDbUserName;
    public String tableSpace;
    public String url;
    public List<ModulesReqPo> modules;
    public Boolean isUpdate =false;
}
