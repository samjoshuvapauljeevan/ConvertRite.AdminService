package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.LicenseCreationReqPo;
import com.rite.products.convertrite.adminapi.service.LicenseManagementService;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@Tag(name = "04. License", description = "APIs for license")
public class LicensesController {

    @Autowired
    LicenseManagementService licenseManagementService;

    @PostMapping("/api/convertriteadmin/licenses")
    @PreAuthorize("hasRole('RITEADMIN')")
    public ResponseEntity<BasicResPo> createLicense(@RequestBody LicenseCreationReqPo licenseCreationReqPo) {
        BasicResPo response = licenseManagementService.createLicense(licenseCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/licenses")
    public ResponseEntity<BasicResPo> getLicenses() {
        BasicResPo response = licenseManagementService.getLicenses();
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/licenses/{license_id}")
    public ResponseEntity<BasicResPo> getLicense(@PathVariable Long license_id) {
        BasicResPo response = licenseManagementService.getLicenseById(license_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PutMapping("/api/convertriteadmin/licenses/{license_id}")
    @PreAuthorize("hasRole('RITEADMIN')")
    public ResponseEntity<BasicResPo> putLicense(@PathVariable Long license_id, @RequestBody LicenseCreationReqPo licenseCreationReqPo) {
        BasicResPo response = licenseManagementService.putLicenseById(license_id, licenseCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @DeleteMapping("/api/convertriteadmin/licenses/{license_id}")
    @PreAuthorize("hasRole('RITEADMIN')")
    public ResponseEntity<BasicResPo> deleteLicense(@PathVariable Long license_id) {
        BasicResPo response = licenseManagementService.deleteLicenseById(license_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }
}
