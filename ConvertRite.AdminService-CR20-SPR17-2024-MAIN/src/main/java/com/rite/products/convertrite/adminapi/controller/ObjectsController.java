package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.CopyObjAndObjectInfoReq;
import com.rite.products.convertrite.adminapi.po.CrObjectInformationCreateReqPo;
import com.rite.products.convertrite.adminapi.po.ObjectCreationReqPo;
import com.rite.products.convertrite.adminapi.service.ObjectManagementService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;

@RestController
@Tag(name = "03. Objects", description = "APIs for objects")
@Slf4j
@RequestMapping("/api/convertriteadmin")
public class ObjectsController {

    @Autowired
    ObjectManagementService objectManagementService;

    @PostMapping("/objects")
    public ResponseEntity<BasicResPo> createObject(@RequestBody ObjectCreationReqPo objectCreationReqPo) {
        BasicResPo response = objectManagementService.createObject(objectCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/objects")
    public ResponseEntity<BasicResPo> getObjects(@RequestParam(name = "module_code", required = false) String moduleCode,@RequestParam(name = "client_id", required = false)Long client_Id) {
        BasicResPo response = objectManagementService.getObjects(moduleCode,client_Id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/objects/{object_id}")
    public ResponseEntity<BasicResPo> getObject(@PathVariable Long object_id) {
        BasicResPo response = objectManagementService.getObjectById(object_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/getObjectsByUserId/{userId}")
    public ResponseEntity<BasicResPo> getObjectsByUserId(@PathVariable Long userId) {
        BasicResPo response = objectManagementService.getObjectsByUserId(userId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/objects/{object_id}/objectinformation")
    public ResponseEntity<BasicResPo> getObjectInformation(@PathVariable Long object_id) {
        BasicResPo response = objectManagementService.getObjectInformationByObjectId(object_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PostMapping("/objects/{object_id}/saveallobjectinformation")
    public ResponseEntity<BasicResPo> saveAllObjectInformation(@RequestBody ArrayList<CrObjectInformationCreateReqPo> valueList,
                                                  @PathVariable Long object_id) {
        BasicResPo response = objectManagementService.saveAllObjectInformationByObjectId(valueList, object_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PutMapping("/objects/{object_id}")
    public ResponseEntity<BasicResPo> putObject(@PathVariable Long object_id, @RequestBody ObjectCreationReqPo objectCreationReqPo) {
        BasicResPo response = objectManagementService.putObjectById(object_id, objectCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @DeleteMapping("/objects/{object_id}")
    public ResponseEntity<BasicResPo> deleteObject(@PathVariable Long object_id) {
        BasicResPo response = objectManagementService.deleteObjectById(object_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/getPodsLinkedWithObjects/{objectId}")
    public ResponseEntity<BasicResPo> getPodsLinkedWithObjects(@PathVariable Long objectId) {
        BasicResPo response = objectManagementService.getPodsLinkedWithObjects(objectId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/getParentObjects")
    public ResponseEntity<BasicResPo> getParentObjects(@RequestParam Long userId,@RequestParam Long projectId) {
        BasicResPo response = objectManagementService.getParentObjects(userId,projectId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/getObjectsWithInformation")
    public ResponseEntity<BasicResPo> getObjectsWithInformation(@RequestParam Long podId,@RequestParam List<Long> objectId) {
        BasicResPo response = objectManagementService.getObjectsWithInformation(podId, objectId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/getobjectshavingtemplates")
    public ResponseEntity<BasicResPo> getObjectsWithTemplates(@RequestParam Long podId, @RequestParam Long projectId) {
        BasicResPo response = objectManagementService.getObjectsHavingTemplates(podId, projectId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/auth/getObjectsWithInformation")
    public ResponseEntity<BasicResPo> getObjectsWithInformationWithOutAuth(@RequestParam Long podId,@RequestParam List<Long> objectId) {
        BasicResPo response = objectManagementService.getObjectsWithInformation(podId, objectId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/getSequence")
    public ResponseEntity<BasicResPo> getSequenceOfObjects(@RequestParam long parentObjectId) {
        BasicResPo response = objectManagementService.getSequence(parentObjectId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PostMapping("/copyparentandchildobjects")
    public ResponseEntity<BasicResPo> copyParentAndChildObjects(@Valid @RequestBody CopyObjAndObjectInfoReq cpyObjAndObjInfo) throws Exception {
        return new ResponseEntity<>(objectManagementService.copyParentAndChildObjects(cpyObjAndObjInfo), HttpStatus.OK);
    }

    @GetMapping("/parentObjects")
    public ResponseEntity<BasicResPo> getParentObjects() {
        BasicResPo response = objectManagementService.getParentObjects();
        return new ResponseEntity<>(response, response.getStatusCode());
    }

}