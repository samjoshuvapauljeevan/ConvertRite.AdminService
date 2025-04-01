package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.UserCreationReqPo;

public interface UserManagementService {

    BasicResPo createUser(UserCreationReqPo userCreationReqPo);

    BasicResPo getUsers(Long clientId);

    BasicResPo getUserById(Long userId);

    BasicResPo getUserWithLicensedPodsByUserId(Long userId);

    BasicResPo getUserWithLicensedPodsByUserEmail(String userEmail);

    BasicResPo getLicensedPodsByUserId(Long userId);

    BasicResPo putUserById(Long clientAdminId, UserCreationReqPo userCreationReqPo);

    BasicResPo deleteUserById(Long userId);

    BasicResPo getUserAuthType(String userName);

    BasicResPo updatePassword(String userId, String password);

    BasicResPo forgotPassword(String email);
}