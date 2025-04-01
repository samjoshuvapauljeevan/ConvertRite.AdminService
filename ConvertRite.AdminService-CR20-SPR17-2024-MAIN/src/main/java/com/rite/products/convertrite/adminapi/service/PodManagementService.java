package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.PodCreationReqPo;

import java.io.IOException;
import java.sql.SQLException;

public interface PodManagementService {

    BasicResPo createPod(PodCreationReqPo podCreationReqPo);

    BasicResPo getPods();

    BasicResPo getClientPods(Long clientId);

    BasicResPo getClientAdminPods(Long clientAdminId);

    BasicResPo getClientAdminLicensedPods(Long clientAdminId);

    BasicResPo getPodsWithDetails();

    BasicResPo getClientPodsWithDetails(Long clientId);

    BasicResPo getClientAdminPodsWithDetails(Long clientAdminId);

    BasicResPo getPodById(Long podId);

    BasicResPo updatePodById(Long podId, PodCreationReqPo podCreationReqPo);

    BasicResPo deletePodById(Long podId);

    BasicResPo getPodModulesByPodId(Long podId);

    BasicResPo getPodObjectsByPodId(Long podId, String moduleCode);

    BasicResPo executeSqlOnPods(Long clientId, String sqlFilePath);

    BasicResPo executeSqlOnPods( String sqlFilePath);

    BasicResPo executeScriptOnMasterDb(String scriptPath) throws IOException, SQLException;
}