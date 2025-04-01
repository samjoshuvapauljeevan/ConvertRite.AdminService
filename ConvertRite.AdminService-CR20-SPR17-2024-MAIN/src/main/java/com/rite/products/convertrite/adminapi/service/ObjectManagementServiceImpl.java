package com.rite.products.convertrite.adminapi.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.rite.products.convertrite.adminapi.exception.CRAdminException;
import com.rite.products.convertrite.adminapi.exception.CRNotFoundException;
import com.rite.products.convertrite.adminapi.exception.CRUniquenessException;
import com.rite.products.convertrite.adminapi.model.*;
import com.rite.products.convertrite.adminapi.po.*;
import com.rite.products.convertrite.adminapi.respository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.*;
import java.util.*;
import java.util.Date;
import java.util.stream.Collectors;

@RequiredArgsConstructor
@Service
@Slf4j
public class ObjectManagementServiceImpl extends BasicManagementService<CRObject, Long> implements ObjectManagementService {

    @Autowired
    ObjectRepository objectRepository;
    @Autowired
    ObjectInformationRepository objectInformationRepository;
    @Autowired
    Object1Repository object1Repository;
    @Autowired
    PodCloudConfigRepository podCloudConfigRepo;
    @Autowired
    CRCloudImportObjectLinkRepository cRCloudImportObjLinkRepo;
    @Autowired
    PodRepository podRepository;
    @Autowired
    CrObjectInformationVRepo crObjectInformationVRepo;
    @Autowired
    CRTargetInterfaceColumnRepository cRTargetInterfaceColumnRepository;

    @Autowired
    DataSyncService dataSyncService;

    @Override
    public BasicResPo createObject(ObjectCreationReqPo objectCreationReqPo) {

        CRObject c = new CRObject();
        c.setObjectName(objectCreationReqPo.getObjectName());
        c.setObjectCode(objectCreationReqPo.getObjectCode());
        c.setUserObjectName(objectCreationReqPo.getUserObjectName());
        c.setModuleCode(objectCreationReqPo.getModuleCode());
        c.setParentObjectId(objectCreationReqPo.getParentObjectId());
        c.setFbdiSheet(objectCreationReqPo.getFbdiSheet());
        c.setHdlSheet(objectCreationReqPo.getHdlSheet());
        c.setLoaderEndpoint(objectCreationReqPo.getLoaderEndpoint());
        c.setReConQuery(objectCreationReqPo.getReConQuery());
        c.setSequenceInParent(objectCreationReqPo.getSequenceInParent());
        c.setInsertTableName(objectCreationReqPo.getInsertTableName());
        c.setRejectionTableName(objectCreationReqPo.getRejectionTableName());
        c.setCtlFileName(objectCreationReqPo.getCtlFileName());
        c.setXlsmFileName(objectCreationReqPo.getXlsmFileName());
        c.setLastUpdatedBy("ConvertRiteAdmin");
        c.setLastUpdatedDate(new java.sql.Date(new Date().getTime()));
        c.setCreationDate(new java.sql.Date(new Date().getTime()));
        c.setCreatedBy("ConvertRiteAdmin");
        try {
            CRObject entityRes = super.addEntity(objectRepository, c);
            CRObject createdEntity = super.getEntityById(objectRepository, entityRes.getObjectId());

            log.info("Syncing the newly created object data to all pods");
            dataSyncService.syncObjectDataToAllPods(new ArrayList<>(Collections.singletonList(createdEntity)), DataSyncService.Operation.INSERT, false);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CREATED);
                setStatus("success");
                setMessage("Successfully created object " + createdEntity.getObjectName());
                setPayload(createdEntity);
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("Object code " + objectCreationReqPo.getObjectCode() + " is already available. It should be unique.");
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
    public BasicResPo getObjects(String moduleCode, Long clientId) {
        List<CRObject> crObjects = new ArrayList<>();
        log.info("clientId---> {} ",  clientId);
        if (moduleCode != null) {
            crObjects = objectRepository.findByModuleCode(moduleCode);
        } else if (clientId != null) {
            crObjects = objectRepository.findByClientId(clientId);
        } else {
            crObjects = objectRepository.findAll();
        }

        Map<Long, String> map = new HashMap<>();
        for (CRObject co : crObjects) {
            if (co.getParentObjectId() == null) {
                map.put(co.getObjectId(), co.getObjectName());
            }
        }
        ObjectMapper mapper = new ObjectMapper();
        List<CrObjectsResPo> newCrObjects = mapper.convertValue(crObjects, new TypeReference<List<CrObjectsResPo>>() {
        });

        for (CrObjectsResPo co : newCrObjects) {
            if (co.getParentObjectId() != null) {
                // log.info("if--->"+co.getObjectName());
                co.setParentObjectName(map.get(co.getParentObjectId()));
            }
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved objects");
            setPayload(newCrObjects);
        }};
    }


    @Override
    public BasicResPo getObjectById(Long objectId) {
        try {
            CRObject crObject = super.getEntityById(objectRepository, objectId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get object with id " + objectId);
                setPayload(crObject);
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Object with id " + objectId + " is not found");
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
    public BasicResPo getObjectInformationByObjectId(Long objectId) {
        try {
            CRObject existingEntity = super.getEntityById(objectRepository, objectId);
            List<CrObjectInformation> crObjectInformation = objectInformationRepository.findByObjectIdOrderByObjInfoIdAsc(objectId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get object information for object with code " + existingEntity.getObjectCode());
                setPayload(crObjectInformation);
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
    public BasicResPo saveAllObjectInformationByObjectId(ArrayList<CrObjectInformationCreateReqPo> objectInformationReqPoList, Long objectId) {

        List<CrObjectInformation> insertList = new ArrayList<CrObjectInformation>();
        List<CrObjectInformation> updateList = new ArrayList<CrObjectInformation>();
        List<Long> deleteList = new ArrayList<Long>();
        CRObject existingEntity = super.getEntityById(objectRepository, objectId);
        for (CrObjectInformationCreateReqPo crObjectInformationCreateReqPo : objectInformationReqPoList) {
            if (crObjectInformationCreateReqPo.getInsertOrDelete().equalsIgnoreCase("D")) {
                deleteList.add((long) crObjectInformationCreateReqPo.getObjInfoId());
            } else {
                CrObjectInformation crObjectInformation = new CrObjectInformation();

                crObjectInformation.setObjectId(crObjectInformationCreateReqPo.getObjectId());
                crObjectInformation.setInfoType(crObjectInformationCreateReqPo.getInfo_type());
                crObjectInformation.setInfoValue(crObjectInformationCreateReqPo.getInfo_value());
                crObjectInformation.setInfoDescription(crObjectInformationCreateReqPo.getInfo_description());
                crObjectInformation.setAdditionalInformation1(crObjectInformationCreateReqPo.getAdditional_information1());
                crObjectInformation.setAdditionalInformation2(crObjectInformationCreateReqPo.getAdditional_information2());
                crObjectInformation.setAdditionalInformation3(crObjectInformationCreateReqPo.getAdditional_information3());
                crObjectInformation.setAdditionalInformation4(crObjectInformationCreateReqPo.getAdditional_information4());
                crObjectInformation.setAdditionalInformation5(crObjectInformationCreateReqPo.getAdditional_information5());

                if (Objects.isNull(crObjectInformationCreateReqPo.getObjInfoId())
                        || crObjectInformationCreateReqPo.getObjInfoId() == 0) {
                    crObjectInformation.setCreationDate(new Date());
                    crObjectInformation.setCreatedBy(crObjectInformationCreateReqPo.getCreated_by());
                    crObjectInformation.setLastUpdateDate(new Date());
                    crObjectInformation.setLastUpdateBy(crObjectInformationCreateReqPo.getCreated_by());
                    insertList.add(crObjectInformation);
                } else {
                    CrObjectInformation existingObject = objectInformationRepository.findById(crObjectInformationCreateReqPo.getObjInfoId()).get();
                    crObjectInformation.setObjInfoId(crObjectInformationCreateReqPo.getObjInfoId());
                    crObjectInformation.setCreationDate(existingObject.getCreationDate());
                    crObjectInformation.setCreatedBy(existingObject.getCreatedBy());
                    crObjectInformation.setLastUpdateDate(new Date());
                    crObjectInformation.setLastUpdateBy(crObjectInformationCreateReqPo.getCreated_by());
                    updateList.add(crObjectInformation);
                }
            }
        }
        log.info(" deleteList Size: {} insertList: {}  updateList: {} ", deleteList.size(), insertList.size(), updateList.size());
        if (deleteList.size() > 0) {
            try {
                objectInformationRepository.deleteAllById(deleteList);
            } catch (Exception e) {

            }
        }
        if (insertList.size() > 0) {
            try {
                objectInformationRepository.saveAll(insertList);
            } catch (Exception e) {

            }
        }
        if (updateList.size() > 0) {
            try {
                objectInformationRepository.saveAll(updateList);
            } catch (Exception e) {

            }
        }

        BasicResPo response = this.getObjectInformationByObjectId(objectId);
        if (response.getStatus() == "success") {
            log.info("Syncing CRUD object data info to all pods");
            dataSyncService.syncCrudObjectInfoToAllPods(insertList, updateList, deleteList);
            response.setMessage("Successfully saved object information for object with code " + existingEntity.getObjectCode());
        }
        return response;
    }

    @Override
    public BasicResPo putObjectById(Long objectId, ObjectCreationReqPo objectCreationReqPo) {
        log.info("service method ====== putObjectById()");
        try {
            CRObject c = objectRepository.findById(objectId).get();
            c.setObjectName(objectCreationReqPo.getObjectName());
            c.setObjectCode(objectCreationReqPo.getObjectCode());
            c.setUserObjectName(objectCreationReqPo.getUserObjectName());
            c.setModuleCode(objectCreationReqPo.getModuleCode());
            c.setParentObjectId(objectCreationReqPo.getParentObjectId());
            c.setFbdiSheet(objectCreationReqPo.getFbdiSheet());
            c.setHdlSheet(objectCreationReqPo.getHdlSheet());
            c.setLoaderEndpoint(objectCreationReqPo.getLoaderEndpoint());
            c.setReConQuery(objectCreationReqPo.getReConQuery());
            c.setSequenceInParent(objectCreationReqPo.getSequenceInParent());
            c.setInsertTableName(objectCreationReqPo.getInsertTableName());
            c.setRejectionTableName(objectCreationReqPo.getRejectionTableName());
            c.setCtlFileName(objectCreationReqPo.getCtlFileName());
            c.setXlsmFileName(objectCreationReqPo.getXlsmFileName());
            c.setBatchSize(objectCreationReqPo.getBatchSize());
            c.setImmediateParent(objectCreationReqPo.getImmediateParent());
            c.setBaseTables(objectCreationReqPo.getBaseTables());
            c.setLastUpdatedBy(objectCreationReqPo.getLastUpdatedBy());
            c.setLastUpdatedDate(new java.sql.Date(new Date().getTime()));
            CRObject updatedEntity = super.updateEntity(objectRepository, c);

            log.info("Syncing PUT object data to all pods");
            dataSyncService.syncObjectDataToAllPods( new ArrayList<>(Collections.singletonList(updatedEntity)), DataSyncService.Operation.UPDATE, false);

            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully updated object " + updatedEntity.getObjectName());
                setPayload(updatedEntity);
            }};

        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Object with id " + objectId + " is not found");
                setPayload(ex);
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("ObjectCode " + objectCreationReqPo.getObjectCode() + " is already available. It should be unique.");
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
    public BasicResPo deleteObjectById(Long objectId) {
        try {
            CRObject objectEntity = super.getEntityById(objectRepository, objectId);
            super.deleteEntityById(objectRepository, objectId);

            log.info("syncing delete object data to all pods");
            dataSyncService.syncObjectDataToAllPods( new ArrayList<>(Collections.singletonList(objectEntity)), DataSyncService.Operation.DELETE , false);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully deleted object with name " + objectEntity.getObjectName());
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Object with id " + objectId + " not exists to delete");
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
    public BasicResPo getPodsLinkedWithObjects(Long objectId) {

        List podsList = new ArrayList<>();
        try {
            Set<Integer> credIdList = cRCloudImportObjLinkRepo.findAllByObjectId(objectId);
            Set<Long> podIdList = new HashSet<>();

            credIdList.forEach(credId -> {
                log.info("credId---> {} ", credId);
                if (credId != null) {
                    Long podId = podCloudConfigRepo.findByCredentialId(credId);
                    log.info("podId---> {} ", podId);
                    podIdList.add(podId);
                }
            });
            podIdList.forEach(id -> {
                if (id != null) {
                    String podName = podRepository.findById(id).get().getPodName();
                    PodDetailsResPo podDetailsResPo = new PodDetailsResPo();
                    podDetailsResPo.setPodId(id);
                    podDetailsResPo.setPodName(podName);
                    podsList.add(podDetailsResPo);
                }
            });

            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully retrieved the Details ");
                setPayload(podsList);
            }};

        } catch (Exception e) {
            e.printStackTrace();
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(e.getMessage());
                setPayload(e);
            }};
        }
    }

    @Override
    public BasicResPo getParentObjects(Long userId, Long projectId) {
        Set<CRObject> parentObjList = objectRepository.getParentObjects(userId, projectId);
        log.info("parentObjList-> {} ", parentObjList.size());
        BasicResPo res = new BasicResPo();
        res.setPayload(parentObjList);
        res.setStatusCode(HttpStatus.OK);
        res.setStatus("success");
        return res;
    }

    @Override
    public BasicResPo getObjectsByUserId(Long userId) {
        BasicResPo res = new BasicResPo();
        try {
            Set<CRObject> crObjects = objectRepository.getAllObjectsByUserId(userId);
            log.info("crObjects--> {} ", crObjects.size());

            Map<Long, String> map = new HashMap<>();
            for (CRObject co : crObjects) {
                if (co.getParentObjectId() == null) {
                    map.put(co.getObjectId(), co.getObjectName());
                }
            }
            ObjectMapper mapper = new ObjectMapper();
            List<CrObjectsResPo> newCrObjects = mapper.convertValue(crObjects, new TypeReference<List<CrObjectsResPo>>() {
            });
            log.info("newCrObjects--> {} ", newCrObjects.size());
            for (CrObjectsResPo co : newCrObjects) {
                if (co.getParentObjectId() != null) {
                    //  log.info("if--->"+co.getObjectName());
                    co.setParentObjectName(map.get(co.getParentObjectId()));
                }
            }

            res.setPayload(newCrObjects);
            res.setStatusCode(HttpStatus.OK);
            res.setStatus("success");
            res.setMessage("Objects Loaded Successfully");
        } catch (Exception e) {
            e.printStackTrace();
            res.setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
            res.setStatus("error");
            res.setMessage(e.getMessage());
        }
        return res;
    }

    @Override
    public BasicResPo getObjectsWithInformation(Long podId, List<Long> objectId) {
        BasicResPo res = new BasicResPo();
        log.info("objectId--> {} ", objectId);
        List<CRObject1> objList = object1Repository.findByObjectIdIn(objectId);
        List<CloudLogin> cloudLoginList = podCloudConfigRepo.findAllByPodId(podId);
        Map<String, Object> map = new HashMap<>();
        map.put("objectsDetails", objList);
        map.put("cloudLoginDetails", cloudLoginList);
        res.setPayload(map);
        res.setStatusCode(HttpStatus.OK);
        res.setStatus("success");
        res.setMessage("Data Loaded Successfully");
        return res;
    }

    @Override
    public BasicResPo getSequence(long parentObjectId) {
        BasicResPo res = new BasicResPo();
        Optional<List<CrObjectInformationV>> optional = crObjectInformationVRepo.findAllByParentObjectId(parentObjectId);
        List<CrObjectInformationV> crObjectInformationVList = new ArrayList<>();
        if (optional.isPresent()) {
            crObjectInformationVList = optional.get();
        }
        res.setPayload(crObjectInformationVList);
        res.setStatus("success");
        res.setStatusCode(HttpStatus.OK);
        res.setMessage("Getting Object Sequence Successfully");
        return res;
    }

    public CopyObjAndObjectInfoRes copyObjectAndObjectInformation(CRObject crObject, String newObjectName, Long parentObjId, String suffix) throws Exception {
        log.info("Copying Object and Object Information with new name, {} ", newObjectName);
        CopyObjAndObjectInfoRes cpyObjAndObjectInfoRes = new CopyObjAndObjectInfoRes();

        CRObject existCrObj=objectRepository.findByObjectNameIgnoreCase(newObjectName);
        if(existCrObj!=null)
            throw new CRAdminException("Object with name " + newObjectName + " already exists");

        // Save CRObject data with a new object name
        CRObject cpyObjectResp = saveCrObjectWithNewName(crObject,newObjectName, parentObjId, suffix);

        // Retrieve CrObjectInformation based on the oldObjectId
        List<CrObjectInformation> crObjectInformationLi = objectInformationRepository.findByObjectIdOrderByObjInfoIdAsc(crObject.getObjectId());

        // Save object information with a new object id
        List<CrObjectInformation> cpyObjectInfoLi=  saveCrObjInfoWithNewObjectId(crObjectInformationLi,cpyObjectResp.getObjectId());

        // Save Target Interface Column with a new Object Id
        List<CRTargetInterfaceColumn> crTargetInterfaceColumns =  saveCRTargetInterfaceColumnWithNewObjectId(crObject.getObjectId(), cpyObjectResp.getObjectId());

        cpyObjAndObjectInfoRes.setCrObject(cpyObjectResp);
        cpyObjAndObjectInfoRes.setCrObjectInformationList(cpyObjectInfoLi);
        cpyObjAndObjectInfoRes.setCRTargetInterfaceColumns(crTargetInterfaceColumns);
        return cpyObjAndObjectInfoRes;
    }

    private List<CrObjectInformation> saveCrObjInfoWithNewObjectId(List<CrObjectInformation> crObjectInformationLi, Long newObjectId) {
        List<CrObjectInformation> updObjectInfoWithNewObjId =
                crObjectInformationLi
                        .stream()
                        .map(objectInfo -> {
                            CrObjectInformation crObjectInformation=new CrObjectInformation();
                            crObjectInformation.setObjectId(newObjectId);
                            crObjectInformation.setInfoType(objectInfo.getInfoType());
                            crObjectInformation.setInfoValue(objectInfo.getInfoValue());
                            crObjectInformation.setInfoDescription(objectInfo.getInfoDescription());
                            crObjectInformation.setAdditionalInformation1(objectInfo.getAdditionalInformation1());
                            crObjectInformation.setAdditionalInformation2(objectInfo.getAdditionalInformation2());
                            crObjectInformation.setAdditionalInformation3(objectInfo.getAdditionalInformation3());
                            crObjectInformation.setAdditionalInformation4(objectInfo.getAdditionalInformation4());
                            crObjectInformation.setAdditionalInformation5(objectInfo.getAdditionalInformation5());
                            crObjectInformation.setCreationDate(new Date());
                            crObjectInformation.setCreatedBy("ConvertRiteAdmin");
                            crObjectInformation.setLastUpdateDate(new Date());
                            crObjectInformation.setLastUpdateBy("ConvertRiteAdmin");
                            return crObjectInformation; // Return the updated objectInfo
                        }).collect(Collectors.toList());
       return  objectInformationRepository.saveAll(updObjectInfoWithNewObjId);
    }

    private CRObject saveCrObjectWithNewName(CRObject crObject, String newObjectName, Long parentObjId, String suffix) {
        CRObject c=new CRObject();
        c.setObjectName(newObjectName);
        c.setObjectCode(newObjectName.trim().replaceAll("\\s+", "_"));
        c.setUserObjectName(newObjectName);
        c.setModuleCode(crObject.getModuleCode());
        if (parentObjId != null) {
            c.setParentObjectId(parentObjId);
        }
        else {
            c.setParentObjectId(crObject.getParentObjectId());
        }
        c.setFbdiSheet(crObject.getFbdiSheet());
        c.setHdlSheet(crObject.getHdlSheet());
        c.setLoaderEndpoint(crObject.getLoaderEndpoint());
        c.setReConQuery(crObject.getReConQuery());
        c.setSequenceInParent(crObject.getSequenceInParent());
        c.setInsertTableName(crObject.getInsertTableName());
        c.setRejectionTableName(crObject.getRejectionTableName());
        c.setCtlFileName(crObject.getCtlFileName());
        c.setXlsmFileName(crObject.getXlsmFileName());
        c.setLastUpdatedBy("ConvertRiteAdmin");
        c.setLastUpdatedDate(new java.sql.Date(new Date().getTime()));
        c.setCreationDate(new java.sql.Date(new Date().getTime()));
        c.setCreatedBy("ConvertRiteAdmin");
        c.setConversionType(crObject.getConversionType());

        if (parentObjId != null) {
            String cldTemplateCode = crObject.getCldTemplateCode() + "_" + suffix;
            String cldTemplateName = "CR_" + cldTemplateCode + "_C";
            String cldMetaDataTblName = "CR_" + cldTemplateCode + "_CLD";

            c.setCldTemplateCode(cldTemplateCode);
            c.setCldTemplateName(cldTemplateName);
            c.setCldMetaDataTableName(cldMetaDataTblName);
        }
        return super.addEntity(objectRepository, c);
    }

    private List<CRTargetInterfaceColumn> saveCRTargetInterfaceColumnWithNewObjectId(Long oldObjectId, Long newObjectId) {
        log.info("Copying Target Interface Column List ... old objectID: {} new objectId: {} ", oldObjectId, newObjectId );
        List<CRTargetInterfaceColumn> targetInterfaceColumns = cRTargetInterfaceColumnRepository.findAllByObjectId(oldObjectId);
        log.info("Existing Target Interface Column Lists size {}  ", targetInterfaceColumns.size());
        ObjectMapper mapper = new ObjectMapper();
        List<CRTargetInterfaceColumn> newTargetInterfaceColumns = targetInterfaceColumns.stream().map(targetInterfaceColumn -> {
            CRTargetInterfaceColumn newTargetInterfaceColumn = mapper.convertValue(targetInterfaceColumn, CRTargetInterfaceColumn.class);
            newTargetInterfaceColumn.setColumnListId(null);
            newTargetInterfaceColumn.setObjectId(newObjectId);
            newTargetInterfaceColumn.setCreationDate(new Date());
            newTargetInterfaceColumn.setCreatedBy("ConvertRiteAdmin");
            newTargetInterfaceColumn.setLastUpdateDate(new Date());
            newTargetInterfaceColumn.setLastUpdatedBy("ConvertRiteAdmin");
            return newTargetInterfaceColumn;
        }).collect(Collectors.toList());
        List<CRTargetInterfaceColumn> result = cRTargetInterfaceColumnRepository.saveAll(newTargetInterfaceColumns);
        log.info("Saved Target Interface Column Lists size {}  ", result.size());
        return result;
    }

    @Transactional
    public BasicResPo copyParentAndChildObjects(CopyObjAndObjectInfoReq cpyObjAndObjInfo) throws Exception {
        log.info("Start of CopyParentAndChildObjects");
        BasicResPo res = new BasicResPo();
        List<CopyObjAndObjectInfoRes> copyObjAndObjectInfoResList = new ArrayList<>();
        CopyParentObjRes copyParentObjRes = new CopyParentObjRes();
        CopyObjAndObjectInfoRes copyObjAndObjectInfoRes;
        List<String> childObjNames = new ArrayList<>();
        String objNameSuffix;

        // Retrieve CRObject based on oldObjectId
        CRObject crObject = super.getEntityById(objectRepository, cpyObjAndObjInfo.getOldObjectId());
        if(crObject == null)
            throw new CRAdminException("Parent object with given id " + cpyObjAndObjInfo.getOldObjectId() + " does not exist");

        String newParentObjectName = crObject.getObjectName().concat("-").concat(cpyObjAndObjInfo.getObjectNameSuffix());
        objNameSuffix = cpyObjAndObjInfo.getObjectNameSuffix();
        log.info("Copying parent object and object information with new name:  {} ", newParentObjectName);
        copyObjAndObjectInfoRes = copyObjectAndObjectInformation(crObject, newParentObjectName, null, objNameSuffix);
        copyObjAndObjectInfoResList.add(copyObjAndObjectInfoRes);
        copyParentObjRes.setParentObjectName(copyObjAndObjectInfoRes.getCrObject().getObjectName());

        log.info("Getting child objects for the old parent object id:  {} ", cpyObjAndObjInfo.getOldObjectId());
        List<CRObject> childObjects = objectRepository.findByParentObjectId(cpyObjAndObjInfo.getOldObjectId());

        log.info("Number of child objects: {} ", childObjects.size());

        log.info("Copying child objects with new name and newly created parent object id");
        Long newParentObjectId = copyObjAndObjectInfoRes.getCrObject().getObjectId();
        String newChildObjectName;
        for (CRObject crObj : childObjects) {
            newChildObjectName = crObj.getObjectName().concat("-").concat(cpyObjAndObjInfo.getObjectNameSuffix());
            objNameSuffix = cpyObjAndObjInfo.getObjectNameSuffix();

            log.info("Copying child object with new name: "+newChildObjectName + " and parent object id: "+newParentObjectId);
            copyObjAndObjectInfoRes = copyObjectAndObjectInformation(crObj, newChildObjectName, newParentObjectId, objNameSuffix);
            copyObjAndObjectInfoResList.add(copyObjAndObjectInfoRes);
            childObjNames.add(copyObjAndObjectInfoRes.getCrObject().getObjectName());
        }

        CRObject childObj;
        List <CrObjectInformation> childObjInfLi;
        for (CopyObjAndObjectInfoRes copyObjRes : copyObjAndObjectInfoResList) {
            childObj = copyObjRes.getCrObject();
            childObjInfLi = copyObjRes.getCrObjectInformationList();
            log.info("Syncing the newly created object data to all pods. Object Name: {} ", childObj.getObjectName());
            dataSyncService.syncObjectDataToAllPods(new ArrayList<>(Collections.singletonList(childObj)), DataSyncService.Operation.INSERT, false);

            log.info("Syncing the newly created object information data to all pods");
            dataSyncService.syncObjectInfoDataToAllPods(childObjInfLi, DataSyncService.Operation.INSERT );

            log.info("Syncing the newly created target interface column data to all pods");
            dataSyncService.syncTargetInterfaceColumnToAllPods(copyObjRes.getCRTargetInterfaceColumns(),DataSyncService.Operation.INSERT );
        }
        copyParentObjRes.setChildObjectNames(childObjNames);
        copyParentObjRes.setCopyObjAndObjectInfoResLi(copyObjAndObjectInfoResList);
        res.setStatusCode(HttpStatus.CREATED);
        res.setStatus("success");
        res.setMessage("Successfully copied parent object and its child objects with a new name");
        res.setPayload(copyParentObjRes);
        return res;
    }

    @Override
    public BasicResPo getObjectsHavingTemplates(Long podId, Long projectId) {
        log.info("Getting Objects having templates for podId: {}, projectId: {} ", podId , projectId);
        BasicResPo res = new BasicResPo();
        Connection conn = null;
        PreparedStatement stmt = null;
        Pod pod = podRepository.findById(podId).get();
        if (pod == null) {
            res.setStatus("error");
            res.setMessage("No Pod exists for the given pod id");
            res.setStatusCode(HttpStatus.EXPECTATION_FAILED);
            return res;
        }
        try {
            log.info("Creating db connection to pod Id :{} ", pod.getPodId());
            conn = DriverManager.getConnection(pod.getPodTargetUrl(), pod.getPodDbUser(), pod.getPodDbPassword());

            String sql ="select DISTINCT object_id from cr_cld_template_hdrs where project_id=? " +
                    "union " +
                    "select DISTINCT object_id from cr_src_template_hdrs where project_id=?";
            log.info(sql);
            stmt = conn.prepareStatement(sql);
            stmt.setLong(1,projectId);
            stmt.setLong(2,projectId);
            ResultSet rs = stmt.executeQuery();

            List<Long> objectsIdLst = new ArrayList<>();

            while (rs.next()) {
                Long objectId = rs.getLong("object_id");
                objectsIdLst.add(objectId);
            }

            log.info("Count of Objects having templates: {} ",objectsIdLst.size());
            if (objectsIdLst.isEmpty()) {
                log.info("No objects having templates found for pod id: {}, project id: {} ", podId , projectId);
                res.setStatus("success");
                res.setMessage("No objects having templates found for pod id: " + podId + ", project id: "+projectId);
                res.setStatusCode(HttpStatus.OK);
            }
            else {
                List<CRObject> crObjectLst = objectRepository.findAllById(objectsIdLst);
                res.setStatus("success");
                res.setMessage("Successfully retrieved objects having templates for pod id: " + podId + ", project id: "+projectId);
                res.setStatusCode(HttpStatus.OK);
                res.setPayload(crObjectLst);
            }
            return res;
        } catch (Exception e) {
            log.info("Error while retrieving objects having templates: ", e);
            res.setStatus("error");
            res.setMessage("Error while retrieving objects having templates for pod id: " + podId + ", project id: "+projectId);
            res.setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
            res.setPayload(e);
            return res;
        } finally {
            try {
                if (stmt != null)
                    stmt.close();
                if (conn != null)
                    conn.close();
            } catch (SQLException se) {
                log.info("Error closing SQL connection and statements: ", se.getMessage());
            }
        }
    }

    @Override
    public BasicResPo getParentObjects() {
        List<CRObject> parentObjList = objectRepository.getParentObjects();
        BasicResPo res = new BasicResPo();
        res.setPayload(parentObjList);
        res.setStatusCode(HttpStatus.OK);
        res.setStatus("success");
        return res;
    }
}