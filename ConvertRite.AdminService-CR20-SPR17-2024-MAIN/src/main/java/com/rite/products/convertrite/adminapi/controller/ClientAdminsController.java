package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.ClientAdminCreationReqPo;
import com.rite.products.convertrite.adminapi.po.ResetPasswordPo;
import com.rite.products.convertrite.adminapi.service.ClientAdminManagementService;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@Tag(name = "08. ClientAdmin", description = "APIs for client admins")
public class ClientAdminsController {

    @Autowired
    ClientAdminManagementService clientAdminManagementService;

    @PostMapping("/api/convertriteadmin/clientadmins")
    @PreAuthorize("hasRole('RITEADMIN') or hasRole('CLIENTADMIN')")
    public ResponseEntity<BasicResPo> createClientAdmin(@RequestBody ClientAdminCreationReqPo clientAdminCreationReqPo) {
        BasicResPo response = clientAdminManagementService.createClientAdmin(clientAdminCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PutMapping("/api/convertriteadmin/clientadmins")
    public ResponseEntity<BasicResPo> updateClientAdminPwd(@RequestBody ResetPasswordPo resetPasswordPo) {
        BasicResPo response = clientAdminManagementService.updateClientAdminPwd(resetPasswordPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clientadmins")
    public ResponseEntity<BasicResPo> getClientAdmins() {
        BasicResPo response = clientAdminManagementService.getClientAdmins();
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clientadmins/{clientAdmin_id}")
    public ResponseEntity<BasicResPo> getClientAdmin(@PathVariable Long clientAdmin_id) {
        BasicResPo response = clientAdminManagementService.getClientAdminById(clientAdmin_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clientadmins/{clientAdmin_id}/licensedpods")
    public ResponseEntity<BasicResPo> getClientAdminLicensedPods(@PathVariable Long clientAdmin_id) {
        BasicResPo response = clientAdminManagementService.getLicensedPodsByClientAdminId(clientAdmin_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PutMapping("/api/convertriteadmin/clientadmins/{clientAdmin_id}")
    @PreAuthorize("hasRole('RITEADMIN') or hasRole('CLIENTADMIN')")
    public ResponseEntity<BasicResPo> putClientAdmin(@PathVariable Long clientAdmin_id, @RequestBody ClientAdminCreationReqPo clientAdminCreationReqPo) {
        BasicResPo response = clientAdminManagementService.putClientAdminById(clientAdmin_id, clientAdminCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @DeleteMapping("/api/convertriteadmin/clientadmins/{clientAdmin_id}")
    @PreAuthorize("hasRole('RITEADMIN') or hasRole('CLIENTADMIN')")
    public ResponseEntity<BasicResPo> deleteClientAdmin(@PathVariable Long clientAdmin_id) {
        BasicResPo response = clientAdminManagementService.deleteClientAdminById(clientAdmin_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clientadmins/{clientAdmin_id}/modules")
    public ResponseEntity<BasicResPo> getClientAdminModules(@PathVariable Long clientAdmin_id) {
        BasicResPo response = clientAdminManagementService.getClientAdminModulesByAdminId(clientAdmin_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clientadmins/{clientAdmin_id}/objects")
    public ResponseEntity<BasicResPo> getCientAdminObjects(@PathVariable Long clientAdmin_id, @RequestParam(name = "module_code", required = false) String moduleCode) {
        BasicResPo response = clientAdminManagementService.getClientAdminObjectsByAdminId(clientAdmin_id, moduleCode);
        return new ResponseEntity<>(response, response.getStatusCode());
    }
}
