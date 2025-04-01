package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.exception.CRAdminException;
import com.rite.products.convertrite.adminapi.exception.CRNotFoundException;
import com.rite.products.convertrite.adminapi.exception.CRUniquenessException;
import com.rite.products.convertrite.adminapi.model.*;
import com.rite.products.convertrite.adminapi.model.Module;
import com.rite.products.convertrite.adminapi.po.*;
import com.rite.products.convertrite.adminapi.respository.*;
import com.rite.products.convertrite.adminapi.utils.DataSourceUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.lang3.StringUtils;
import org.apache.ibatis.jdbc.ScriptRunner;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.core.io.support.ResourcePatternResolver;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.io.*;
import java.net.URISyntaxException;
import java.nio.charset.StandardCharsets;
import java.sql.*;
import java.sql.Date;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@RequiredArgsConstructor
@Service
@Slf4j
public class PodManagementServiceImpl extends BasicManagementService<Pod, Long> implements PodManagementService {

    private static final String VALID_DATABASE_NAME_REGEXP = "[A-Za-z0-9_]*";
    private static final Pattern FORBIDDEN_PATTERNS = Pattern.compile(
            "(?i)" +  // Case-insensitive matching
                    //commented code to disable drop   "\\b(DROP\\s+TABLE\\s+\\w+|TRUNCATE\\s+TABLE\\s+\\w+|DELETE\\s+FROM\\s+\\w+)");
                    "\\b(TRUNCATE\\s+TABLE\\s+\\w+|DELETE\\s+FROM\\s+\\w+)");
    @Autowired
    PodRepository podRepository;

    @Autowired
    ModuleRepository moduleRepository;

    @Autowired
    LicenseRepository licenseRepository;

    @Autowired
    DataSourceUtil dataSourceUtil;

    @Value("${oracle.datasource.url}")
    private String url;

    @Value("${schema.upgrade.base.path}")
    private String schemaUpgradeBasePath;

    @Autowired
    private SqlExecutionLogRepository sqlExecutionLogRepository;

    @Autowired
    DataSyncService dataSyncService;

    @Autowired
    ObjectRepository objectRepository;

    @Autowired
    ObjectInformationRepository objectInformationRepository;

    @Autowired
    CRTargetInterfaceColumnRepository cRTargetInterfaceColumnRepository;

    private String userName;

    @Value("${schema.master-scripts.path}")
    private String masterScriptsPath;

    @Override
    public BasicResPo createPod(PodCreationReqPo podCreationReqPo) {
        boolean isOracleUserCreated = false;
        String podDbUserName = podCreationReqPo.getDatabaseUserName();
        try {
            checkPodLimit(podCreationReqPo);
            // Verify podName string to prevent SQL injection
            if (!podDbUserName.matches(VALID_DATABASE_NAME_REGEXP)) {
                throw new CRAdminException("Invalid pod username: " + podDbUserName);
            }
            createPod(podDbUserName, podCreationReqPo.getDatabasePassword(), podCreationReqPo.getTablespaceSize());
            isOracleUserCreated = true;

            // Load and execute the script on the master database
     /*       try {
                log.info("Executing script directory on master DB");
                BasicResPo response = executeScriptOnMasterDb(masterScriptsPath);

                if (response.getStatusCode() != HttpStatus.OK) {
                    log.error("Error executing script on master DB: {} ", response.getMessage());
                    throw new CRAdminException("Error executing script on master DB: " + response.getMessage());
                } else {
                    log.info("Successfully executed script on master DB: {}", response.getMessage());
                }
            } catch (Exception e) {
                log.error("Exception occurred while executing script on master DB: {} ", e.getMessage(), e);
                throw new CRAdminException("Error executing script on master DB: ", e);
            } */

            //Load the schema tables in to newly created pod
            try (Connection connection = DriverManager.getConnection(url, podDbUserName, podCreationReqPo.getDatabasePassword())) {
                loadSchema(connection);
            } catch (Exception e) {
                log.error("Error while Loading Schema into the Pod---> {} ", e.getMessage());
                throw new CRAdminException("Error when populating schema into pod: ", e);
            }
            Pod p = new Pod();
            p.setPodName(podCreationReqPo.getPodName());
            p.setPodDbUser(podDbUserName);
            p.setPodDbPassword(podCreationReqPo.getDatabasePassword());
            p.setPodTargetUrl(url);
            p.setTablespaceSize(podCreationReqPo.getTablespaceSize());
            if (podCreationReqPo.getLicenseId() != null) {
                License license = new License();
                license.setLicenseId(podCreationReqPo.getLicenseId());
                p.setLicense(license);
            }
            if (podCreationReqPo.getClientId() != null) {
                Client client = new Client();
                client.setClientId(podCreationReqPo.getClientId());
                p.setClient(client);
            }
            if(StringUtils.isNotBlank(podCreationReqPo.getScheduledJobFlag()))
                p.setScheduledJobFlag(podCreationReqPo.getScheduledJobFlag());

            p.setLastUpdatedBy("ConvertRiteAdmin");
            p.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
            p.setCreationDate(new java.sql.Date(new java.util.Date().getTime()));
            p.setCreatedBy("ConvertRiteAdmin");
            Pod entityRes = super.addEntity(podRepository, p);
            Pod createdEntity = super.getEntityById(podRepository, entityRes.getPodId());

            try{
                log.info("Loading schema updates for pod: {} ", createdEntity.getPodName());
                loadSchemaUpdates(createdEntity);
                log.info("Successfully loaded schema updates for pod: {}", createdEntity.getPodName());

                log.info("Syncing object data for pod: {}", createdEntity.getPodName());
                dataSyncService.syncObjectDataToSinglePod(objectRepository.findAll(), DataSyncService.Operation.INSERT, createdEntity, true);

                log.info("Syncing object information data for pod: {}", createdEntity.getPodName());
                dataSyncService.syncObjectInfoDataToSinglePod(objectInformationRepository.findAll(), DataSyncService.Operation.INSERT, createdEntity);

                log.info("Syncing interface column data for pod: {}", createdEntity.getPodName());
                dataSyncService.syncTargetInterfaceColumnToSinglePod(cRTargetInterfaceColumnRepository.findAll(), createdEntity);

                log.info("Successfully synced data for pod: {} ", createdEntity.getPodName());
            }
            catch (Exception e) {
                log.error("Error while setting up updates into the Pod---> {} ", e.getMessage());
                throw new CRAdminException("Error when setting up updates into pod: ", e);
            }
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CREATED);
                setStatus("success");
                setMessage("Successfully created pod " + createdEntity.getPodName());
                setPayload(generatePodDetailsResPo(createdEntity));
            }};
        } catch (CRUniquenessException ex) {
            String errorMessage = "Pod name " + podCreationReqPo.getPodName() + " is already available. It should be unique.";
            if(isOracleUserCreated){
                try {
                    deletePod(podDbUserName);
                } catch (Exception e) {
                    //throw new RuntimeException(e);
                }
            } else {
                errorMessage = "Database User " + podCreationReqPo.getDatabaseUserName() + " is already available. It should be unique.";
            }

            String finalErrorMessage = errorMessage;
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage(finalErrorMessage);
                setPayload(ex);
            }};
        } catch (Exception ex) {
            if(isOracleUserCreated){
                try {
                    deletePod(podDbUserName);
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            }
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    public BasicResPo executeScriptOnMasterDb(String scriptPath) throws IOException, SQLException {
        BasicResPo response = new BasicResPo();
        ResourcePatternResolver resourcePatternResolver = new PathMatchingResourcePatternResolver();
        Resource resource = resourcePatternResolver.getResource("classpath:" + scriptPath);

        if (resource.exists()) {
            log.info("Resource found: {}", scriptPath);
            try {
                if (isValidDirectory(scriptPath)) {
                    log.info("Resource is a valid directory: {}", scriptPath);
                    executeSqlDirectoryOnMasterDB(scriptPath);
                } else {
                    if (resource.isReadable()) {
                        log.info("Resource is readable: {}", scriptPath);
                        executeSqlFileOnMasterDB(resource);
                    } else {
                        log.error("Resource not readable: {} ", scriptPath);
                        return createErrorResponse(HttpStatus.NOT_FOUND, "Resource not readable: " + scriptPath);
                    }
                }
                response.setStatusCode(HttpStatus.OK);
                response.setStatus("success");
                response.setMessage("Script executed successfully: " + scriptPath);
                log.info("Script executed successfully: {} ",scriptPath);
            } catch (IOException | SQLException e) {
                log.error("Error executing script: {} ", scriptPath, e);
                return createErrorResponse(HttpStatus.INTERNAL_SERVER_ERROR, "Error executing script: " + e.getMessage());
            }
        } else {
            log.error("Resource not found: {}", scriptPath);
            return createErrorResponse(HttpStatus.NOT_FOUND, "Resource not found: " + scriptPath);
        }

        return response;
    }

    private void executeSqlFileOnMasterDB(Resource resource) throws IOException, SQLException {
        try  {

            log.info("Getting sql content from resource: {}", resource.getFilename());
            String sqlContent = new String(resource.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
            try (Connection connection = dataSourceUtil.createOracleConnection()) {
                log.info("Executing SQL script: {} ", resource.getFilename());
                runSqlScript(sqlContent, connection);
            } catch (SQLException ex) {
                log.error("SQL Exception while executing script: {} ", resource.getFilename(), ex);
                throw new RuntimeException("SQL Exception while executing script", ex);
            } catch (Exception e) {
                log.error("Error executing script: {} ", resource.getFilename(), e);
                throw new RuntimeException(e);
            }
        }
        catch (Exception e) {
            log.error("Error executing script:  {} ", resource.getFilename(), e);
            throw new RuntimeException(e);
        }
    }

    private void executeSqlDirectoryOnMasterDB(String scriptPath) throws IOException {
        List<Resource> resourceList = getResourcesFromPath(scriptPath);
        log.info("Found {} resources in directory: {}", resourceList.size(), scriptPath);
        List<String> sqlContentList = getSqlContentFromResources(resourceList);
        log.info("Fetched sqlContentList from resources");

        Connection connection = null;
        try {
            connection = dataSourceUtil.createOracleConnection();
            connection.setAutoCommit(false); // Begin transaction

            for (String sqlContent : sqlContentList) {
                try {
                    log.info("Executing SQL script from directory: {}", scriptPath);
                    runSqlScript(sqlContent, connection);
                }  catch (Exception e) {
                    log.error("Exception while executing script: {} ", scriptPath, e);
                    throw new RuntimeException(e);
                }
            }

            connection.commit(); // Commit transaction
        } catch (Exception e) {
            if (connection != null) {
                try {
                    connection.rollback(); // Rollback transaction in case of error
                    log.info("Transaction rolled back due to error");
                } catch (SQLException rollbackEx) {
                    log.error("Failed to rollback transaction", rollbackEx);
                }
            }
            throw new RuntimeException("Error executing scripts from directory", e);
        } finally {
            if (connection != null) {
                try {
                    connection.close(); // Ensure connection is closed
                    log.info("Connection closed successfully");
                } catch (SQLException ex) {
                    log.error("Error closing database connection", ex);
                }
            }
        }
    }


    private void loadSchemaUpdates(Pod pod) throws IOException {
        try {
            log.info("Applying sql versions for pod ID {}", pod.getPodId());
            List<Double> versionsList = getAllAvailableVersions();

            if (versionsList.isEmpty()) {
                log.info("No versions found in the path: {} ", schemaUpgradeBasePath);
                return;
            }
            // find out the max version in versionsList
            Double maxVersion = Collections.max(versionsList);
            log.info("Max version in versionsList: {}", maxVersion);
            String maxVersionPath = constructVersionPath(maxVersion.toString());
            String errorMessages = "";
            errorMessages = applySqlVersionsForSinglePod(pod.getClient().getClientId(), maxVersionPath, pod);

            if (!errorMessages.isEmpty()) {
                log.error("errorMessages Not EmptyError in applying sql versions: {}", errorMessages);
                throw new CRAdminException("Error in applying sql versions: " + errorMessages);
            } else {
                log.info("Successfully applied sql versions for newly created pod ID {}", pod.getPodId());
            }
        }
        catch (Exception e) {
            log.error("Error in applying sql versions: {} ", e.getMessage());
            throw new CRAdminException("Error in applying sql versions: " + e.getMessage());
        }
    }

    @Override
    public BasicResPo getPods() {

        List<Pod> pods = podRepository.findByOrderByPodIdAsc();
        List<PodBasicResPo> res = new ArrayList<>();
        if (pods != null) {
            for (Pod pod : pods) {
                res.add(generatePodResPo(pod));
            }
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved all pods");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getClientPods(Long clientId) {

        List<Pod> pods = podRepository.getPodsByClientId(clientId);
        List<PodBasicResPo> res = new ArrayList<>();
        if (pods != null) {
            for (Pod pod : pods) {
                res.add(generatePodResPo(pod));
            }
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved pods for client");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getClientAdminPods(Long clientAdminId) {

        List<Pod> pods = podRepository.getPodsByClientAdminId(clientAdminId);
        List<PodBasicResPo> res = new ArrayList<>();
        if (pods != null) {
            for (Pod pod : pods) {
                res.add(generatePodResPo(pod));
            }
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved pods for client admin");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getClientAdminLicensedPods(Long clientAdminId) {

        List<Pod> pods = podRepository.getPodsByClientAdminId(clientAdminId);
        Date currentDate = new Date(System.currentTimeMillis());
        List<PodBasicResPo> res = new ArrayList<>();
        if (pods != null) {
            for (Pod pod : pods) {
                if(currentDate.before(pod.getLicense().getEffectiveEndDate())) {
                    res.add(generatePodResPo(pod));
                }
            }
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved licensed pods for client admin");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getPodsWithDetails() {
        List<Pod> pods = podRepository.findByOrderByPodIdAsc();
        List<PodResPo> res = new ArrayList<>();
        if (pods != null) {
            for (Pod pod : pods) {
                res.add(generatePodDetailsResPo(pod));
            }
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved all pods with details");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getClientPodsWithDetails(Long clientId) {
        List<Pod> pods = podRepository.getPodsByClientId(clientId);
        List<PodResPo> res = new ArrayList<>();
        if (pods != null) {
            for (Pod pod : pods) {
                res.add(generatePodDetailsResPo(pod));
            }
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved all client pods with details");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getClientAdminPodsWithDetails(Long clientAdminId) {
        List<Pod> pods = podRepository.getPodsByClientAdminId(clientAdminId);
        List<PodResPo> res = new ArrayList<>();
        if (pods != null) {
            for (Pod pod : pods) {
                res.add(generatePodDetailsResPo(pod));
            }
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved all clientadmin pods with details");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getPodById(Long podId) {
        try {
            Pod pod = super.getEntityById(podRepository, podId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get pod with id " + podId);
                setPayload(generatePodDetailsResPo(pod));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Pod with id " + podId + " is not found");
                setPayload(ex);
            }};
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo updatePodById(Long podId, PodCreationReqPo podCreationReqPo) {
        try {
            Pod p = podRepository.findById(podId).get();
            if (podCreationReqPo.getPodName() != null && podCreationReqPo.getPodName().length() > 0) {
                p.setPodName(podCreationReqPo.getPodName());
                p.setTablespaceSize(podCreationReqPo.getTablespaceSize());
            }
            if (podCreationReqPo.getLicenseId() != null && podCreationReqPo.getLicenseId() != p.getLicenseId()) {
                checkPodLimit(podCreationReqPo);
                License license = new License();
                license.setLicenseId(podCreationReqPo.getLicenseId());
                p.setLicense(license);
            }
            if(StringUtils.isNotBlank(podCreationReqPo.getScheduledJobFlag()))
                p.setScheduledJobFlag(podCreationReqPo.getScheduledJobFlag());
            Pod updatedEntity = super.updateEntity(podRepository, p);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully updated pod " + updatedEntity.getPodName());
                setPayload(generatePodDetailsResPo(updatedEntity));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Pod with id " + podId + " is not found");
                setPayload(ex);
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("Pod name " + podCreationReqPo.getPodName() + " is already available. It should be unique.");
                setPayload(ex);
            }};
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo deletePodById(Long podId) {
        try {
            Pod pod = super.getEntityById(podRepository, podId);
            log.info("Retrieved POD: {}", pod.getPodDbUser());
            String podName = pod.getPodDbUser();

            // Drop the POD in Oracle
            deletePod(podName);
            // Verify if POD is deleted in Oracle

            // Cleanup in PostgreSQL
            try {
                log.info("Cleaning up PostgreSQL for POD ID: {}", podId);
                podRepository.deletePodClientAdminLinks(podId);
                sqlExecutionLogRepository.deleteSqlExecutionLogByPodId(podId);
                podRepository.deletePodInformationById(podId);
                podRepository.deletePodRoleObjectLinks(podId);
                podRepository.deletePodRoleUserLinks(podId);
                podRepository.deletePodRoles(podId);
                podRepository.deletePodCredentialObjectLinks(podId);
                podRepository.deletePodCredentials(podId);
                podRepository.deletePodProjectObjectLinks(podId);
                podRepository.deletePodProjects(podId);
                log.info("Successfully deleted POD with name: {}", pod.getPodName());
                return new BasicResPo() {{
                    setStatusCode(HttpStatus.OK);
                    setStatus("success");
                    setMessage("Successfully deleted pod with name " + pod.getPodName());
                    setPayload(null);
                }};
            } catch (Exception ex) {
                log.error("PostgreSQL cleanup failed for POD ID: {}", podId, ex);
                return new BasicResPo() {{
                    setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                    setStatus("error");
                    setMessage(ex.getMessage());
                    setPayload(null);
                }};
            }
        } catch (CRNotFoundException ex) {
            log.error("Pod not found: {}", ex.getMessage(), ex);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(null);
            }};
        } catch (Exception ex) {
            log.error("Unexpected error occurred while deleting POD: {}", podId, ex);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(null);
            }};
        }
    }


    // Method to delete POD in Oracle
    private void deletePod(String podName) {
        String dropUserQuery = "DROP USER " + podName + " CASCADE";
        String dropTablespaceQuery = "DROP TABLESPACE " + podName + " INCLUDING CONTENTS AND DATAFILES";
        try (Connection con = dataSourceUtil.createOracleConnection();
             Statement stmt = con.createStatement()) {
            con.setAutoCommit(false);
            stmt.addBatch(dropUserQuery);
            stmt.addBatch(dropTablespaceQuery);
            stmt.executeBatch();
            con.commit();
            log.info("POD dropped successfully: {}", podName);
        } catch (SQLException ex) {
            log.error("SQL Exception while dropping POD: {}", podName, ex);
            String errorMessage = "Session is active,Please close the session before deleting the pod" ;
            throw new RuntimeException(errorMessage);
        } catch (Exception e) {
            log.error("Error in Delete Pod Method ", podName, e);
            throw new RuntimeException(e);
        }
    }

    @Override
    public BasicResPo getPodModulesByPodId(Long podId) {
        try {
            Pod pod = super.getEntityById(podRepository, podId);
            List<String> modules = new ArrayList<>();
            pod.getLicense().getObjects().forEach(crObject -> {
                if (!modules.contains(crObject.getModuleCode())) {
                    modules.add(crObject.getModuleCode());
                }
            });
            List<Module> allModules = moduleRepository.findAll();
            List<ModuleWithObjectsResPo> res = new ArrayList<>();
            allModules.forEach(module -> {
                String moduleCode = module.getModuleCode();
                if (modules.contains(moduleCode)) {
                    ModuleWithObjectsResPo moduleWithObjectsResPo = new ModuleWithObjectsResPo();
                    moduleWithObjectsResPo.setModuleId(module.getModuleId());
                    moduleWithObjectsResPo.setModuleName(module.getModuleName());
                    moduleWithObjectsResPo.setModuleCode(moduleCode);
                    List<ObjectBasicResPo> objectBasicResPos = new ArrayList<>();
                    pod.getLicense().getObjects().forEach(crObject -> {
                        if (moduleCode.equals(crObject.getModuleCode())) {
                            ObjectBasicResPo objectBasicResPo = new ObjectBasicResPo();
                            objectBasicResPo.setObjectId(crObject.getObjectId());
                            objectBasicResPo.setObjectCode(crObject.getObjectCode());
                            objectBasicResPo.setObjectName(crObject.getObjectName());
                            objectBasicResPos.add(objectBasicResPo);
                        }
                    });
                    moduleWithObjectsResPo.setCrObjects(objectBasicResPos);
                    res.add(moduleWithObjectsResPo);
                }
            });
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get pod modules with id " + podId);
                setPayload(res);
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Pod with id " + podId + " is not found");
                setPayload(ex);
            }};
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo getPodObjectsByPodId(Long podId, String moduleCode) {
        try {
            List<CRObject> res;
            Pod pod = super.getEntityById(podRepository, podId);
            if (moduleCode != null && moduleCode.length() > 0) {
                res = pod.getLicense().getObjects().stream().filter(crobject -> moduleCode.equals(crobject.getModuleCode())).toList();
            } else {
                res = pod.getLicense().getObjects().stream().toList();
            }
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully got pod objects with pod id " + podId);
                setPayload(res);
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Pod with id " + podId + " is not found");
                setPayload(ex);
            }};
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    private void checkPodLimit(PodCreationReqPo podCreationReqPo) throws Exception {
        Long existingPodCount = podRepository.getExistingPodCountWithLicenseId(podCreationReqPo.getLicenseId());
        License license = licenseRepository.findById(podCreationReqPo.getLicenseId()).get();
        if (license.getPodLimit() <= existingPodCount) {
            throw new CRAdminException("Existing pods already reached pod limit : " + license.getPodLimit());
        }
    }

    private void createPod(String dbUserName, String dbUserPassword, String tablespaceSize) throws Exception {
        try {
            Connection con = dataSourceUtil.createOracleConnection();
            con.setAutoCommit(false);
            Statement stmt = con.createStatement();
            stmt.addBatch("CREATE USER " + dbUserName + " IDENTIFIED BY " + dbUserPassword);
            stmt.addBatch("GRANT CREATE SESSION TO " + dbUserName);
            stmt.addBatch("CREATE TABLESPACE " + dbUserName + " DATAFILE SIZE " + tablespaceSize + " AUTOEXTEND ON NEXT 5G" + " MAXSIZE UNLIMITED");
            stmt.addBatch("ALTER USER " + dbUserName + " QUOTA UNLIMITED ON " + dbUserName);
            stmt.addBatch("ALTER USER " + dbUserName + " default TABLESPACE " + dbUserName);
            stmt.addBatch("GRANT READ, WRITE ON DIRECTORY data_pump_dir TO " + dbUserName);
            stmt.addBatch("ALTER USER " + dbUserName + " default TABLESPACE " + dbUserName);
            stmt.addBatch("GRANT connect TO " + dbUserName);
            stmt.addBatch("GRANT resource TO " + dbUserName);
            stmt.addBatch("GRANT CREATE JOB TO " + dbUserName);
            stmt.addBatch("GRANT CREATE ANY VIEW TO " + dbUserName);
            stmt.addBatch("GRANT ALTER ANY TABLE TO " + dbUserName);
            stmt.addBatch("GRANT CREATE ANY TABLE TO " + dbUserName);
            stmt.addBatch("GRANT UNLIMITED TABLESPACE TO " + dbUserName);
            stmt.addBatch("GRANT EXECUTE ON sys.dbms_scheduler TO " + dbUserName);
            stmt.addBatch("GRANT READ,WRITE, EXECUTE ON DIRECTORY G2N_TAB_MAIN TO " + dbUserName);
            stmt.addBatch("GRANT DROP PUBLIC DATABASE LINK TO " + dbUserName);
            stmt.addBatch("GRANT CREATE PUBLIC DATABASE LINK TO " + dbUserName);

            //stmt.addBatch("GRANT EXECUTE ON sys.sys_plsql_faa5f685_2385_1 TO "+dbUserName+" WITH GRANT OPTION");
            //stmt.addBatch("GRANT EXECUTE ON sys.sys_plsql_d9b1149d_9_1 TO "+dbUserName+" WITH GRANT OPTION");
            stmt.executeBatch();
            con.commit();
        } catch (Exception ex) {
            if (ex.getMessage().startsWith("error occurred during batching: ORA-01920: user name")) {
                throw new CRUniquenessException(ex.getMessage(), ex);
            }
            throw ex;
        }
    }

     private PodBasicResPo generatePodResPo(Pod pod) {
        PodBasicResPo res = new PodBasicResPo();
        res.setPodId(pod.getPodId());
        res.setPodName(pod.getPodName());
        return res;
    }

    private PodResPo generatePodDetailsResPo(Pod pod) {
        PodResPo res = new PodResPo();
        res.setPodId(pod.getPodId());
        res.setPodName(pod.getPodName());
        res.setDatabaseUserName(pod.getPodDbUser());
        res.setDatabasePassword(pod.getPodDbPassword());
        res.setTablespaceSize(pod.getTablespaceSize());
        res.setScheduledJobFlag(pod.getScheduledJobFlag());
        ClientResPo client = new ClientResPo();
        if (pod.getClient() != null) {
            client.setClientId(pod.getClient().getClientId());
            client.setClientName(pod.getClient().getClientName());
        }
        res.setClient(client);
        LicenseResPo license = new LicenseResPo();
        license.setLicenseId(pod.getLicense().getLicenseId());
        license.setLicenseKey(pod.getLicense().getLicenseKey());
        res.setLicense(license);
        return res;
    }

    private void loadSchema(Connection con) throws IOException {
        //Load schema for multiple sql files from resources/schema
        ResourcePatternResolver resourcePatResolver = new PathMatchingResourcePatternResolver();
        Resource[] AllResources = resourcePatResolver.getResources("classpath*:schema/*.sql");
        List<Resource> sortedList = Arrays.stream(AllResources).sorted((o1, o2)->o1.getFilename().
                compareTo(o2.getFilename())).toList();
        for(Resource resource: sortedList) {
            InputStream inputStream = resource.getInputStream();
            BufferedReader br = new BufferedReader(new InputStreamReader(inputStream, StandardCharsets.UTF_8)) ;
            ScriptRunner sr = new ScriptRunner(con);
            sr.setStopOnError(true);
            sr.setDelimiter("$#$");
            sr.runScript(br);
        }


    }




    @Override
    public BasicResPo executeSqlOnPods( String sqlFilePath) {
        boolean success = true;
        log.info("Executing sql on all pods");
        List<Long> clientIds = podRepository.findAllUniqueClientIds();
        log.info("Found {} unique client ids", clientIds.size());
        for (Long clientId : clientIds) {
            log.info("Executing sql on pods for client {}", clientId);
            BasicResPo res = executeSqlOnPods(clientId, sqlFilePath);
            if(!res.getStatusCode().equals(HttpStatus.OK)) {
                success = false;
            }
        }
        log.info("Finished executing sql on all pods with success status as {}", success);
        return success ?
                createSuccessResponse("SQL executed successfully on all applicable pods")
                : createErrorResponse(HttpStatus.INTERNAL_SERVER_ERROR, "Error executing SQL on all pods");
    }

    @Override
    public BasicResPo executeSqlOnPods(Long clientId, String sqlFilePath) {
        log.info("Executing sql on pods for client {}", clientId);
        try {

            performValidations(clientId, sqlFilePath);


            List<Pod> pods = podRepository.getPodsByClientId(clientId);
            String errorMessages = "";

            for (Pod pod : pods) {
                errorMessages+= applySqlVersionsForSinglePod(clientId, sqlFilePath, pod);

            }

            if (!errorMessages.isEmpty()) {
                return createErrorResponse(HttpStatus.INTERNAL_SERVER_ERROR, errorMessages);
            }
            return createSuccessResponse("SQL executed successfully on all applicable pods");

        } catch (Exception e) {
            return createErrorResponse(HttpStatus.INTERNAL_SERVER_ERROR, "Error executing SQL: " + e.getMessage());
        }
    }

    private String applySqlVersionsForSinglePod(Long clientId, String sqlFilePath, Pod pod) throws IOException, URISyntaxException {
        log.info("Applying sql versions for single pod ID {}", pod.getPodId());
        String errorMessages = "";
        Map<Long, String> podLatestVersionMap = getLatestSuccessfulVersionsPerPod(clientId);
        String lastSuccessfulVersion = podLatestVersionMap.getOrDefault(pod.getPodId(), "0.0");
        List<String> versionsToApply = getVersionsToApply(lastSuccessfulVersion, sqlFilePath);

        for (String version : versionsToApply) {
            String versionPath = constructVersionPath(version);
            List<String> sqlContents = validateSqlFilesInDirectory(clientId, pod.getPodId(),versionPath);
            String rollbackSqlFilePath = sqlFilePath.endsWith("/") ? sqlFilePath + "rollback.sql" : sqlFilePath + "/rollback.sql";
            String rollbackSql  = getRollbackSqlContent(rollbackSqlFilePath);

            try {
                BasicResPo podResult = executeSqlOnPodForAllFiles(pod, sqlContents,rollbackSql);
                if (podResult.getStatusCode() != HttpStatus.OK) {
                    errorMessages += "Error executing SQL on pod " + pod.getPodId() + ": " + podResult.getMessage() + "\n";
                    log.error("Error executing SQL on pod ID {}: {}", pod.getPodId(), podResult.getMessage());
                    saveExecutionLog(clientId, pod.getPodId(), versionPath, Boolean.FALSE);
                    break ; // Exit the inner loop and continue with the next pod
                }
            } catch (Exception e) {
                log.error("Exception caught while executing SQL on pod ID {}: {}", pod.getPodId(), e.getMessage());
                errorMessages += "Error executing SQL on pod " + pod.getPodId() + ": " + e.getMessage() + "\n";
                saveExecutionLog(clientId, pod.getPodId(), versionPath, Boolean.FALSE);
                break; // Move to the next pod
            }

            saveExecutionLog(clientId, pod.getPodId(), versionPath, Boolean.TRUE);
        }
        return errorMessages;
    }

    private String getRollbackSqlContent(String rollbackSqlFilePath) {
        log.info("Reading rollback sql file: " + rollbackSqlFilePath);
        try {
            ResourcePatternResolver resolver = new PathMatchingResourcePatternResolver();

            Resource[] resources = resolver.getResources(rollbackSqlFilePath);

            return new String(resources[0].getInputStream().readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            log.error("Error reading rollback sql file: {}", rollbackSqlFilePath, e);
            throw new CRAdminException("Error reading rollback sql file: " + rollbackSqlFilePath, e);
        }
    }

    private void performValidations(Long clientId, String sqlFilePath) throws IOException {
        if(!isValidClientId(clientId)){
            log.info("Invalid client id: " + clientId);
            throw new IllegalArgumentException("Invalid client id: " + clientId);
        }


        if(!isValidDirectory(sqlFilePath)){
            log.info("Invalid version directory path: " + sqlFilePath);
            throw new IllegalArgumentException("Invalid version directory path: " + sqlFilePath);
        }


        if(!isValidVersion(clientId, Double.parseDouble(extractVersionFromPath(sqlFilePath)))){
            log.info("Invalid version. Version in the request is lesser than the recorded minimum version in the database " + sqlFilePath);
            throw new IllegalArgumentException("Invalid version. Version in the request is lesser than the recorded minimum version in the database " + sqlFilePath);
        }


    }

    private boolean isValidVersion(Long clientId, double version) {
        List<String> versionList = sqlExecutionLogRepository.findSuccessfulSqlFilePathsByClientId(clientId);
        if(versionList.isEmpty()){
            return true;
        }
        double latestVersion = Double.parseDouble(extractVersionFromPath(versionList.get(0)));
        return  version >= latestVersion;
    }

    private boolean isValidClientId(Long clientId) {
        return podRepository.getPodsByClientId(clientId).size() > 0;
    }

    private boolean isValidDirectory(String path) throws IOException {
        log.info("Checking if path is a valid directory");
        try{
            return new PathMatchingResourcePatternResolver().getResources(path.endsWith("/") ? path + "*.sql" : path+"/*.sql").length > 0;
        }
        catch(Exception e){
            return false;
        }

    }

    private BasicResPo executeSqlOnPodForAllFiles(Pod pod, List<String> sqlContents, String rollbackSql) throws Exception {
        log.info("Executing SQL on pod ID {}", pod.getPodId());
        Connection connection = null;
        try {
            connection = DriverManager.getConnection(pod.getPodTargetUrl(), pod.getPodDbUser(), pod.getPodDbPassword());
            connection.setAutoCommit(false);

            for (String sqlContent : sqlContents) {
                runSqlScript(sqlContent, connection);
            }

            connection.commit();
            log.info("SQL executed successfully on pod ID {}", pod.getPodId());
            return createSuccessResponse("SQL executed successfully on pod " + pod.getPodId());
        } catch (Exception e) {
            log.error("In Error executing SQL on pod ID {}: {}", pod.getPodId(), e.getMessage());
            String exceptionMessage = e.getMessage();
            if (connection != null) {
                try {
                    runSqlScript(rollbackSql, connection);// Run rollback sql on error
                    log.error("Rollback success on pod ID {}", pod.getPodId());
                } catch (Exception ex) {
                    exceptionMessage+= "Exception performing rollback  " + ex.getMessage();
                    log.error("Exception performing rollback on pod ID {}: {}", pod.getPodId(), ex.getMessage());
                }
            }

            return createErrorResponse(HttpStatus.INTERNAL_SERVER_ERROR, "Error executing SQL on pod " + pod.getPodId() + ": " + exceptionMessage  );
        } finally {
            if (connection != null) {
                try {
                    connection.close(); // Ensure connection is closed
                    log.info("Connection closed successfully on pod ID {}", pod.getPodId());
                } catch (SQLException ex) {
                    log.error("Error closing database connection on pod ID {}: {}", pod.getPodId(), ex.getMessage());
                }
            }
        }
    }

    private static void runSqlScript(String sqlContent, Connection connection) {
        log.info("Running SQL script: {}", sqlContent);
        ScriptRunner runner = new ScriptRunner(connection);
        runner.setDelimiter("$#$");
        runner.setStopOnError(true);
        runner.runScript(new BufferedReader(new StringReader(sqlContent)));
    }

    private Map<Long, String> getLatestSuccessfulVersionsPerPod(Long clientId) {
        try {
            log.info("Fetching latest successful versions per pod for client id: {}", clientId);
            Map<Long, String> latestVersionsPerPod = new HashMap<>();
            List<Object[]> latestTimestamps = sqlExecutionLogRepository.findLatestTimestampsPerPodByClientId(clientId);

            for (Object[] result : latestTimestamps) {

                Long podId = ((Number) result[0]).longValue();
                Timestamp latestTimestamp = (Timestamp) result[1];

                SqlExecutionLog latestLog = sqlExecutionLogRepository.findFirstByPodIdAndClientIdAndCreatedTime(podId, clientId, latestTimestamp);
                if (latestLog != null) {
                    String version = extractVersionFromPath(latestLog.getSqlFilePath());
                    latestVersionsPerPod.put(podId, version);
                }
            }
            return latestVersionsPerPod;
        }
        catch (Exception e) {
            log.error("Error fetching latest successful versions per pod for client id {}: {}", clientId, e.getMessage());
            throw new CRAdminException("Error fetching latest successful versions per pod for client id " + clientId, e);
        }
    }

    private String extractVersionFromPath(String sqlFilePath) {
        String[] parts = sqlFilePath.split("/");
        // Assuming the version is the second element in the path (e.g., "schema/upgrade/1.0/")
        return parts.length > 2 ? parts[2] : "0.0";
    }

    private List<Resource> getResourcesFromPath(String path) throws IOException {
        log.info("Validating SQL files in the path: {}",  path);
        ResourcePatternResolver resolver = new PathMatchingResourcePatternResolver();
        Resource[] resources = resolver.getResources(path.endsWith("/") ? path + "*.sql" : path+"/*.sql");

        if (resources.length == 0) {
            log.info("No SQL files found in the path: {}", path);
            throw new IllegalArgumentException("SQL  directory does not exist or no SQL files found" + path);
        }

        List<Resource> sortedList = Arrays.stream(resources).sorted((o1, o2) -> o1.getFilename().
                compareTo(o2.getFilename())).toList();
        return sortedList;
    }

    private List<String> getSqlContentFromResources(List<Resource> resourceList) throws IOException {
        List<String> sqlContents = new ArrayList<>();
        for (Resource resource : resourceList) {
            sqlContents.add(new String(resource.getInputStream().readAllBytes(), StandardCharsets.UTF_8));
        }
        return sqlContents;
    }

    private List<String> validateSqlFilesInDirectory(long clientId, long podId, String path) throws IOException {

        boolean rollbackFileFound = false;
        List<Resource> sortedList = null;
        List<String> sqlContents = new ArrayList<>();

        try{
              sortedList =   getResourcesFromPath(path);
        }
        catch(Exception ex){
              saveExecutionLog(clientId, podId, path, Boolean.FALSE);
              throw new RuntimeException(ex);
        }
        for (Resource resource : sortedList) {
            String sqlContent = new String(resource.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
            if (resource.isReadable()) {
                if(resource.getFilename().equals("rollback.sql")){
                    rollbackFileFound = true;
                }
                if ( isValidSql(sqlContent,resource.getFilename() )  ) {
                    if(!resource.getFilename().equals("rollback.sql") ){
                        sqlContents.add(sqlContent);
                    }
                    log.info("SQL content validated successfully for the resource {}", path+ resource.getFilename());
                }
                else {
                    log.info("SQL content validation failed for the resource {}", path+ resource.getFilename());
                    saveExecutionLog(clientId, podId, path, Boolean.FALSE);
                    throw new IllegalArgumentException("SQL content validation failed for the resource " + path+ resource.getFilename());
                }
            }
            else{
                saveExecutionLog(clientId, podId, path, Boolean.FALSE);
                throw new IllegalArgumentException("SQL file or directory is not readable"+ path);
            }
        }
        if(!rollbackFileFound){
            log.info("No rollback.sql file found in the path: {} ", path);
            saveExecutionLog(clientId, podId, path, Boolean.FALSE);
            throw new CRAdminException("No rollback.sql file found in the path: " + path);
        }
        return sqlContents;
    }

    private boolean isValidSql(String sqlContent, String fileName) {
        if (fileName.toUpperCase().equals("ROLLBACK.SQL")) {
            return !sqlContent.isEmpty();
        }

        if (sqlContent.isEmpty()) {
            return false;
        }

        if(!fileName.toUpperCase().contains("TABLE")){
            return true;
        }

        Matcher matcher = FORBIDDEN_PATTERNS.matcher(sqlContent);
        boolean containsForbiddenPatterns = matcher.find();

        return !(containsForbiddenPatterns ||
                sqlContent.matches("(?i).*ALTER\\s+TABLE.*ADD.*NOT\\s+NULL.*"));
    }
    private List<String> getVersionsToApply(String lastSuccessfulVersion, String requestedVersionPath) throws IOException, URISyntaxException {
        log.info("Getting versions to apply for pod with last successful version: {} and requested version path: {}", lastSuccessfulVersion, requestedVersionPath);
        // Split the requestedVersionPath to get the requested version number
        String[] requestedPathParts = requestedVersionPath.split("/");
        String requestedVersion = requestedPathParts[requestedPathParts.length - 1];

        // Initialize the list to collect the versions to apply
        List<String> versionsToApply = new ArrayList<>();

        // Handle the case where there is no last successful version (it's either null or not found)
        if (lastSuccessfulVersion == null || lastSuccessfulVersion.isEmpty()) {
            lastSuccessfulVersion = "0.0"; // Assume starting from the beginning if no successful version is found
        }

        // Convert versions to numerical values for comparison
        double lastSuccessfulVersionNum = Double.parseDouble(lastSuccessfulVersion);
        double requestedVersionNum = Double.parseDouble(requestedVersion);

        // Assuming version folders are named as simple numerical versions like "1.0", "2.0", etc.
        // List and sort all available versions from the upgrade directory
        List<Double> availableVersions = getAllAvailableVersions();
        // Filter and add the versions that are between the last successful and the requested versions
        for (Double version : availableVersions) {
            if (version > lastSuccessfulVersionNum && version <= requestedVersionNum) {
                versionsToApply.add(String.format("%.1f", version));
            }
        }
        return versionsToApply;
    }

    private String constructVersionPath(String version) {
        log.info("Constructing version path for version: {} ", version);
        return schemaUpgradeBasePath + version + "/";
    }

    private List<Double> getAllAvailableVersions() throws IOException, URISyntaxException {
        try {
            log.info("Getting all available versions in the path: {} ", schemaUpgradeBasePath);
            Set<Double> availableVersions = new TreeSet<>();
            ResourcePatternResolver resourcePatResolver = new PathMatchingResourcePatternResolver();
            Resource[] AllResources = resourcePatResolver.getResources("classpath*:"+schemaUpgradeBasePath+"*/");
            List<Resource> sortedList = Arrays.stream(AllResources).sorted((o1, o2) -> o1.getFilename().
                    compareTo(o2.getFilename())).toList();
            for (Resource resource : sortedList) {
                String resourcePath = resource.toString();
                String[] parts = resourcePath.split("/");
                double version = Double.parseDouble(parts[parts.length - 2]);
                log.info("Found versioned directory: {}", version);
                availableVersions.add(version);
            }
            return new ArrayList<>(availableVersions);
        }
        catch (Exception e){
            log.error("Error getting all available versions in the path: {}",  schemaUpgradeBasePath, e);
            throw e;
        }
    }

    private BasicResPo createErrorResponse(HttpStatus status, String message) {
        BasicResPo response = new BasicResPo();
        response.setStatusCode(status);
        response.setStatus("error");
        response.setMessage(message);
        return response;
    }

    private BasicResPo createSuccessResponse(String message, Object payload) {
        BasicResPo response = new BasicResPo();
        response.setStatusCode(HttpStatus.OK);
        response.setStatus("success");
        response.setMessage(message);
        response.setPayload(payload);
        return response;
    }

    private BasicResPo createSuccessResponse(String message) {
        return createSuccessResponse(message, null);
    }

    private void saveExecutionLog(Long clientId, Long podId, String sqlFilePath, Boolean success) {
        SqlExecutionLog log = new SqlExecutionLog();
        log.setClientId(clientId);
        log.setPodId(podId);
        log.setSqlFilePath(sqlFilePath);
        log.setCreatedTime(new java.util.Date());
        log.setSuccess(success);
        sqlExecutionLogRepository.save(log);
    }
}