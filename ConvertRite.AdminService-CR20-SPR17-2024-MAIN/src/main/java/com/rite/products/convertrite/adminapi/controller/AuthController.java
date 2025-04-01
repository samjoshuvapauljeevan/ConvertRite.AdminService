package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.exception.CRLicenseExpiredException;
import com.rite.products.convertrite.adminapi.model.CRClientLicenseLinks;
import com.rite.products.convertrite.adminapi.model.ClientAdmin;
import com.rite.products.convertrite.adminapi.model.License;
import com.rite.products.convertrite.adminapi.model.User;
import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.LoginReqPo;
import com.rite.products.convertrite.adminapi.po.LoginResPo;
import com.rite.products.convertrite.adminapi.po.PodBasicResPo;
import com.rite.products.convertrite.adminapi.respository.CRClientLicenseLinksRepository;
import com.rite.products.convertrite.adminapi.respository.ClientAdminRepository;
import com.rite.products.convertrite.adminapi.respository.LicenseRepository;
import com.rite.products.convertrite.adminapi.respository.UserRepository;
import com.rite.products.convertrite.adminapi.security.jwt.JwtUtils;
import com.rite.products.convertrite.adminapi.service.*;
import com.rite.products.convertrite.adminapi.utils.Constants;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import static org.springframework.http.HttpStatus.OK;

@RestController
@Slf4j
@Tag(name = "01. Auth", description = "APIs for authentication and freely accessible paths")
public class AuthController {
    @Autowired
    AuthenticationManager authenticationManager;
    @Autowired
    UserManagementService userManagementService;
    @Autowired
    ClientManagementService clientManagementService;
    @Autowired
    ClientAdminManagementService clientAdminManagementService;
    @Autowired
    JwtUtils jwtUtils;
    @Autowired
    ClientAdminRepository clientAdminRepository;
    @Autowired
    UserRepository userRepository;
    @Autowired
    AuthServiceImpl authServiceImpl;
    @Autowired
    HttpServletRequest request;
    @Autowired
    LicenseRepository licenseRepository;
    @Autowired
    CRClientLicenseLinksRepository crClientLicenseLinksRepository;

    @Operation(summary = "Api to get user authorization token",
            responses = {@ApiResponse(content = @Content(schema = @Schema(implementation = BasicResPo.class)))})
    @PostMapping("/api/convertriteadmin/auth/signin")
    public ResponseEntity<BasicResPo> authenticateUser(@RequestBody @Valid LoginReqPo loginRequest) {
        log.info("========authenticateUser========");
        log.info("Role from UI: {}",loginRequest.getRole());
        //Constants.ROLE.set(loginRequest.getRole());
        request.setAttribute("ROLE", loginRequest.getRole());
        AuthUserDetailsImpl userDetails = null;
        Boolean isfirstLogin = false;
        String jwt = "";
        String addFeature = "";
        List<String> roles = null;
        List<PodBasicResPo> licensedPods = new ArrayList<>();
        // try {
        Authentication authentication = authenticationManager
                .authenticate(new UsernamePasswordAuthenticationToken(loginRequest.getUsername(), loginRequest.getPassword()));
        userDetails = (AuthUserDetailsImpl) authentication.getPrincipal();
        SecurityContextHolder.getContext().setAuthentication(authentication);
        jwt = jwtUtils.generateJwtToken(authentication);

        roles = userDetails.getAuthorities().stream().map(item -> item.getAuthority())
                .collect(Collectors.toList());
        if (roles != null && roles.contains("ROLE_CLIENTADMIN")) {
            ClientAdmin clientAdmin = clientAdminRepository.findByClientAdminUserName(loginRequest.getUsername());
            isfirstLogin = clientAdmin.getIsFirstTimeLogin();
            Long clientId = clientAdmin.getClient().getClientId();
            addFeature = crClientLicenseLinksRepository.findAdditionalFeaturesByClientId(clientId);
        } else if (roles != null && roles.contains("ROLE_USER")) {
            User user = userRepository.findByEmail(loginRequest.getUsername());
            isfirstLogin = user.getIsFirstTimeLogin();
            Long clientId = user.getClientId();
            addFeature = crClientLicenseLinksRepository.findAdditionalFeaturesByClientId(clientId);
        }
        try {
            if (roles != null && roles.contains("ROLE_CLIENTADMIN")) {
                log.info("ClientAdmin Id---->" + userDetails.getId());
                licensedPods = (List<PodBasicResPo>) clientAdminManagementService.getLicensedPodsByClientAdminId(userDetails.getId()).getPayload();
            } else if (roles != null && roles.contains("ROLE_USER")) {
                log.info("UserId---->" + userDetails.getId());
                licensedPods = (List<PodBasicResPo>) userManagementService.getLicensedPodsByUserId(userDetails.getId()).getPayload();
            }
        } catch (Exception e) {
            log.error("Error while fetching licensed pods----> {} ", e.getMessage(), e);
            String expiryMessage = "Error while fetching licensed pods";
            throw new RuntimeException(expiryMessage);
        }
        if (licensedPods.isEmpty() && !loginRequest.getRole().equals("ROLE_RITEADMIN")) {
            String expiryMessage = "No licensed pods are available.";
            throw new CRLicenseExpiredException(expiryMessage);
        }

        String finalJwt = jwt;
        String finaladdFeature = addFeature;
        Boolean finalIsfirstLogin = isfirstLogin;
        AuthUserDetailsImpl finalUserDetails = userDetails;
        List<String> finalRoles = roles;
        BasicResPo response = new BasicResPo() {{
            setStatusCode(OK);
            setStatus("success");
            setMessage("Login in success.");
            setPayload(new LoginResPo(finalJwt, finalUserDetails.getId(), finalUserDetails.getUsername(), finalRoles, finalIsfirstLogin,finaladdFeature));
        }};
        return new ResponseEntity<>(response, response.getStatusCode());
    }


    @Operation(summary = "Api to get user authtype",
            responses = {@ApiResponse(content = @Content(schema = @Schema(implementation = BasicResPo.class)))})
    @GetMapping("/api/convertriteadmin/auth/{user_name}")
    public ResponseEntity<BasicResPo> getAuthType(@PathVariable(name = "user_name") String userName) {
        BasicResPo response = userManagementService.getUserAuthType(userName);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @Operation(summary = "Api to get all clients with details",
            responses = {@ApiResponse(content = @Content(schema = @Schema(implementation = BasicResPo.class)))})
    @GetMapping("/api/convertriteadmin/auth/clientdetails")
    public ResponseEntity<BasicResPo> getClientLogo() {
        BasicResPo response = clientManagementService.getClients();
        return new ResponseEntity<>(response, response.getStatusCode());
    }


    @GetMapping("/api/convertriteadmin/auth/refresh-token")
    public ResponseEntity<?> refreshToken(@RequestHeader("Authorization") String oldToken) {
        oldToken = oldToken.substring(7); // Remove "Bearer " prefix
        log.info("Old token: " + oldToken);
        try {
            if (!jwtUtils.validateJwtToken(oldToken) || jwtUtils.isTokenExpired(oldToken)) {
                log.error("Token is invalid or expired");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Token is invalid or expired");
            }

            String username = jwtUtils.getUserNameFromJwtToken(oldToken);
            UserDetails userDetails = authServiceImpl.loadUserByUsername(username);
            Authentication authentication = new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
            SecurityContextHolder.getContext().setAuthentication(authentication);
            String newToken = jwtUtils.generateJwtToken(authentication);

            log.info("Successfully generated new token");
            return ResponseEntity.ok(newToken);
        } catch (Exception e) {
            log.error("Failed to generate new token", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Failed to generate new token");
        }
    }
}

