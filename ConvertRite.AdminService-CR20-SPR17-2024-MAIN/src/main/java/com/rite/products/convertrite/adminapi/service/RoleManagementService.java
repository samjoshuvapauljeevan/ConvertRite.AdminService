package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.RoleCreationReqPo;

public interface RoleManagementService {

    BasicResPo createRole(RoleCreationReqPo roleCreationReqPo);

    BasicResPo getRoles(Long clientId, Long podId);

    BasicResPo getRoleById(Long roleId);

    BasicResPo putRoleById(Long roleId, RoleCreationReqPo roleCreationReqPo);

    BasicResPo deleteRoleById(Long roleId);
}