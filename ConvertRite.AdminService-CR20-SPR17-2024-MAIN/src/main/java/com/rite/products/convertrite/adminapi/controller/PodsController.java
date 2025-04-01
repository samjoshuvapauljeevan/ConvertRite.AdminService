package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.PodCreationReqPo;
import com.rite.products.convertrite.adminapi.po.SqlExecutionReqPo;
import com.rite.products.convertrite.adminapi.service.DataSyncService;
import com.rite.products.convertrite.adminapi.service.PodManagementService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.sql.SQLException;

@RestController
@Tag(name = "06. Pods", description = "APIs for pods")
@Slf4j
public class PodsController {

    @Autowired
    PodManagementService podManagementService;

    @Autowired
    DataSyncService dataSyncService;

    @PostMapping("/api/convertriteadmin/pods")
    @PreAuthorize("hasRole('RITEADMIN') or hasRole('CLIENTADMIN')")
    public ResponseEntity<BasicResPo> createPod(@RequestBody PodCreationReqPo podCreationReqPo) {
        BasicResPo response = podManagementService.createPod(podCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/pods")
    public ResponseEntity<BasicResPo> getPods() {
        BasicResPo response = podManagementService.getPods();
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clients/{client_id}/pods")
    public ResponseEntity<BasicResPo> getClientPods(@PathVariable(name = "client_id") Long clientId) {
        BasicResPo response = podManagementService.getClientPods(clientId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clientadmins/{clientadmin_id}/pods")
    public ResponseEntity<BasicResPo> getClientAdminPods(@PathVariable(name = "clientadmin_id") Long clientAdminId) {
        BasicResPo response = podManagementService.getClientAdminPods(clientAdminId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clientadmins/{clientadmin_id}/licensedpods")
    public ResponseEntity<BasicResPo> getClientAdminLicensedPods(@PathVariable(name = "clientadmin_id") Long clientAdminId) {
        BasicResPo response = podManagementService.getClientAdminLicensedPods(clientAdminId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/podswithdetails")
    @PreAuthorize("hasRole('RITEADMIN') or hasRole('CLIENTADMIN')")
    public ResponseEntity<BasicResPo> getPodsWithDetails() {
        BasicResPo response = podManagementService.getPodsWithDetails();
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clients/{client_id}/podswithdetails")
    @PreAuthorize("hasRole('RITEADMIN') or hasRole('CLIENTADMIN')")
    public ResponseEntity<BasicResPo> getClientPodsWithDetails(@PathVariable(name = "client_id") Long clientId) {
        BasicResPo response = podManagementService.getClientPodsWithDetails(clientId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clientadmins/{clientadmin_id}/podswithdetails")
    @PreAuthorize("hasRole('RITEADMIN') or hasRole('CLIENTADMIN')")
    public ResponseEntity<BasicResPo> getClientAdminPodsWithDetails(@PathVariable(name = "clientadmin_id") Long clientAdminId) {
        BasicResPo response = podManagementService.getClientAdminPodsWithDetails(clientAdminId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/pods/{pod_id}")
    public ResponseEntity<BasicResPo> getPod(@PathVariable Long pod_id) {
        BasicResPo response = podManagementService.getPodById(pod_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PutMapping("/api/convertriteadmin/pods/{pod_id}")
    @PreAuthorize("hasRole('RITEADMIN') or hasRole('CLIENTADMIN')")
    public ResponseEntity<BasicResPo> updatePod(@PathVariable Long pod_id, @RequestBody PodCreationReqPo podCreationReqPo) {
        BasicResPo response = podManagementService.updatePodById(pod_id, podCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @DeleteMapping("/api/convertriteadmin/pods/{pod_id}")
    @PreAuthorize("hasRole('RITEADMIN') or hasRole('CLIENTADMIN')")
    public ResponseEntity<BasicResPo> deletePod(@PathVariable Long pod_id) {
        BasicResPo response = podManagementService.deletePodById(pod_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/pods/{pod_id}/modules")
    public ResponseEntity<BasicResPo> getPodModules(@PathVariable Long pod_id) {
        BasicResPo response = podManagementService.getPodModulesByPodId(pod_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/pods/{pod_id}/objects")
    public ResponseEntity<BasicResPo> getPodObjects(@PathVariable Long pod_id, @RequestParam(name = "module_code", required = false) String moduleCode) {
        BasicResPo response = podManagementService.getPodObjectsByPodId(pod_id, moduleCode);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PostMapping("/api/convertriteadmin/executeSql")
    public ResponseEntity<BasicResPo> executeSqlOnPods(@RequestBody SqlExecutionReqPo request) {
        BasicResPo response = null;

        // do null check of client ID
        if(request.getClientId() != null) {
            response = podManagementService.executeSqlOnPods(request.getClientId(), request.getSqlFilePath());
        }
        else {
           response =  podManagementService.executeSqlOnPods(request.getSqlFilePath());
        }
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PostMapping("/api/convertriteadmin/executeMasterScripts")
    public ResponseEntity<BasicResPo> executeMasterScripts(@RequestBody SqlExecutionReqPo request) {
        BasicResPo response = null;
        try {
            response = podManagementService.executeScriptOnMasterDb(request.getSqlFilePath());
        } catch (IOException | SQLException e ) {
            log.error("Error while executing master scripts", e);
            throw new RuntimeException(e);
        }
        return new ResponseEntity<>(response, response.getStatusCode());

    }

    @GetMapping("/api/convertriteadmin/pods/datasync")
    public ResponseEntity<BasicResPo> performDataSyncToAllPods() {
        dataSyncService.performFullDataSyncToAllPods();
        BasicResPo response = new BasicResPo();
        response.setStatusCode(HttpStatus.OK);
        response.setMessage("Data sync triggered succesfully . Please check logs for the progress");
        return new ResponseEntity<>(response, response.getStatusCode());
    }
}
