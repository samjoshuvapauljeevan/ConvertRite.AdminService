package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.model.ValidationObject;
import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.ExecuteCustomObjectRequest;
import com.rite.products.convertrite.adminapi.po.GetValidationObjectsReqPo;
import com.rite.products.convertrite.adminapi.po.ValidateSqlObjectRequest;
import com.rite.products.convertrite.adminapi.service.ValidationService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.util.List;
import java.util.Map;

@RestController
@Slf4j
@RequestMapping("/api/convertriteadmin/validation")
public class ValidationController {

    @Autowired
    private ValidationService validationService;

    @PostMapping("/compileAndUploadSql")
    public ResponseEntity<?> compileAndUploadSql(@ModelAttribute ValidateSqlObjectRequest request, Authentication authentication) {

        BasicResPo response = new BasicResPo();
        try {
            String username = authentication.getName();
            log.info(" User name: {} ", username);
            validationService.compileAndUploadSql(request, username);
            response.setStatusCode(HttpStatus.OK);
            response.setMessage("File uploaded and executed successfully");
            log.info("File uploaded and executed successfully");
        } catch (IOException e) {
            log.error("In IOException, Error while uploading and executing the SQL file.", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Error while uploading and executing the SQL file: " + e.getMessage());
        } catch (Exception e) {
            log.error("Error while uploading and executing the SQL file.", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Error while uploading and executing the SQL file: " + e.getMessage());
        }
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PostMapping("/executeValidationObjects")
    public ResponseEntity<?> executeCustomObjects(
            @RequestBody ExecuteCustomObjectRequest request,
            Authentication authentication) {

        BasicResPo response = new BasicResPo();
        try {
            // Validation: Ensure  objectIds  is present and non-empty and project ID is present and valid
            if ((request.getObjectIds() == null || request.getObjectIds().isEmpty()) || request.getProjectId() == null) {
                response.setStatusCode(HttpStatus.BAD_REQUEST);
                response.setMessage(" ObjectIds and projectId must be provided and cannot be empty .");
                return new ResponseEntity<>(response, response.getStatusCode());
            }

            // Fetch related custom objects based on the provided IDs
            Map<Long, List<ValidationObject>> customObjectsMap = validationService.fetchCustomObjectsMap(request.getObjectIds());
            if (customObjectsMap.isEmpty() || customObjectsMap.values().stream().allMatch(List::isEmpty)) {
                response.setStatusCode(HttpStatus.NOT_FOUND);
                response.setMessage("No custom objects found for the given IDs.");
                return new ResponseEntity<>(response, response.getStatusCode());
            }

            // Execute the custom objects
            String userName = authentication.getName();
            log.info("User name: {} ", userName);

            String errorMessages = validationService.executeCustomValidationObjects(request, userName);
            if (errorMessages.isEmpty() || errorMessages.contains("SUCCESS")) {
                response.setStatusCode(HttpStatus.OK);
                response.setMessage("At least one Custom Object executed successfully "+errorMessages);
                log.info("At least one Custom Object executed successfully {} ", errorMessages);
            } else {
                response.setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                response.setMessage("Execution completed with errors:\n" + errorMessages);
                log.error("Execution completed with errors:\n {} ", errorMessages);
            }
        } catch (Exception e) {
            log.error("Error while executing procedures.", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Error while executing procedures: " + e.getMessage());
        }
        return new ResponseEntity<>(response, response.getStatusCode());
    }

   @PostMapping("/getValidationObjects")
    public ResponseEntity<BasicResPo> getValidationObjects(@RequestBody GetValidationObjectsReqPo validationObjectsReqPo) {
        BasicResPo responsePo = new BasicResPo();
        if (validationObjectsReqPo.getObjectIdLi() == null || validationObjectsReqPo.getObjectIdLi().isEmpty()) {
            responsePo.setMessage("ObjectIds cannot be empty");
            responsePo.setStatusCode(HttpStatus.BAD_REQUEST);
            return new ResponseEntity<>(responsePo, HttpStatus.BAD_REQUEST);
        }
        Map<Long, List<ValidationObject>> validationObjectsResMap = validationService.fetchCustomObjectsMap(validationObjectsReqPo.getObjectIdLi());
        if (validationObjectsResMap.isEmpty() || validationObjectsResMap.values().stream().allMatch(List::isEmpty)) {
            responsePo.setStatusCode(HttpStatus.NOT_FOUND);
            responsePo.setMessage("No validation objects found for the given objectIds.");
            return new ResponseEntity<>(responsePo, responsePo.getStatusCode());
        }
        responsePo.setPayload(validationObjectsResMap);
        responsePo.setMessage("Successfully retrieved validation objects");
        responsePo.setStatusCode(HttpStatus.OK);
        return new ResponseEntity<>(responsePo, HttpStatus.OK);
    }

}
