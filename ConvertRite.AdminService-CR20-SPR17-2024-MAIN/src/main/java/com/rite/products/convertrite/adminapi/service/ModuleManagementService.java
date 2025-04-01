package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.ModuleCreationReqPo;

public interface ModuleManagementService {

    BasicResPo createModule(ModuleCreationReqPo moduleCreationReqPo);

    BasicResPo getModules();

    BasicResPo getModuleTree();

    BasicResPo getModuleById(Long moduleId);

    BasicResPo putModuleById(Long moduleId, ModuleCreationReqPo moduleCreationReqPo);

    BasicResPo deleteModuleById(Long moduleId);
}