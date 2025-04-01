package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.RoleCreationReqPo;
import com.rite.products.convertrite.adminapi.service.RoleManagementService;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@Tag(name = "09. Roles", description = "APIs for roles")
public class RolesController {

    @Autowired
    RoleManagementService roleManagementService;

    @PostMapping("/api/convertriteadmin/clients/{client_id}/roles")
    public ResponseEntity<BasicResPo> createRole(@PathVariable(name = "client_id") Long clientId, @RequestBody RoleCreationReqPo roleCreationReqPo) {
        roleCreationReqPo.setClientId(clientId);
        BasicResPo response = roleManagementService.createRole(roleCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clients/{client_id}/roles")
    public ResponseEntity<BasicResPo> getRoles(@PathVariable(name = "client_id") Long clientId, @RequestParam(name = "pod_id", required = false) Long podId) {
        BasicResPo response = roleManagementService.getRoles(clientId, podId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clients/{client_id}/roles/{role_id}")
    public ResponseEntity<BasicResPo> getRole(@PathVariable(name = "client_id") Long clientId, @PathVariable Long role_id) {
        BasicResPo response = roleManagementService.getRoleById(role_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PutMapping("/api/convertriteadmin/clients/{client_id}/roles/{role_id}")
    public ResponseEntity<BasicResPo> putRole(@PathVariable Long role_id, @RequestBody RoleCreationReqPo roleCreationReqPo) {
        BasicResPo response = roleManagementService.putRoleById(role_id, roleCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @DeleteMapping("/api/convertriteadmin/clients/{client_id}/roles/{role_id}")
    public ResponseEntity<BasicResPo> deleteRole(@PathVariable Long role_id) {
        BasicResPo response = roleManagementService.deleteRoleById(role_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }
}
