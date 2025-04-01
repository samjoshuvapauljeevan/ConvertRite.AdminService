package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.CopyObjAndObjectInfoReq;
import com.rite.products.convertrite.adminapi.po.CrObjectInformationCreateReqPo;
import com.rite.products.convertrite.adminapi.po.ObjectCreationReqPo;

import java.util.ArrayList;
import java.util.List;

public interface ObjectManagementService {

    BasicResPo createObject(ObjectCreationReqPo objectCreationReqPo);

    BasicResPo getObjects(String moduleCode, Long clientId);

    BasicResPo getObjectById(Long objectId);

    BasicResPo getObjectInformationByObjectId(Long objectId);

    BasicResPo saveAllObjectInformationByObjectId(ArrayList<CrObjectInformationCreateReqPo> objectInformationReqPoList, Long objectId);

    BasicResPo putObjectById(Long objectId, ObjectCreationReqPo objectCreationReqPo);

    BasicResPo getPodsLinkedWithObjects(Long objectId);

    BasicResPo deleteObjectById(Long objectId);

    BasicResPo getParentObjects(Long userId, Long projectId);

    BasicResPo getObjectsByUserId(Long userId);

    BasicResPo getObjectsWithInformation( Long podId, List<Long> objectId);

    BasicResPo getObjectsHavingTemplates(Long podId, Long projectId);

    BasicResPo getSequence(long parentObjectId);

    BasicResPo copyParentAndChildObjects(CopyObjAndObjectInfoReq cpyObjAndObjInfo) throws Exception;

    BasicResPo getParentObjects();
}