package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.CrRsPodCreationReqPo;
import com.rite.products.convertrite.adminapi.po.PodCreationReqPo;
import com.rite.products.convertrite.adminapi.service.CrRsPodManagementService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@Tag(name = "06. Pods", description = "APIs for pods")
@Slf4j
@RequestMapping("/api/convertriteadmin/rspods")
public class CrRsPodController {
    @Autowired
    CrRsPodManagementService crRsPodManagementService;
    @PostMapping("/createPod")
    @PreAuthorize("hasRole('RITEADMIN') or hasRole('CLIENTADMIN')")
    public ResponseEntity<BasicResPo> createPod(@RequestBody CrRsPodCreationReqPo req) {
        BasicResPo response = crRsPodManagementService.createPod(req);
        return new ResponseEntity<>(response, response.getStatusCode());
    }
    @GetMapping("/getPodsInformation")
    @PreAuthorize("hasRole('RITEADMIN') or hasRole('CLIENTADMIN')")
    public ResponseEntity<BasicResPo> getPodsInformation(@RequestParam Long clientId) {
        BasicResPo response = crRsPodManagementService.getPodsInformation(clientId);
        log.info("Returning response: {}", response);
        return ResponseEntity.status(response.getStatusCode()).body(response);
    }

}
