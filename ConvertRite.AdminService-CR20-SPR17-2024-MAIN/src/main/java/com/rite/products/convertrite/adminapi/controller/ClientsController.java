package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.model.Client;
import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.ClientCreationReqPo;
import com.rite.products.convertrite.adminapi.service.ClientManagementService;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@Tag(name = "05. Client", description = "APIs for clients")
public class ClientsController {

    @Autowired
    ClientManagementService clientManagementService;

    @PostMapping("/api/convertriteadmin/clients")
    @PreAuthorize("hasRole('RITEADMIN')")
    public ResponseEntity<BasicResPo> createClient(@ModelAttribute ClientCreationReqPo clientReqPo) {
        BasicResPo response = clientManagementService.createClient(clientReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clients")
    public ResponseEntity<BasicResPo> getClients() {
        BasicResPo response = clientManagementService.getClients();
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clients/{client_id}")
    public ResponseEntity<BasicResPo> getClient(@PathVariable Long client_id) {
        BasicResPo response = clientManagementService.getClientById(client_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clients/{client_id}/logo")
    public ResponseEntity<Object> getClientLogo(@PathVariable Long client_id) {
        BasicResPo response = clientManagementService.getClientDetailsByClientId(client_id);

        if (response.getStatus() == "success" && ((Client) (response.getPayload())).getClientLogo() == null) {
            return new ResponseEntity<>(new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Client logo not available for client with id " + client_id);
            }}, HttpStatus.NOT_FOUND);
        } else if (response.getStatus() == "error") {
            return new ResponseEntity<>(response, response.getStatusCode());
        }

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + ((Client) (response.getPayload())).getClientLogoFileName() + "\"")
                .contentType(MediaType.valueOf(((Client) (response.getPayload())).getClientLogoFileType()))
                .body(((Client) (response.getPayload())).getClientLogo());
    }

    @PutMapping("/api/convertriteadmin/clients/{client_id}")
    @PreAuthorize("hasRole('RITEADMIN')")
    public ResponseEntity<BasicResPo> putClient(@PathVariable Long client_id, @ModelAttribute ClientCreationReqPo clientCreationReqPo) {
        BasicResPo response = clientManagementService.putClientById(client_id, clientCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @DeleteMapping("/api/convertriteadmin/clients/{client_id}")
    @PreAuthorize("hasRole('RITEADMIN')")
    public ResponseEntity<BasicResPo> deleteClient(@PathVariable Long client_id) {
        BasicResPo response = clientManagementService.deleteClientById(client_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }
}
