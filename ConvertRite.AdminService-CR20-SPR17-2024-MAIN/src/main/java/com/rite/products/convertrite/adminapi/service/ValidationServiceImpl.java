package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.model.ObjectSource;
import com.rite.products.convertrite.adminapi.model.ValidationObjectAudit;
import com.rite.products.convertrite.adminapi.po.ExecuteCustomObjectRequest;
import com.rite.products.convertrite.adminapi.po.ValidateSqlObjectRequest;
import com.rite.products.convertrite.adminapi.model.ValidationObject;
import com.rite.products.convertrite.adminapi.model.Pod;

import com.rite.products.convertrite.adminapi.respository.CustomObjectAuditRepository;
import com.rite.products.convertrite.adminapi.respository.ValidationObjectRepository;
import com.rite.products.convertrite.adminapi.respository.PodRepository;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.apache.ibatis.jdbc.ScriptRunner;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.stereotype.Service;

import java.io.*;
import java.nio.file.*;
import java.sql.*;
import java.util.*;
import java.util.stream.Collectors;

@Service
@Slf4j
public class ValidationServiceImpl implements ValidationService {

    @Autowired
    private ValidationObjectRepository customObjectRepository;

    @Autowired
    private PodRepository podRepository;

    @Value("${validation.api.mount.path}")
    private String fileUploadPath;

    @Autowired
    private CustomObjectAuditRepository customObjectAuditRepository;

    @Value("${db.connection.max.retries}")
    Integer maxRetries;

    @PostConstruct
    public void init() throws IOException {
        try {
            log.info("Initializing Validation Service to copy the files from the classpath to the fileUploadPath: {}", fileUploadPath);
            // Ensure the directory exists, create it if not
            Path destinationPath = Paths.get(fileUploadPath);
            if (Files.notExists(destinationPath)) {
                try {
                    log.info("Directory does not exist. Creating directory: {}", destinationPath);
                    Files.createDirectories(destinationPath);
                } catch (IOException e) {
                    log.error("Failed to create directory at {}. Possible permission issue or invalid path. Error: {}", destinationPath, e.getMessage());
                    throw e; // Re-throw the exception to prevent further execution
                }
            }

            PathMatchingResourcePatternResolver resolver = new PathMatchingResourcePatternResolver();
            org.springframework.core.io.Resource[] resources = resolver.getResources("classpath:/validation_api/**/*.sql");
            log.info("Found {} resources", resources.length);

            for (Resource resource : resources) {
                Path filePath = destinationPath.resolve(Paths.get(resource.getFilename()));
                try (InputStream is = resource.getInputStream()) {
                    Files.copy(is, filePath, StandardCopyOption.REPLACE_EXISTING);
                    log.info("File copied to path: {}", filePath);
                } catch (IOException e) {
                    log.error("Error while copying file: {}", e.getMessage());
                }
            }
        } catch (Exception e) {
            log.error("Error while running the post construct at app startup: {}", e.getMessage());
        }
    }



    @Override
    public String compileAndUploadSql(ValidateSqlObjectRequest request, String username) throws IOException {
        log.info("Validating and uploading SQL");

        // Copy the uploaded file to the specified path
        Path filePath = Paths.get(fileUploadPath, request.getFile().getOriginalFilename());
        Files.copy(request.getFile().getInputStream(), filePath, StandardCopyOption.REPLACE_EXISTING);
        log.info("Copied file to mount path: {}", filePath);

        // Save the ValidationObject and get the saved object
        ValidationObject savedCustomObject = saveCustomObject(request, username);
        log.info("In compileAndUploadSql(), Saved custom object: {}", savedCustomObject);

        StringBuilder errorMessages = new StringBuilder();

        // Create a map for objectId to ValidationObject mapping
        Map<Long, List<ValidationObject>> objectIdToValidationObjectsMap = new HashMap<>();
        objectIdToValidationObjectsMap.put(request.getObjectId(), Collections.singletonList(savedCustomObject));

        if (request.getPodId() != null) {
            // Execute on the specified pod
            try {
                errorMessages.append(executeCustomObjectsOnPod(request.getPodId(), null, objectIdToValidationObjectsMap, username, false));
            } catch (Exception e) {
                log.error("Error executing on pod ID: {} ", request.getPodId(), e);
                errorMessages.append("Error executing on pod ID: ").append(request.getPodId()).append(" - ").append(e.getMessage()).append("\n");
            }
        } else {
            // Execute on all pods
            List<Pod> pods = podRepository.findAll();
            log.info("Executing on all pods");
            for (Pod pod : pods) {
                try {
                    errorMessages.append(executeCustomObjectsOnPod(pod.getPodId(), null, objectIdToValidationObjectsMap, username, false));
                } catch (Exception e) {
                    log.error("Error executing on pod ID: {} ", pod.getPodId(), e);
                    errorMessages.append("Error executing on pod ID: ").append(pod.getPodId()).append(" - ").append(e.getMessage()).append("\n");
                    // Continue to next pod
                }
            }
        }
        if (!errorMessages.isEmpty()) {
            log.error("Error messages not empty: {}", errorMessages.toString());
        }
        return errorMessages.toString();
    }

    private ValidationObject saveCustomObject(ValidateSqlObjectRequest request, String username) {
        // Check if a record with the same filename already exists
        Optional<ValidationObject> existingCustomObject = customObjectRepository.findByFilename(request.getFilename());

        ValidationObject customObject;
        if (existingCustomObject.isPresent()) {
            // Update the existing record
            customObject = existingCustomObject.get();
            log.info("Filename exists. Updating the existing record: {}", customObject.getValidationObjectId());
            customObject.setObjectId(request.getObjectId());
            customObject.setObjectType(request.getObjectType());
            customObject.setSyncDependentTables(request.getDependantTables());
            customObject.setUpdatedBy(username);
            customObject.setUpdatedAt(new java.util.Date());
        } else {
            // Create a new record
            customObject = new ValidationObject();
            customObject.setObjectId(request.getObjectId());
            customObject.setObjectType(request.getObjectType());
            customObject.setFilename(request.getFilename());
            customObject.setObjectSource(ObjectSource.ADMIN_UI);
            customObject.setSyncDependentTables(request.getDependantTables());
            customObject.setCreatedBy(username);
            customObject.setUpdatedBy(username);
            customObject.setCreatedAt(new java.util.Date());
            customObject.setUpdatedAt(new java.util.Date());
        }

        ValidationObject savedCustomObject = customObjectRepository.save(customObject);
        log.info("Saved custom object: {}", savedCustomObject);
        return savedCustomObject;
    }


    private String executeCustomObjectsOnPod(Long podId, Long projectId,
                                             Map<Long, List<ValidationObject>> objectIdToValidationObjectsMap,
                                             String username , boolean updatePreloadTable) throws IOException {
        Pod pod = podRepository.findById(podId)
                .orElseThrow(() -> new IllegalArgumentException("Invalid pod ID: " + podId));

        StringBuilder errorMessages = new StringBuilder();
        int attempt = 0;
        boolean connectionSuccess = false;

        while (attempt < maxRetries && !connectionSuccess) {
            Connection connection = null;
            try {
                connection = DriverManager.getConnection(
                        pod.getPodTargetUrl(), pod.getPodDbUser(), pod.getPodDbPassword());
                connection.setAutoCommit(false);

                log.info("Connection successful.");
                ScriptRunner runner = new ScriptRunner(connection);
                runner.setStopOnError(true);
                runner.setThrowWarning(true);
                runner.setDelimiter("$#$");

                // Loop through the map
                for (Map.Entry<Long, List<ValidationObject>> entry : objectIdToValidationObjectsMap.entrySet()) {
                    Long objectId = entry.getKey();
                    List<ValidationObject> customObjects = entry.getValue();

                    StringBuilder errorMsgsPerObjectId = new StringBuilder();
                    StringBuilder errorStatusPerObjectId = new StringBuilder();
                    StringBuilder successMsgPerObjectId = new StringBuilder();
                    StringBuilder validationPackages = new StringBuilder();

                    if(updatePreloadTable && !isValidPackageStatus(connection, projectId, objectId) ){
                        log.info("Skipping object Id {} as it does not have a valid package status ", objectId);
                        errorMsgsPerObjectId.append("Skipping object Id ").append(objectId).append(" as it does not have a valid package status \n");
                        errorMessages.append(errorMsgsPerObjectId);
                        continue;
                    }
                    log.info("Iterating through customObjects list for objectId {}: {}", objectId, customObjects);
                    for (ValidationObject customObject : customObjects) {
                        try {
                            validationPackages.append(customObject.getFilename()).append(", ");
                            Path filePath = Paths.get(fileUploadPath, customObject.getFilename());
                            String fileContent = new String(Files.readAllBytes(filePath));

                            log.info("Executing SQL script for pod ID {} and custom object Id {} from file {}: \n", podId, customObject.getValidationObjectId(), customObject.getFilename());
                            runner.runScript(new BufferedReader(new StringReader(fileContent)));

                            // If successful, commit this individual file's changes
                            connection.commit();
                            saveCustomObjectAuditLog(podId, customObject.getObjectId(), customObject, true, username, null);
                            log.info("Successfully committed changes for file: {}", customObject.getFilename());
                            successMsgPerObjectId.append(" PackageName : ").append(customObject.getFilename()).append(" - SUCCESS,").append("\n");
                        }
                        catch(NoSuchFileException | FileNotFoundException e){
                            log.error("PodId {} CustomObjectId {}, File not found: {}", podId, customObject.getValidationObjectId(), customObject.getFilename(), e);
                            errorMsgsPerObjectId.append("PackageName : ").append(customObject.getFilename()).append(" - FAILURE - ").append("File not found: "+customObject.getFilename()+",").append("\n");
                            errorStatusPerObjectId.append("PackageName : ").append(customObject.getFilename()).append(" - FAILURE ,").append("File not found: "+customObject.getFilename());
                            saveCustomObjectAuditLog(podId, customObject.getObjectId(), customObject, false, username, "File not found : "+customObject.getFilename());
                        }
                        catch (Exception e) {
                            // If there's an exception for this file, rollback only this file's changes
                            log.error("PodId {} CustomObjectId {}, Error executing SQL file: {}. Rolling back changes for this file.", podId, customObject.getValidationObjectId(), customObject.getFilename(), e);
                            try {
                                connection.rollback();
                            } catch (SQLException rollbackException) {
                                log.error("Pod Id - {} Error during rollback for file: {}", podId, customObject.getFilename(), rollbackException);
                            }
                            // Capture the error message
                            errorMsgsPerObjectId.append("PackageName : ").append(customObject.getFilename()).append(" - FAILURE: ").append(e.getMessage()+",").append("\n");
                            errorStatusPerObjectId.append("PackageName : ").append(customObject.getFilename()).append(" - FAILURE ,");
                            saveCustomObjectAuditLog(podId, customObject.getObjectId(), customObject, false, username, e.getMessage());

                        }
                    }

                    // Update CR_PRELOAD_CLD_SETUP_STATUS table
                    if(updatePreloadTable){

                        try {
                            log.info("Updating CR_PRELOAD_CLD_SETUP_STATUS for pod ID {} and object ID {} with packages: {}", podId, objectId, validationPackages.toString());
                            updateCldSetupStatus(connection, projectId, objectId, validationPackages.toString(), errorStatusPerObjectId.toString(), successMsgPerObjectId.toString());
                        } catch (SQLException e) {
                            log.error("Error updating CR_PRELOAD_CLD_SETUP_STATUS for projectId: {} and objectId: {}", projectId, objectId, e);
                            errorMessages.append("Error updating setup status for projectId ").append(projectId).append(" and objectId ").append(objectId).append(": ").append(e.getMessage()).append("\n");
                        }
                    }
                    errorMessages.append(successMsgPerObjectId.append(errorMsgsPerObjectId));
                }
                connectionSuccess = true;
            } catch (SQLTransientConnectionException e) {
                log.error("Transient connection error during SQL execution on pod ID:{} ", podId, e);
                errorMessages.append("Transient connection error on pod ID ").append(podId).append(": ").append(e.getMessage()).append("\n");
                attempt++;
                if (attempt < maxRetries) {
                    log.info("Retrying connection for pod ID: {} (Attempt {}/{})", podId, attempt + 1, maxRetries);
                } else {
                    log.error("Max retries reached for pod ID: {}", podId);
                    errorMessages.append("Max retries reached for pod ID ").append(podId).append("\n");
                    saveCustomObjectAuditLog(podId, null, null, false, username, e.getMessage());
                    break;
                }
            } catch (Exception e) {
                log.error("Unexpected SQL error during execution on pod ID: {} ", podId, e);
                errorMessages.append("Unexpected SQL error on pod ID ").append(podId).append(": ").append(e.getMessage()).append("\n");
                saveCustomObjectAuditLog(podId, null, null, false, username, e.getMessage());
                break;
            } finally {
                if (connection != null) {
                    try {
                        connection.close();
                    } catch (SQLException closeException) {
                        log.error("Error closing connection for pod ID: {} ", podId, closeException);
                    }
                }
            }
        }
        return errorMessages.toString();
    }

    private boolean isValidPackageStatus(Connection connection, Long projectId, Long objectId) throws SQLException {
        log.info("Validating package status for projectId: {} and objectId: {}", projectId, objectId);

        String query = "SELECT VAL_PKG_STATUS FROM CR_PRELOAD_CLD_SETUP_STATUS WHERE PROJECT_ID = ? AND OBJECT_ID = ?";
        try (PreparedStatement preparedStatement = connection.prepareStatement(query)) {
            preparedStatement.setLong(1, projectId);
            preparedStatement.setLong(2, objectId);

            try (ResultSet resultSet = preparedStatement.executeQuery()) {
                List<String> statusList = new ArrayList<>();

                while (resultSet.next()) {
                    statusList.add(resultSet.getString("VAL_PKG_STATUS"));
                }

                if (statusList.size() > 1) {
                    log.error("More than one row found for the same projectId and objectId.");
                    throw new IllegalStateException("More than one row found for the same projectId and objectId.");
                }

                if (statusList.isEmpty()) {
                    log.error("No rows found for the projectId and objectId in CR_PRELOAD_CLD_SETUP_STATUS table.");
                    throw new IllegalStateException("No rows found for the projectId and objectId in CR_PRELOAD_CLD_SETUP_STATUS table.");  // No row found, consider it as false
                }
                String status = statusList.get(0);
                log.info("Validation package status: {}", status);
                return "1. Validation Tables Created Successfully".equals(status);
            }
        }
    }

    private void updateCldSetupStatus(Connection connection, Long projectId, Long objectId, String validationPackages, String errorMsgsPerObjectId, String sucessMsgPerObjectId) throws SQLException {
        String updateQuery;
        if (errorMsgsPerObjectId.isEmpty()) {
            updateQuery = "UPDATE CR_PRELOAD_CLD_SETUP_STATUS " +
                    "SET VAL_PKG_STATUS = ?, VAL_PKG_ERROR_MESSAGE = ?, VAL_PKG_EXECUTION = ?, LAST_UPDATE_DATE = SYSDATE " +
                    "WHERE PROJECT_ID = ? AND OBJECT_ID = ?";
        } else {
            // trim the errorMsgsPerObjectId to only its first 2000 characters due to db field size limit
            errorMsgsPerObjectId = errorMsgsPerObjectId.substring(0, Math.min(errorMsgsPerObjectId.length(), 2000));
            updateQuery = "UPDATE CR_PRELOAD_CLD_SETUP_STATUS " +
                    "SET VAL_PKG_ERROR_MESSAGE = ?, VAL_PKG_EXECUTION = ?, LAST_UPDATE_DATE = SYSDATE " +
                    "WHERE PROJECT_ID = ? AND OBJECT_ID = ?";
        }

        String trimmedValidationPackages = validationPackages.toString().replaceFirst(",\\s*$", "");
        try (PreparedStatement preparedStatement = connection.prepareStatement(updateQuery)) {
            if (errorMsgsPerObjectId.isEmpty()) {
                preparedStatement.setString(1, "2. Validation PKG compiled successfully");
                preparedStatement.setString(2, sucessMsgPerObjectId+"\n"+errorMsgsPerObjectId);
                preparedStatement.setString(3, trimmedValidationPackages);
                preparedStatement.setLong(4, projectId);
                preparedStatement.setLong(5, objectId);
            } else {
                preparedStatement.setString(1, sucessMsgPerObjectId+"\n"+errorMsgsPerObjectId);
                preparedStatement.setString(2, trimmedValidationPackages);
                preparedStatement.setLong(3, projectId);
                preparedStatement.setLong(4, objectId);
            }
            preparedStatement.executeUpdate();
            connection.commit();
            log.info("Updated CR_PRELOAD_CLD_SETUP_STATUS for projectId {} and objectId {} ", projectId, objectId);
        } catch (Exception e) {
            log.error("Error updating CR_PRELOAD_CLD_SETUP_STATUS for projectId {} and objectId {} ", projectId, objectId, e);
        }
    }

    @Override
    public String executeCustomValidationObjects(ExecuteCustomObjectRequest request, String username) throws IOException {
        log.info("Executing custom validation objects");
        StringBuilder errorMessages = new StringBuilder();
        // Fetch the ValidationObjects for the given object IDs
        Map<Long, List<ValidationObject>> objectIdToValidationObjectsMap = fetchCustomObjectsMap(request.getObjectIds());
        if (request.getPodId() != null) {
            // Execute on the specified pod
            errorMessages.append(executeCustomObjectsOnPod(request.getPodId(), request.getProjectId(), objectIdToValidationObjectsMap, username, true));
        } else {
            // Execute on all pods
            List<Pod> pods = podRepository.findAll();
            for (Pod pod : pods) {
                errorMessages.append(executeCustomObjectsOnPod(pod.getPodId(), request.getProjectId(), objectIdToValidationObjectsMap, username, true));
            }
        }
        if (!errorMessages.isEmpty()) {
            log.error("Error messages: {}", errorMessages.toString());
        }
        return errorMessages.toString();
    }

    @Override
    public Map<Long, List<ValidationObject>> fetchCustomObjectsMap(List<Long> objectIds) {
        log.info("Fetching custom objects map for objectIds: {}", objectIds);
        if (objectIds != null && !objectIds.isEmpty()) {
            List<ValidationObject> validationObjects = customObjectRepository.findByObjectIds(objectIds);
            return validationObjects.stream().collect(Collectors.groupingBy(ValidationObject::getObjectId));
        }
        return Collections.emptyMap();
    }

    private void saveCustomObjectAuditLog(Long podId,  Long objectId, ValidationObject customObject, Boolean success, String username, String errorMessage) {
        ValidationObjectAudit auditRecord = new ValidationObjectAudit();
        auditRecord.setPodId(podId);
        auditRecord.setObjectId(objectId);
        auditRecord.setValidationObject(customObject);
        auditRecord.setSuccess(success);
        auditRecord.setErrorMessage(errorMessage);
        auditRecord.setCreatedBy(username);
        auditRecord.setCreationDate(new java.util.Date());
        customObjectAuditRepository.save(auditRecord);
        log.info("Saved custom object audit log: {}", auditRecord);
    }
}