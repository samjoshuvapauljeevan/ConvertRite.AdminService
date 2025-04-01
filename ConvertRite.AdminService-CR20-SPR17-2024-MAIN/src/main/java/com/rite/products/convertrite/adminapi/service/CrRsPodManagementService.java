package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.exception.CRAdminException;
import com.rite.products.convertrite.adminapi.exception.CRUniquenessException;
import com.rite.products.convertrite.adminapi.model.*;
import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.CrRsPodCreationReqPo;
import com.rite.products.convertrite.adminapi.respository.CRClientLicenseLinksRepository;

import com.rite.products.convertrite.adminapi.respository.CrRsPodInformationRepo;
import com.rite.products.convertrite.adminapi.respository.CrRsPodInformationRepo1;
import com.rite.products.convertrite.adminapi.respository.LicenseRepository;
import com.rite.products.convertrite.adminapi.utils.DataSourceUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

import static com.rite.products.convertrite.adminapi.utils.Constants.VALID_DATABASE_NAME_REGEXP;

@Service
@Slf4j
public class CrRsPodManagementService {
    @Autowired
    CrRsPodInformationRepo crRsPodInformationRepo;
    @Autowired
    CrRsPodInformationRepo1 crRsPodInformationRepo1;
    @Autowired
    LicenseRepository licenseRepository;
    @Autowired
    DataSourceUtil dataSourceUtil;
    @Autowired
    CRClientLicenseLinksRepository cRClientLicenseLinksRepository;
    @Value("${oracle.datasource.url}")
    private String url;

    public BasicResPo createPod(CrRsPodCreationReqPo req) {
        boolean isOracleUserCreated = false;
        CrRsPodInformation crRsPodInformation = null;
        String podDbUserName = req.getDatabaseUserName();
        try {
            CRClientLicenseLinks cRClientLicenseLinks = cRClientLicenseLinksRepository.findByClientId(req.getClientId());
            if (cRClientLicenseLinks != null) {
                checkPodLimit(cRClientLicenseLinks.getLicenseId());
            }
            // Verify podName string to prevent SQL injection
            if (!podDbUserName.matches(VALID_DATABASE_NAME_REGEXP)) {
                throw new CRAdminException("Invalid pod username: " + podDbUserName);
            }
            createPod(podDbUserName, req.getDatabasePassword(), req.getTablespaceSize());
            isOracleUserCreated = true;
            CrRsPodInformation p = new CrRsPodInformation();
            p.setPodName(req.getPodName());
            p.setPodDbUser(podDbUserName);
            p.setPodDbPassword(req.getDatabasePassword());
            p.setPodTargetUrl(url);
            p.setTablespaceSize(req.getTablespaceSize());
            if (req.getClientId() != null) {
                Client client = new Client();
                client.setClientId(req.getClientId());
                p.setClient(client);
                if (cRClientLicenseLinks != null) {
                    p.setLicenseId(cRClientLicenseLinks.getLicenseId());
                    if (cRClientLicenseLinks.getLicenseId() != null) {
                        License license = new License();
                        license.setLicenseId(cRClientLicenseLinks.getLicenseId());
                        p.setLicense(license);
                    }
                }
            }
            p.setLastUpdatedBy("ConvertRiteAdmin");
            p.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
            p.setCreationDate(new java.sql.Date(new java.util.Date().getTime()));
            p.setCreatedBy("ConvertRiteAdmin");
            crRsPodInformation = crRsPodInformationRepo.save(p);

        } catch (CRUniquenessException ex) {
            String errorMessage = "Pod name " + req.getPodName() + " is already available. It should be unique.";
            if (isOracleUserCreated) {
                try {
                    deletePod(podDbUserName);
                } catch (Exception e) {
                    //throw new RuntimeException(e);
                }
            } else {
                errorMessage = "Database User " + req.getDatabaseUserName() + " is already available. It should be unique.";
            }
            String finalErrorMessage = errorMessage;
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage(finalErrorMessage);
                setPayload(ex);
            }};
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
        CrRsPodInformation finalCrRsPodInformation = crRsPodInformation;
        return new BasicResPo() {{
            setStatusCode(HttpStatus.CREATED);
            setStatus("success");
            setMessage("Successfully created pod " + finalCrRsPodInformation.getPodName());
            setPayload(finalCrRsPodInformation);
        }};
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
            // stmt.addBatch("GRANT READ, WRITE ON DIRECTORY data_pump_dir TO " + dbUserName);
            stmt.addBatch("ALTER USER " + dbUserName + " default TABLESPACE " + dbUserName);
            stmt.addBatch("GRANT connect TO " + dbUserName);
            stmt.addBatch("GRANT resource TO " + dbUserName);
            stmt.addBatch("GRANT CREATE JOB TO " + dbUserName);
            // stmt.addBatch("GRANT CREATE ANY VIEW TO " + dbUserName);
            stmt.addBatch("GRANT ALTER ANY TABLE TO " + dbUserName);
            stmt.addBatch("GRANT CREATE ANY TABLE TO " + dbUserName);
            stmt.addBatch("GRANT UNLIMITED TABLESPACE TO " + dbUserName);
            //  stmt.addBatch("GRANT EXECUTE ON sys.dbms_scheduler TO " + dbUserName);
            stmt.addBatch("GRANT READ,WRITE, EXECUTE ON DIRECTORY G2N_TAB_MAIN TO " + dbUserName);
            stmt.addBatch("GRANT DROP PUBLIC DATABASE LINK TO " + dbUserName);
            stmt.addBatch("GRANT CREATE PUBLIC DATABASE LINK TO " + dbUserName);

            stmt.executeBatch();
            con.commit();
        } catch (Exception ex) {
            if (ex.getMessage().startsWith("error occurred during batching: ORA-01920: user name")) {
                throw new CRUniquenessException(ex.getMessage(), ex);
            }
            throw ex;
        }
    }

    private void checkPodLimit(Long licenseId) throws Exception {
        Long existingPodCount = crRsPodInformationRepo.getExistingPodCountWithLicenseId(licenseId);
        License license = licenseRepository.findById(licenseId).get();
        if (license.getPodLimit() <= existingPodCount) {
            throw new CRAdminException("Existing pods already reached pod limit : " + license.getPodLimit());
        }
    }

    // Method to delete POD in Oracle
    public void deletePod(String podName) {
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
            String errorMessage = "Session is active,Please close the session before deleting the pod";
            throw new RuntimeException(errorMessage);
        } catch (Exception e) {
            log.error("Error in Delete Pod Method ", podName, e);
            throw new RuntimeException(e);
        }
    }

    public BasicResPo getPodsInformation(Long clientId) {
        List<CrRsPodInformation1> pods = null;
        try {
            if (clientId != null) {
                CRClientLicenseLinks cRClientLicenseLinks = cRClientLicenseLinksRepository.findByClientId(clientId);
                if (cRClientLicenseLinks != null) {
                    log.info("Fetching pods for client ID: {}", clientId);
                    pods = crRsPodInformationRepo1.findAllByLicenseId(cRClientLicenseLinks.getLicenseId());
                }
            } else {
                log.info("Fetching all pods as client ID is null");
                pods = crRsPodInformationRepo1.findAll();
            }
            log.info("Number of pods retrieved: {}", pods.size());
        } catch (Exception e) {
            log.error("Exception in getPodsInformation: {}", e.getMessage());
            BasicResPo errorResponse = new BasicResPo();
            errorResponse.setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
            errorResponse.setStatus("error");
            errorResponse.setMessage("Error while retrieving pods for client");
            errorResponse.setPayload(null);
            return errorResponse;
        }

        BasicResPo successResponse = new BasicResPo();
        successResponse.setStatusCode(HttpStatus.OK);
        successResponse.setStatus("success");
        successResponse.setMessage("Successfully retrieved pods for client");
        successResponse.setPayload(pods);
        return successResponse;
    }


}
