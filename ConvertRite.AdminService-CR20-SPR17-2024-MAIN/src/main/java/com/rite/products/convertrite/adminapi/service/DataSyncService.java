package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.model.CRObject;
import com.rite.products.convertrite.adminapi.model.CRTargetInterfaceColumn;
import com.rite.products.convertrite.adminapi.model.CrObjectInformation;
import com.rite.products.convertrite.adminapi.model.Pod;

import java.sql.SQLException;
import java.util.List;
import java.util.concurrent.CompletableFuture;

public interface DataSyncService {

    enum Operation {
        INSERT,
        UPDATE,
        DELETE
    }

    void performFullDataSyncToAllPods() ;
    CompletableFuture<Boolean> syncObjectDataToAllPods(List<CRObject> objects, Operation operation, boolean truncateTargetTable) throws SQLException ;

    boolean syncObjectDataToSinglePod(List<CRObject> objects, Operation operation, Pod pod, boolean truncateTargetTable) throws SQLException ;

    CompletableFuture<Boolean> syncObjectInfoDataToAllPods(List<CrObjectInformation> objectsInfo, Operation operation) throws SQLException ;

    boolean syncObjectInfoDataToSinglePod(List<CrObjectInformation> objectsInfo, Operation operation, Pod pod) throws SQLException ;

    void syncCrudObjectInfoToAllPods(List<CrObjectInformation> insertList, List<CrObjectInformation> updateList, List<Long> deleteList) ;

    boolean syncTargetInterfaceColumnToSinglePod(List<CRTargetInterfaceColumn> targetInfData, Pod pod) throws SQLException;

    CompletableFuture<Boolean> syncTargetInterfaceColumnToAllPods(List<CRTargetInterfaceColumn> objects, Operation operation) throws SQLException ;

}
