package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.po.UpdatePodCloudConfigReqPo;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.PodCloudConfigReqPo;

public interface PodCloudConfigService {

    BasicResPo createPodCloudConfig(PodCloudConfigReqPo podCloudConfigReqPo);

    BasicResPo getAllPodCloudConfigs();
    BasicResPo getAllPodCloudConfigs(Long clientId);
    BasicResPo getPodCloudConfigsByClientId(Long clientId);

    BasicResPo updatePodCloudConfig(UpdatePodCloudConfigReqPo req);

    BasicResPo deletePodCloudConfig(Long credentialId, Long podId);

    BasicResPo getConfigsByClientIdAndPodId(Long clientId, Long podId);

    BasicResPo getPodCloudConfigs(Long podId);
}