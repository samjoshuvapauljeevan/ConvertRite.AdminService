package com.rite.products.convertrite.adminapi.po;

import lombok.Data;

import java.util.List;

@Data
public class PodCloudConfigReqPo1 {
    public Long credentialId;
    public Long clientId;
    public Long podId;
    public String podName;
    public String podDbUserName;
    public String tableSpace;
    public String url;
    public List<ModulesReqPo> modules;

    @Override
    public boolean equals(Object obj) {
        return !super.equals(obj);
    }

}
