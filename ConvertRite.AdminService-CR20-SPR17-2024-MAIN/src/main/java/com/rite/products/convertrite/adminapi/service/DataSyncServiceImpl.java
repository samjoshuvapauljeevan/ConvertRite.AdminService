package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.model.CRObject;
import com.rite.products.convertrite.adminapi.model.CrObjectInformation;
import com.rite.products.convertrite.adminapi.model.CRTargetInterfaceColumn;
import com.rite.products.convertrite.adminapi.model.Pod;
import com.rite.products.convertrite.adminapi.model.DataSyncExecutionLog;
import com.rite.products.convertrite.adminapi.respository.CRTargetInterfaceColumnRepository;
import com.rite.products.convertrite.adminapi.respository.DataSyncExecutionLogRepository;
import com.rite.products.convertrite.adminapi.respository.ObjectInformationRepository;
import com.rite.products.convertrite.adminapi.respository.ObjectRepository;
import com.rite.products.convertrite.adminapi.respository.PodRepository;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.sql.*;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;

@Slf4j
@Service
public class DataSyncServiceImpl implements DataSyncService {

    @Autowired
    private PodRepository podRepository;

    @Autowired
    private ObjectRepository objectRepository;

    @Autowired
    private ObjectInformationRepository objectInformationRepository;

    @Autowired
    private CRTargetInterfaceColumnRepository cRTargetInterfaceColumnRepository;

    @Value("${data.sync.target.object.table}")
    String targetObjectTable;

    @Value("${data.sync.target.object.info.table}")
    String targetObjectInfoTable;

    @Value("${data.sync.target.object.interface.table}")
    String targetInterfaceColumnTable;

    @Value("${data.sync.enable}")
    boolean enableDataSync;

    @Autowired
    DataSyncExecutionLogRepository dataSyncRepository;

    @Scheduled(cron = "${data.sync.cron}") // use fixedDelay = 10000000 for local/dev testing
    @Async
    public void performFullDataSyncToAllPods() {
        log.info("Running the cron job to sync data to pods");
        if (!enableDataSync) {
            log.info("In performFullDataSyncToAllPods(), Data sync is disabled");
            return;
        }
        try {
            log.info("Fetching data from database");
            List<CRObject> objects = objectRepository.findAll();
            List<CrObjectInformation> objectInformation = objectInformationRepository.findAll();
            List<CRTargetInterfaceColumn> targetInterfaceColumns = cRTargetInterfaceColumnRepository.findAll();
            List<Pod> pods = podRepository.findAll();
            log.info("Fetching data from database completed");
            for (Pod pod : pods) {
                try {
                    boolean objectsSuccess = syncObjectDataToSinglePod(objects, Operation.INSERT, pod, true);
                    if (objectsSuccess) {
                        log.info("Data sync of objects to pod ID: {}  completed successfully", pod.getPodId());
                    } else {
                        log.info("Data sync of objects to pod ID: {} failed", pod.getPodId());
                    }
                } catch (Exception e) {
                    log.error("Data sync of objects to pod ID: {} failed ", pod.getPodId(), e);
                }
                try {
                    boolean objectInfoSuccess = syncObjectInfoDataToSinglePod(objectInformation, Operation.INSERT, pod);
                    if(objectInfoSuccess){
                        log.info("Data sync of object information to pod ID: {}  completed successfully", pod.getPodId());
                    } else {
                        log.info("Data sync of object information to pod ID: {}  failed", pod.getPodId());
                    }
                } catch (Exception e) {
                    log.error("Data sync of object information to pod ID: {} failed ", pod.getPodId(), e);
                }
                try {
                    boolean interfaceColumnSuccess = syncTargetInterfaceColumnToSinglePod(targetInterfaceColumns, pod);
                    if(interfaceColumnSuccess){
                        log.info("Data sync of Target Interface Column to pod ID: {} completed successfully", pod.getPodId());
                    } else {
                        log.info("Data sync of Target Interface Column to pod ID: {}  failed", pod.getPodId());
                    }
                } catch (Exception e) {
                    log.error("Data sync of Target Interface Column to pod ID: {} failed ", pod.getPodId(), e);
                }
            }
        }
        catch (Exception e) {
            log.error("Error in the cron syncing data to pods ", e);
        }
    }

    @Async
    @Override
    public CompletableFuture<Boolean> syncObjectDataToAllPods(List<CRObject> objects, DataSyncService.Operation operation, boolean truncateTargetTable) {
        log.info("Syncing object data to all pods");
        if (!enableDataSync) {
            log.info("In syncObjectDataToAllPods, Data sync is disabled");
            return CompletableFuture.completedFuture(true);
        }
        if(objects.isEmpty()){
            log.info("In syncObjectDataToAllPods, No objects to sync");
            return CompletableFuture.completedFuture(true);
        }

        boolean allSuccess = true;
        List<Pod> pods = podRepository.findAll();
        for (Pod pod : pods) {
            try {
                syncObjectDataToSinglePod(objects, operation, pod, truncateTargetTable);
            } catch (Exception e) {
                log.error("Error in syncing data to pod in method syncObjectDataToAllPods : {} ", pod.getPodId(), e);
                allSuccess = false;
            }
        }
        return CompletableFuture.completedFuture(allSuccess);
    }

    @Override
    public boolean syncObjectDataToSinglePod(List<CRObject> objects, Operation operation, Pod pod, boolean truncateTargetTable) throws SQLException {
        boolean success = true;

        if (!enableDataSync) {
            log.info("In syncObjectDataToSinglePod, Data sync is disabled");
            return true;
        }
        // return true objects list is empty
        if(objects.isEmpty()){
            log.info("No objects to sync");
            return true;
        }
        log.info("In syncObjectDataToSinglePod, Syncing object data to pod ID: {} ", pod.getPodId());
        Connection conn = null;
        try {
            log.info("In syncObjectDataToSinglePod, Creating db connection tp pod Id : {} ", pod.getPodId());
            conn = DriverManager.getConnection(pod.getPodTargetUrl(), pod.getPodDbUser(), pod.getPodDbPassword());
            conn.setAutoCommit(false);

            if(truncateTargetTable){
                truncateTargetTables(conn);
            }

            switch (operation) {
                case INSERT:
                    log.info("Inserting objects to pod Id : {} ", pod.getPodId());
                    insertObjects(conn, objects);
                    break;
                case UPDATE:
                    log.info("Updating objects to pod Id :  {} ", pod.getPodId());
                    updateObjects(conn, objects);
                    break;
                case DELETE:
                    log.info("Deleting objects to pod Id : {} ", pod.getPodId());
                    deleteObjects(conn, objects);
                    break;
            }
            conn.commit();
            log.info("Transaction committed for Objects");
            saveDataSyncExecutionLog(pod.getClient().getClientId(), pod.getPodId(), targetObjectTable, success, null);
            log.info("Saved data sync execution log for Objects successfully");
        } catch (Exception e) {
            log.error("Error during data sync for pod ID: {} ", pod.getPodId(), e);
            success = false;
            saveDataSyncExecutionLog(pod.getClient().getClientId(), pod.getPodId(), targetObjectTable, success, e.getMessage());
            log.info("In Exception, Saved data sync execution log for Objects successfully");
            try {
                if (conn != null &&  !conn.isClosed()) {
                    conn.rollback();
                    log.info("Transaction rolled back");
                }
            } catch (SQLException sqlException) {
                log.error("Error rolling back transaction", sqlException);
                throw sqlException;
            }
        } finally {
            try {
                if (conn != null) {
                    conn.close();
                    log.info("Connection closed");
                }
            } catch (Exception e) {
                log.error("Error closing connection", e);
            }
            return success;
        }
    }

    @Async
    @Override
    public CompletableFuture<Boolean> syncObjectInfoDataToAllPods(List<CrObjectInformation> objectsInfo, DataSyncService.Operation operation) {
        log.info("Syncing object information data to all pods");
        if (!enableDataSync) {
            log.info("Data sync is disabled");
            return CompletableFuture.completedFuture(true);
        }
        if(objectsInfo.isEmpty()){
            log.info("No objects Info data to sync");
            return CompletableFuture.completedFuture(true);
        }
        log.info("Syncing object information data to all pods");
        boolean allSuccess = true;
        List<Pod> pods = podRepository.findAll();
        for (Pod pod : pods) {
            try {
                syncObjectInfoDataToSinglePod(objectsInfo, operation, pod);
            } catch (Exception e) {
                log.error("Error in syncing object information to pod ID: {}", pod.getPodId(), e);
                allSuccess = false;
            }
        }
        return CompletableFuture.completedFuture(allSuccess);
    }
    @Override
    public boolean syncObjectInfoDataToSinglePod(List<CrObjectInformation> objectsInfo, Operation operation, Pod pod) throws SQLException {
        boolean success = true;
        if (!enableDataSync) {
            log.info("In syncObjectInfoDataToSinglePod(), Data sync is disabled");
            return true;
        }

        if(objectsInfo.isEmpty()){
            log.info("In syncObjectInfoDataToSinglePod(), No objects Info data to sync");
            return true;
        }
        log.info("In syncObjectInfoDataToSinglePod(), Syncing object information data to pod ID: {} ", pod.getPodId());
        Connection conn = null;
        try {
            log.info("Creating db connection tp pod Id : {} ", pod.getPodId());
            conn = DriverManager.getConnection(pod.getPodTargetUrl(), pod.getPodDbUser(), pod.getPodDbPassword());
            conn.setAutoCommit(false);

            switch (operation) {
                case INSERT:
                    log.info("Inserting object information to pod Id : {} ", pod.getPodId());
                    insertObjectInformation(conn, objectsInfo);
                    break;
                case UPDATE:
                    log.info("Updating object information to pod Id : {} ", pod.getPodId());
                    updateObjectInformation(conn, objectsInfo);
                    break;
                case DELETE:
                    log.info("Deleting object information to pod Id : {} ", pod.getPodId());
                    deleteObjectInformation(conn, objectsInfo);
                    break;
            }
            conn.commit();
            log.info("In syncObjectInfoDataToSinglePod() Transaction committed");
            saveDataSyncExecutionLog(pod.getClient().getClientId(), pod.getPodId(), targetObjectInfoTable, success, null);
            log.info("In syncObjectInfoDataToSinglePod() Saved data sync execution log successfully");
        } catch (Exception e) {
            log.error("In syncObjectInfoDataToSinglePod(), Error during data sync for pod: {} ", pod.getPodId(), e);
            success = false;
            saveDataSyncExecutionLog(pod.getClient().getClientId(), pod.getPodId(), targetObjectInfoTable, success, e.getMessage());
            log.info("In syncObjectInfoDataToSinglePod(), Saved data sync execution log successfully");
            try {
                if (conn != null &&  !conn.isClosed()) {
                    conn.rollback();
                    log.info("In syncObjectInfoDataToSinglePod(), Transaction rolled back");
                }
            } catch (SQLException sqlException) {
                log.error("In syncObjectInfoDataToSinglePod(), Error rolling back transaction", sqlException);
                throw sqlException;
            }
        } finally {
            try {
                if (conn != null) {
                    conn.close();
                    log.info("In syncObjectInfoDataToSinglePod(), Connection closed");
                }
            } catch (Exception e) {
                log.error("In syncObjectInfoDataToSinglePod(), Error closing connection", e);
            }
            return success;
        }
    }

    private void truncateTargetTables(Connection conn) throws SQLException {
        log.info("Truncating target tables");
        try (Statement stmt = conn.createStatement()) {
            stmt.execute("DELETE FROM "+targetObjectInfoTable);
            stmt.execute("DELETE FROM "+targetObjectTable);
            stmt.execute("DELETE FROM "+targetInterfaceColumnTable);
        }
        catch (SQLException e) {
            log.error("Error truncating target tables -- The tables might not exist. Please make sure the target tables do exist", e);
            throw e;
        }
    }

    private void insertObjects(Connection conn, List<CRObject> objects) throws SQLException {
        log.info("Inserting objects");
        String sql = "INSERT INTO "+targetObjectTable+" (object_id, object_name, object_code, user_object_name, module_code, " +
                "parent_object_id, fbdi_sheet, hdl_sheet, loader_endpoint, re_con_query, batch_size, " +
                "immediate_parent, sequence_in_parent, interface_table_name, rejection_table_name, " +
                "ctl_file_name, xlsm_file_name, base_tables, creation_date, created_by, " +
                "last_update_date, last_update_by, conversion_type, cld_template_name, "+
                "cld_template_code, cld_metadata_table_name) "+
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,?,?,?,?)";

        try (PreparedStatement pstmt = conn.prepareStatement(sql)) {
            for (CRObject obj : objects) {
                pstmt.setLong(1, obj.getObjectId());
                pstmt.setString(2, obj.getObjectName());
                pstmt.setString(3, obj.getObjectCode());
                pstmt.setString(4, obj.getUserObjectName());
                pstmt.setString(5, obj.getModuleCode());
                pstmt.setObject(6, obj.getParentObjectId());  // Handle nulls appropriately
                pstmt.setString(7, obj.getFbdiSheet());
                pstmt.setString(8, obj.getHdlSheet());
                pstmt.setString(9, obj.getLoaderEndpoint());
                pstmt.setString(10, obj.getReConQuery());
                if (obj.getBatchSize() != null) {
                    pstmt.setLong(11, obj.getBatchSize());
                } else {
                    pstmt.setNull(11, java.sql.Types.BIGINT);  // Use appropriate SQL type
                }
                pstmt.setString(12, obj.getImmediateParent());
                if (obj.getSequenceInParent() != null) {
                    pstmt.setLong(13, obj.getSequenceInParent());
                } else {
                    pstmt.setNull(13, java.sql.Types.BIGINT);  // Use appropriate SQL type
                }
                pstmt.setString(14, obj.getInsertTableName());
                pstmt.setString(15, obj.getRejectionTableName());
                pstmt.setString(16, obj.getCtlFileName());
                pstmt.setString(17, obj.getXlsmFileName());
                pstmt.setString(18, obj.getBaseTables());
                pstmt.setDate(19, obj.getCreationDate() != null ? new java.sql.Date(obj.getCreationDate().getTime()) : null);
                pstmt.setString(20, obj.getCreatedBy());
                pstmt.setDate(21, obj.getLastUpdatedDate() != null ? new java.sql.Date(obj.getLastUpdatedDate().getTime()) : null);
                pstmt.setString(22, obj.getLastUpdatedBy());
                pstmt.setString(23, obj.getConversionType());
                pstmt.setString(24, obj.getCldTemplateName());
                pstmt.setString(25, obj.getCldTemplateCode());
                pstmt.setString(26, obj.getCldMetaDataTableName());
                pstmt.addBatch();
            }
            log.info("In insertObjects, Executing Batch of PreparedStatements");
            pstmt.executeBatch();
        } catch (SQLException e) {
            log.error("Error inserting objects into {}", targetObjectTable, e);
            throw e; // Rethrow the caught SQLException
        }
    }

    private void updateObjects(Connection conn, List<CRObject> objects) throws SQLException {
        log.info("Updating objects");
        String sql = "UPDATE "+targetObjectTable+" SET " +
                "object_name = ?, object_code = ?, user_object_name = ?, module_code = ?, " +
                "parent_object_id = ?, fbdi_sheet = ?, hdl_sheet = ?, loader_endpoint = ?, " +
                "re_con_query = ?, batch_size = ?, immediate_parent = ?, sequence_in_parent = ?, " +
                "interface_table_name = ?, rejection_table_name = ?, ctl_file_name = ?, " +
                "xlsm_file_name = ?, base_tables = ?, creation_date = ?, created_by = ?, " +
                "last_update_date = ?, last_update_by = ?, " +
                "conversion_type = ?, cld_template_name = ?, cld_template_code =?, " +
                "cld_metadata_table_name=? "+
                "WHERE object_id = ?";

        try (PreparedStatement pstmt = conn.prepareStatement(sql)) {
            for (CRObject obj : objects) {
                pstmt.setString(1, obj.getObjectName());
                pstmt.setString(2, obj.getObjectCode());
                pstmt.setString(3, obj.getUserObjectName());
                pstmt.setString(4, obj.getModuleCode());
                pstmt.setObject(5, obj.getParentObjectId(), java.sql.Types.BIGINT);
                pstmt.setString(6, obj.getFbdiSheet());
                pstmt.setString(7, obj.getHdlSheet());
                pstmt.setString(8, obj.getLoaderEndpoint());
                pstmt.setString(9, obj.getReConQuery());
                if (obj.getBatchSize() != null) {
                    pstmt.setLong(10, obj.getBatchSize());
                } else {
                    pstmt.setNull(10, java.sql.Types.BIGINT);
                }
                pstmt.setString(11, obj.getImmediateParent());
                if (obj.getSequenceInParent() != null) {
                    pstmt.setLong(12, obj.getSequenceInParent());
                } else {
                    pstmt.setNull(12, java.sql.Types.BIGINT);  // Use appropriate SQL type
                }
                pstmt.setString(13, obj.getInsertTableName());
                pstmt.setString(14, obj.getRejectionTableName());
                pstmt.setString(15, obj.getCtlFileName());
                pstmt.setString(16, obj.getXlsmFileName());
                pstmt.setString(17, obj.getBaseTables());
                pstmt.setDate(18, obj.getCreationDate() != null ? new java.sql.Date(obj.getCreationDate().getTime()) : null);
                pstmt.setString(19, obj.getCreatedBy());
                pstmt.setDate(20, obj.getLastUpdatedDate() != null ? new java.sql.Date(obj.getLastUpdatedDate().getTime()) : null);
                pstmt.setString(21, obj.getLastUpdatedBy());
                pstmt.setString(22, obj.getConversionType());
                pstmt.setString(23, obj.getCldTemplateName());
                pstmt.setString(24, obj.getCldTemplateCode());
                pstmt.setString(25, obj.getCldMetaDataTableName());
                pstmt.setLong(26, obj.getObjectId());
                pstmt.addBatch();
            }
            log.info("In updateObjects(), Executing Batch of PreparedStatements");
            pstmt.executeBatch();
        } catch (SQLException e) {
            log.error("Error updating objects into  {} exception:: {} ", targetObjectTable, e);
            throw e; // Rethrow the caught SQLException
        }
    }

    @Async
    public void syncCrudObjectInfoToAllPods(List<CrObjectInformation> insertList, List<CrObjectInformation> updateList, List<Long> deleteList) {
        try {
            log.info("Inserting object info data to all pods in the method syncCrudObjectInfoToAllPods");
            CompletableFuture<Boolean> insertSuccess = syncObjectInfoDataToAllPods(insertList, DataSyncService.Operation.INSERT );
            if( insertSuccess.get()){
                log.info("Updating object info data to all pods in the method syncCrudObjectInfoToAllPods");
                CompletableFuture<Boolean> updateSuccess  = syncObjectInfoDataToAllPods(updateList, DataSyncService.Operation.UPDATE );
                if(updateSuccess.get()){
                    log.info("Deleting object info data to all pods in the method syncCrudObjectInfoToAllPods");
                    syncObjectInfoDataToAllPods(objectInformationRepository.findAllById(deleteList), DataSyncService.Operation.DELETE );
                }
            }

        } catch (ExecutionException | InterruptedException e) {
            log.error("Error syncing object info data to all pods in method syncCrudObjectInfoToAllPods", e);
            throw new RuntimeException(e);
        }
        catch (Exception e) {
            log.error("Error syncing object info data to all pods in method syncCrudObjectInfoToAllPods", e);
            throw new RuntimeException(e);
        }
    }

    private void deleteObjects(Connection conn, List<CRObject> objects) throws SQLException {
        log.info("Deleting objects");
        String sql = "DELETE FROM "+targetObjectTable+" WHERE object_id = ?";

        try (PreparedStatement pstmt = conn.prepareStatement(sql)) {
            for (CRObject obj : objects) {
                if (obj.getObjectId() != null) { // Ensure the ID is not null to prevent errors
                    pstmt.setLong(1, obj.getObjectId());
                    pstmt.addBatch();
                }
            }
            log.info("In deleteObjects(), Executing Batch of PreparedStatements");
            int[] affectedRecords = pstmt.executeBatch();
            log.info("In deleteObjects(), Deleted count: {} ", Arrays.stream(affectedRecords).sum());
        }
        catch (SQLException e) {
            log.error("Error deleting objects into {} ",targetObjectTable, e);
            throw e; // Rethrow the caught SQLException
        }
    }

    private void insertObjectInformation(Connection conn, List<CrObjectInformation> objectInformation) throws SQLException {
        log.info("Inserting object information");
        String sql = "INSERT INTO "+targetObjectInfoTable+" (obj_info_id, object_id, info_type, info_value, info_description, " +
                "additional_information1, additional_information2, additional_information3, additional_information4, additional_information5, " +
                "creation_date, created_by, last_update_date, last_update_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

        try (PreparedStatement pstmt = conn.prepareStatement(sql)) {
            for (CrObjectInformation info : objectInformation) {
                pstmt.setLong(1, info.getObjInfoId());
                pstmt.setLong(2, info.getObjectId());
                pstmt.setString(3, info.getInfoType());
                pstmt.setString(4, info.getInfoValue()); // Using setString for CLOB for simplicity; adjust if needed
                pstmt.setString(5, info.getInfoDescription());
                pstmt.setString(6, info.getAdditionalInformation1());
                pstmt.setString(7, info.getAdditionalInformation2());
                pstmt.setString(8, info.getAdditionalInformation3());
                pstmt.setString(9, info.getAdditionalInformation4());
                pstmt.setString(10, info.getAdditionalInformation5());
                pstmt.setDate(11, info.getCreationDate() != null ? new java.sql.Date(info.getCreationDate().getTime()) : null);
                pstmt.setString(12, info.getCreatedBy());
                pstmt.setDate(13, info.getLastUpdateDate() != null ? new java.sql.Date(info.getLastUpdateDate().getTime()) : null);
                pstmt.setString(14, info.getLastUpdateBy());

                pstmt.addBatch();
            }
            log.info("In insertObjectInformation(), Executing Batch of PreparedStatements");
            pstmt.executeBatch();
        } catch (SQLException e) {
            log.error("In insertObjectInformation(), Error inserting object information into {}", targetObjectInfoTable, e);
            throw e; // Rethrow the caught SQLException
        }
    }

    private void updateObjectInformation(Connection conn, List<CrObjectInformation> objectInformations) throws SQLException {
        log.info("Updating object information");
        String sql = "UPDATE "+targetObjectInfoTable+" SET " +
                "object_id = ?, info_type = ?, info_value = ?, info_description = ?, " +
                "additional_information1 = ?, additional_information2 = ?, additional_information3 = ?, " +
                "additional_information4 = ?, additional_information5 = ?, " +
                "creation_date = ?, created_by = ?, last_update_date = ?, last_update_by = ? " +
                "WHERE obj_info_id = ?";

        try (PreparedStatement pstmt = conn.prepareStatement(sql)) {
            for (CrObjectInformation info : objectInformations) {
                pstmt.setLong(1, info.getObjectId());
                pstmt.setString(2, info.getInfoType());
                pstmt.setString(3, info.getInfoValue());
                pstmt.setString(4, info.getInfoDescription());
                pstmt.setString(5, info.getAdditionalInformation1());
                pstmt.setString(6, info.getAdditionalInformation2());
                pstmt.setString(7, info.getAdditionalInformation3());
                pstmt.setString(8, info.getAdditionalInformation4());
                pstmt.setString(9, info.getAdditionalInformation5());
                pstmt.setDate(10, info.getCreationDate() != null ? new java.sql.Date(info.getCreationDate().getTime()) : null);
                pstmt.setString(11, info.getCreatedBy());
                pstmt.setDate(12, info.getLastUpdateDate() != null ? new java.sql.Date(info.getLastUpdateDate().getTime()) : null);
                pstmt.setString(13, info.getLastUpdateBy());
                pstmt.setLong(14, info.getObjInfoId());

                pstmt.addBatch();
            }
            log.info("Executing Batch of PreparedStatements");
            pstmt.executeBatch();
        }
        catch (SQLException e) {
            log.error("Error updating object information into {} ",targetObjectInfoTable, e);
            throw e; // Rethrow the caught SQLException
        }
    }

    private void deleteObjectInformation(Connection conn, List<CrObjectInformation> objectInfoList) throws SQLException {
        log.info("Deleting object information");
        String sql = "DELETE FROM "+targetObjectInfoTable+" WHERE obj_info_id = ?";

        try (PreparedStatement pstmt = conn.prepareStatement(sql)) {
            for (CrObjectInformation  objectInfo : objectInfoList) {
                pstmt.setLong(1, objectInfo.getObjInfoId());
                pstmt.addBatch();
            }
            int[] affectedRecords = pstmt.executeBatch();
            log.info("Deleted count:  {} ", Arrays.stream(affectedRecords).sum());
        }
        catch (SQLException e) {
            log.error("Error deleting object information into {} ", targetObjectInfoTable, e);
            throw e; // Rethrow the caught SQLException
        }
    }

    private void saveDataSyncExecutionLog(Long clientId, Long podId, String tableName, Boolean success, String errorMessage) {
        DataSyncExecutionLog dataSyncExecutionLog = new DataSyncExecutionLog();
        dataSyncExecutionLog.setClientId(clientId);
        dataSyncExecutionLog.setPodId(podId);
        dataSyncExecutionLog.setTableName(tableName);
        dataSyncExecutionLog.setSuccess(success);
        dataSyncExecutionLog.setErrorMsg(errorMessage);
        dataSyncExecutionLog.setCreationDate(new java.util.Date());
        dataSyncRepository.save(dataSyncExecutionLog);
    }

    @Async
    @Override
    public CompletableFuture<Boolean> syncTargetInterfaceColumnToAllPods(List<CRTargetInterfaceColumn> targetInfData, DataSyncService.Operation operation) {
        log.info("Syncing Target Interface Column data to all pods");
        if (!enableDataSync) {
            log.info("In syncTargetInterfaceColumnToAllPods, Data sync is disabled");
            return CompletableFuture.completedFuture(true);
        }
        if(targetInfData.isEmpty()){
            log.info("No Target Interface Column data found to sync");
            return CompletableFuture.completedFuture(true);
        }
        log.info("Syncing Target Interface Column data to all pods");
        boolean allSuccess = true;
        List<Pod> pods = podRepository.findAll();
        for (Pod pod : pods) {
            try {
                syncTargetInterfaceColumnToSinglePod(targetInfData, pod);
            } catch (Exception e) {
                log.error("Error in syncing Target Interface Column to pod ID:  {}  Exception: {}", pod.getPodId(), e);
                allSuccess = false;
            }
        }
        return CompletableFuture.completedFuture(allSuccess);
    }

    @Override
    public boolean syncTargetInterfaceColumnToSinglePod(List<CRTargetInterfaceColumn> targetInfData, Pod pod) {
        boolean success = true;
        if (!enableDataSync) {
            log.info("In syncTargetInterfaceColumnToSinglePod(), Data sync is disabled");
            return true;
        }
        // return true Target Data list is empty
        if(targetInfData.isEmpty()){
            log.info("No Target Interface Column data to sync");
            return true;
        }
        log.info("Syncing TargetInterfaceColumnList data to pod ID: {} ", pod.getPodId());
        Connection conn = null;
        try {
            log.info("In TargetInterfaceColumnList, Creating db connection to pod Id : {} ", pod.getPodId());
            conn = DriverManager.getConnection(pod.getPodTargetUrl(), pod.getPodDbUser(), pod.getPodDbPassword());
            conn.setAutoCommit(false);
            insertTargetInterfaceColumn(conn, targetInfData);
            conn.commit();
            log.info("In TargetInterfaceColumnList Transaction committed for POD: {} ", pod.getPodId());
            saveDataSyncExecutionLog(pod.getClient().getClientId(), pod.getPodId(), targetInterfaceColumnTable, success, null);
            log.info("In TargetInterfaceColumnList Saved Target Interface Column data sync execution log successfully");
        } catch (Exception e) {
            log.error("In TargetInterfaceColumnList, Error during data sync for pod ID: {}", pod.getPodId(), e);
            success = false;
            saveDataSyncExecutionLog(pod.getClient().getClientId(), pod.getPodId(), targetInterfaceColumnTable, success, e.getMessage());
            log.info("In TargetInterfaceColumnList, Saved data sync execution log successfully");
            try {
                if (conn != null &&  !conn.isClosed()) {
                    conn.rollback();
                    log.info("In TargetInterfaceColumnList, Transaction rolled back");
                }
            } catch (SQLException sqlException) {
                log.error("In TargetInterfaceColumnList, Error rolling back transaction", sqlException);
                throw sqlException;
            }
        } finally {
            try {
                if (conn != null) {
                    conn.close();
                    log.info("In TargetInterfaceColumnList, Connection closed");
                }
            } catch (Exception e) {
                log.error("In TargetInterfaceColumnList, Error closing connection", e);
            }
            return success;
        }
    }

    private void insertTargetInterfaceColumn(Connection conn, List<CRTargetInterfaceColumn> targetInfData) throws SQLException {
        String sql = "INSERT INTO CR_TARGET_INTF_COLUMN_LIST (" +
                "TARGET_SYSTEM, TARGET_SYSTEM_VERSION, OBJECT_ID, COLUMN_NAME, " +
                "PHYSICAL_COLUMN_NAME, USER_COLUMN_NAME, COLUMN_DESCRPTION, COLUMN_SEQUENCE, COLUMN_TYPE, " +
                "COLUMN_WIDTH, NULL_ALLOWED_FLAG, TRANSLATE_FLAG, PRECISION, SCALE, DOMAIN_CODE, " +
                "DENORM_PATH, ROUTING_MODE, CLOUD_VERSION, ELIGIBLE_TO_BE_SECURED, " +
                "SECURITY_CLASSIFICATION, SEC_CLASSIFICATION_OVERRIDE, ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, " +
                "ATTRIBUTE4, ATTRIBUTE5, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,?)";

        try (PreparedStatement pstmt = conn.prepareStatement(sql)) {
            for (CRTargetInterfaceColumn obj : targetInfData) {
                pstmt.setString(1, obj.getTargetSystem());
                pstmt.setString(2, obj.getTargetSystemVersion());
                pstmt.setObject(3, obj.getObjectId(), java.sql.Types.BIGINT);
                pstmt.setString(4, obj.getColumnName());
                pstmt.setString(5, obj.getPhysicalColumnName());
                pstmt.setString(6, obj.getUserColumnName());
                pstmt.setString(7, obj.getColumnDescription());
                pstmt.setString(8, obj.getColumnSequence());
                pstmt.setString(9, obj.getColumnType());
                pstmt.setString(10, obj.getColumnWidth());
                pstmt.setString(11, obj.getNullAllowedFlag());
                pstmt.setString(12, obj.getTranslateFlag());
                pstmt.setString(13, obj.getPrecision());
                pstmt.setString(14, obj.getScale());
                pstmt.setString(15, obj.getDomainCode());
                pstmt.setString(16, obj.getDenormPath());
                pstmt.setString(17, obj.getRoutingMode());
                pstmt.setString(18, obj.getCloudVersion());
                pstmt.setString(19, obj.getEligibleToBeSecured());
                pstmt.setString(20, obj.getSecurityClassification());
                pstmt.setString(21, obj.getSecClassificationOverride());
                pstmt.setString(22, obj.getAttribute1());
                pstmt.setString(23, obj.getAttribute2());
                pstmt.setString(24, obj.getAttribute3());
                pstmt.setString(25, obj.getAttribute4());
                pstmt.setString(26, obj.getAttribute5());
                pstmt.setTimestamp(27, new java.sql.Timestamp(obj.getCreationDate().getTime())); // CREATION_DATE
                pstmt.setString(28, obj.getCreatedBy());
                pstmt.setTimestamp(29, obj.getLastUpdateDate() != null ? new java.sql.Timestamp(obj.getLastUpdateDate().getTime()) : null);
                pstmt.setString(30, obj.getLastUpdatedBy());

                pstmt.addBatch();
            }
            pstmt.executeBatch();
        }catch (SQLException e) {
            log.error("Error inserting target interface columns into {} exception: {} ", targetInterfaceColumnTable, e.getMessage());
            throw e; // Rethrow the caught SQLException
        }
    }
}
