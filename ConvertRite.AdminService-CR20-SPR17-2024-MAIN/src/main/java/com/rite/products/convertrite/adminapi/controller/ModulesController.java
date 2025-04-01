package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.ModuleCreationReqPo;
import com.rite.products.convertrite.adminapi.service.ModuleManagementService;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@Tag(name = "02. Modules", description = "APIs for modules")
public class ModulesController {

    @Autowired
    ModuleManagementService moduleManagementService;

    @PostMapping("/api/convertriteadmin/modules")
    public ResponseEntity<BasicResPo> createModule(@RequestBody ModuleCreationReqPo moduleCreationReqPo) {
        BasicResPo response = moduleManagementService.createModule(moduleCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/moduleswithdetails")
    public ResponseEntity<BasicResPo> getModuleTree() {
        BasicResPo response = moduleManagementService.getModuleTree();
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/modules")
    public ResponseEntity<BasicResPo> getModules() {
        BasicResPo response = moduleManagementService.getModules();
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/modules/{module_id}")
    public ResponseEntity<BasicResPo> getModule(@PathVariable Long module_id) {
        BasicResPo response = moduleManagementService.getModuleById(module_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PutMapping("/api/convertriteadmin/modules/{module_id}")
    public ResponseEntity<BasicResPo> putModule(@PathVariable Long module_id, @RequestBody ModuleCreationReqPo moduleCreationReqPo) {
        BasicResPo response = moduleManagementService.putModuleById(module_id, moduleCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @DeleteMapping("/api/convertriteadmin/modules/{module_id}")
    public ResponseEntity<BasicResPo> deleteModule(@PathVariable Long module_id) {
        BasicResPo response = moduleManagementService.deleteModuleById(module_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

}
