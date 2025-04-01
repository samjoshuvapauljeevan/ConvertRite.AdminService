package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.UserCreationReqPo;
import com.rite.products.convertrite.adminapi.service.UserManagementService;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@Tag(name = "10. Users", description = "APIs for users")
public class UsersController {

    @Autowired
    UserManagementService userManagementService;

    @PostMapping("/api/convertriteadmin/clients/{client_id}/users")
    public ResponseEntity<BasicResPo> createUser(@PathVariable(name = "client_id") Long clientId, @RequestBody UserCreationReqPo userCreationReqPo) {
        userCreationReqPo.setClientId(clientId);
        BasicResPo response = userManagementService.createUser(userCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clients/{client_id}/users")
    public ResponseEntity<BasicResPo> getUsers(@PathVariable(name = "client_id") Long clientId) {
        BasicResPo response = userManagementService.getUsers(clientId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clients/{client_id}/users/{user_id}")
    public ResponseEntity<BasicResPo> getUser(@PathVariable(name = "client_id") Long clientId, @PathVariable Long user_id) {
        BasicResPo response = userManagementService.getUserById(user_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clients/{client_id}/users/{user_id}/withlicensedpods")
    public ResponseEntity<BasicResPo> getClientUserLicensedPods(@PathVariable(name = "client_id") Long clientId, @PathVariable Long user_id) {
        BasicResPo response = userManagementService.getUserWithLicensedPodsByUserId(user_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/users/{user_id}/withlicensedpods")
    public ResponseEntity<BasicResPo> getUserLicensedPods(@PathVariable Long user_id) {
        BasicResPo response = userManagementService.getUserWithLicensedPodsByUserId(user_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clients/{client_id}/userswithemail/{user_email}/withlicensedpods")
    public ResponseEntity<BasicResPo> getCientUserLicensedPodsByName(@PathVariable(name = "client_id") Long clientId, @PathVariable String user_email) {
        BasicResPo response = userManagementService.getUserWithLicensedPodsByUserEmail(user_email);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/userswithemail/{user_email}/withlicensedpods")
    public ResponseEntity<BasicResPo> getUserLicensedPodsByName(@PathVariable String user_email) {
        BasicResPo response = userManagementService.getUserWithLicensedPodsByUserEmail(user_email);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PutMapping("/api/convertriteadmin/clients/{client_id}/users/{user_id}")
    public ResponseEntity<BasicResPo> putUser(@PathVariable(name = "client_id") Long clientId, @PathVariable Long user_id, @RequestBody UserCreationReqPo userCreationReqPo) {
        BasicResPo response = userManagementService.putUserById(user_id, userCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }
    @PutMapping("/api/convertriteadmin/users/updatePassword")
    public ResponseEntity<BasicResPo> updatePassword(@RequestParam String email,@RequestParam String password) {
        BasicResPo response = userManagementService.updatePassword(email,password);
        return new ResponseEntity<>(response, response.getStatusCode());
    }
    @PostMapping("/api/convertriteadmin/users/forgotPassword")
    public ResponseEntity<BasicResPo> forgotPassword(@RequestParam String email) {
        BasicResPo response = userManagementService.forgotPassword(email);
        return new ResponseEntity<>(response, response.getStatusCode());
    }
    @DeleteMapping("/api/convertriteadmin/clients/{client_id}/users/{user_id}")
    public ResponseEntity<BasicResPo> deleteUser(@PathVariable(name = "client_id") Long clientId, @PathVariable Long user_id) {
        BasicResPo response = userManagementService.deleteUserById(user_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }
}
