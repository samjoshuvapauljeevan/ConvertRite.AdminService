package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.LicenseCreationReqPo;

public interface LicenseManagementService {

    BasicResPo createLicense(LicenseCreationReqPo licenseCreationReqPo);

    BasicResPo getLicenses();

    BasicResPo getLicenseById(Long licenseId);

    BasicResPo putLicenseById(Long licenseId, LicenseCreationReqPo licenseCreationReqPo);

    BasicResPo deleteLicenseById(Long licenseId);
}