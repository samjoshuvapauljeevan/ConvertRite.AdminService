package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.po.UpdatePodCloudConfigReqPo;
import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.PodCloudConfigReqPo;
import com.rite.products.convertrite.adminapi.service.PodCloudConfigService;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@Tag(name = "07. PodCloudConfig", description = "APIs for pod cloud configs")
public class PodCloudConfigController {
    @Autowired
    PodCloudConfigService podCloudConfigService;

    @PostMapping("/api/convertriteadmin/podcloudconfigs")
    public ResponseEntity<BasicResPo> createPodCloudConfig(@RequestBody PodCloudConfigReqPo req) {
        BasicResPo response = podCloudConfigService.createPodCloudConfig(req);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/podcloudconfigs")
    public ResponseEntity<BasicResPo> getAllPodCloudConfigs() {
        BasicResPo response = podCloudConfigService.getAllPodCloudConfigs();
        return new ResponseEntity<>(response, response.getStatusCode());
    }
    @GetMapping("/api/convertriteadmin/getAllPodCloudConfigsByClientId/{clientId}")
    public ResponseEntity<BasicResPo> getAllPodCloudConfigsByClientId(@PathVariable Long clientId) {
        BasicResPo response = podCloudConfigService.getAllPodCloudConfigs(clientId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }
    @GetMapping("/api/convertriteadmin/podcloudconfigs/{podId}")
    public ResponseEntity<BasicResPo> getPodCloudConfigs(@PathVariable Long podId) {
        BasicResPo response = podCloudConfigService.getPodCloudConfigs(podId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @DeleteMapping("/api/convertriteadmin/deletePodCloudConfig")
    public ResponseEntity<BasicResPo> deletePodCloudConfig(@RequestParam Long clientId,@RequestParam Long podId) {
        BasicResPo response = podCloudConfigService.deletePodCloudConfig(clientId,podId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PutMapping("/api/convertriteadmin/podcloudconfigs/{credentialId}")
    public ResponseEntity<BasicResPo> updatePodCloudConfig(@PathVariable Long credentialId, @RequestBody UpdatePodCloudConfigReqPo req) {
        req.setCredentialId(credentialId);
        BasicResPo response = podCloudConfigService.updatePodCloudConfig(req);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/getPodInfo")
    public ResponseEntity<BasicResPo> getConfigsByClientIdAndPodI(@RequestParam Long clientId, @RequestParam Long podId) {
        BasicResPo response = podCloudConfigService.getConfigsByClientIdAndPodId(clientId, podId);
        return new ResponseEntity<>(response, response.getStatusCode());

    }
}
