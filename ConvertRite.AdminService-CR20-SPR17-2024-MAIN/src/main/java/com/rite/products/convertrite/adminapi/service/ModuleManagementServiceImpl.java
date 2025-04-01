package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.exception.CRNotFoundException;
import com.rite.products.convertrite.adminapi.exception.CRUniquenessException;
import com.rite.products.convertrite.adminapi.model.CRObject;
import com.rite.products.convertrite.adminapi.model.Module;
import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.ModuleCreationReqPo;
import com.rite.products.convertrite.adminapi.po.ModuleWithObjectsResPo;
import com.rite.products.convertrite.adminapi.po.ObjectBasicResPo;
import com.rite.products.convertrite.adminapi.respository.ModuleRepository;
import com.rite.products.convertrite.adminapi.respository.ObjectRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@RequiredArgsConstructor
@Service
public class ModuleManagementServiceImpl extends BasicManagementService<Module, Long> implements ModuleManagementService {

    @Autowired
    ModuleRepository moduleRepository;

    @Autowired
    ObjectRepository objectRepository;

    @Override
    public BasicResPo createModule(ModuleCreationReqPo moduleCreationReqPo) {

        Module module = new Module();
        module.setModuleName(moduleCreationReqPo.getModuleName());
        module.setModuleCode(moduleCreationReqPo.getModuleCode());
        module.setLastUpdatedBy("ConvertRiteAdmin");
        module.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
        module.setCreationDate(new java.sql.Date(new java.util.Date().getTime()));
        module.setCreatedBy("ConvertRiteAdmin");
        try {
            Module entityRes = super.addEntity(moduleRepository, module);
            Module createdEntity = super.getEntityById(moduleRepository, entityRes.getModuleId());
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CREATED);
                setStatus("success");
                setMessage("Successfully created module " + createdEntity.getModuleName());
                setPayload(createdEntity);
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("ModuleCode " + moduleCreationReqPo.getModuleCode() + " is already available. It should be unique.");
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
    public BasicResPo getModules() {
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved all modules");
            setPayload(moduleRepository.findAll());
        }};
    }

    @Override
    public BasicResPo getModuleTree() {
        List<Module> allModules = moduleRepository.findAll();
        List<CRObject> allObjects = objectRepository.findAll();
        List<ModuleWithObjectsResPo> modulesWithObjects = new ArrayList<>();
        allModules.forEach(module -> {
            String moduleCode = module.getModuleCode();
            ModuleWithObjectsResPo moduleWithObjectsResPo = new ModuleWithObjectsResPo();
            moduleWithObjectsResPo.setModuleId(module.getModuleId());
            moduleWithObjectsResPo.setModuleName(module.getModuleName());
            moduleWithObjectsResPo.setModuleCode(moduleCode);
            List<ObjectBasicResPo> objectBasicResPos = new ArrayList<>();
            allObjects.forEach(crObject -> {
                if (moduleCode.equals(crObject.getModuleCode())) {
                    ObjectBasicResPo objectBasicResPo = new ObjectBasicResPo();
                    objectBasicResPo.setObjectId(crObject.getObjectId());
                    objectBasicResPo.setObjectCode(crObject.getObjectCode());
                    objectBasicResPo.setObjectName(crObject.getObjectName());
                    objectBasicResPos.add(objectBasicResPo);
                }
            });
            moduleWithObjectsResPo.setCrObjects(objectBasicResPos);
            modulesWithObjects.add(moduleWithObjectsResPo);
        });
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved all modules with objects");
            setPayload(modulesWithObjects);
        }};
    }

    @Override
    public BasicResPo getModuleById(Long moduleId) {
        try {
            Module module = super.getEntityById(moduleRepository, moduleId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get module with id " + moduleId);
                setPayload(module);
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Module with id " + moduleId + " is not found");
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
    public BasicResPo putModuleById(Long moduleId, ModuleCreationReqPo moduleCreationReqPo) {
        try {
            Module module = super.getEntityById(moduleRepository, moduleId);
            if (moduleCreationReqPo.getModuleName() != null && moduleCreationReqPo.getModuleName().length() > 0) {
                module.setModuleName(moduleCreationReqPo.getModuleName());
            }
            if (moduleCreationReqPo.getModuleCode() != null && moduleCreationReqPo.getModuleCode().length() > 0) {
                module.setModuleCode(moduleCreationReqPo.getModuleCode());
            }
            module.setLastUpdatedBy("ConvertRiteAdmin");
            module.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
            Module updatedEntity = super.updateEntity(moduleRepository, module);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully updated module " + updatedEntity.getModuleName());
                setPayload(updatedEntity);
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Module with id " + moduleId + " is not found");
                setPayload(ex);
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("ModuleCode " + moduleCreationReqPo.getModuleCode() + " is already available. It should be unique.");
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
    public BasicResPo deleteModuleById(Long moduleId) {
        try {
            Module moduleEntity = super.getEntityById(moduleRepository, moduleId);
            super.deleteEntityById(moduleRepository, moduleId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully deleted module with name " + moduleEntity.getModuleName());
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Module with id " + moduleId + " not exists to delete");
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
}
