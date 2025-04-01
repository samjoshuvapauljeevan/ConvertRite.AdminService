package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.ClientAdminCreationReqPo;
import com.rite.products.convertrite.adminapi.po.ResetPasswordPo;

public interface ClientAdminManagementService {

    BasicResPo createClientAdmin(ClientAdminCreationReqPo clientAdminCreationReqPo);

    BasicResPo getClientAdmins();

    BasicResPo getClientAdminById(Long clientAdminId);

    BasicResPo getLicensedPodsByClientAdminId(Long clientAdminId);

    BasicResPo putClientAdminById(Long clientAdminId, ClientAdminCreationReqPo clientAdminCreationReqPo);

    BasicResPo deleteClientAdminById(Long clientAdminId);

    BasicResPo getClientAdminModulesByAdminId(Long clientAdminId);

    BasicResPo getClientAdminObjectsByAdminId(Long clientAdminId, String moduleCode);

    BasicResPo updateClientAdminPwd(ResetPasswordPo resetPasswordPo);
}