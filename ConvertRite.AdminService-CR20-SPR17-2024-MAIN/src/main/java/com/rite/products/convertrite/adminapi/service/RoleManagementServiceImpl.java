package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.exception.CRNotFoundException;
import com.rite.products.convertrite.adminapi.exception.CRUniquenessException;
import com.rite.products.convertrite.adminapi.model.*;
import com.rite.products.convertrite.adminapi.po.*;
import com.rite.products.convertrite.adminapi.respository.PodRepository;
import com.rite.products.convertrite.adminapi.respository.RoleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@RequiredArgsConstructor
@Service
public class RoleManagementServiceImpl extends BasicManagementService<Role, Long> implements RoleManagementService {

    @Autowired
    RoleRepository roleRepository;

    @Autowired
    PodRepository podRepository;

    @Override
    public BasicResPo createRole(RoleCreationReqPo roleCreationReqPo) {
        try {
            Role r = new Role();
            r.setRoleName(roleCreationReqPo.getRoleName());
            r.setDescription(roleCreationReqPo.getDescription());
            Client c = new Client();
            c.setClientId(roleCreationReqPo.getClientId());
            r.setClient(c);
            Pod pod = new Pod();
            pod.setPodId(roleCreationReqPo.getPodId());
            r.setPod(pod);
            if (roleCreationReqPo.getObjectIds() != null) {
                Set<CRObject> crObjects = new HashSet<CRObject>();
                for (Long objectId : roleCreationReqPo.getObjectIds()) {
                    CRObject cr = new CRObject();
                    cr.setObjectId(objectId);
                    crObjects.add(cr);
                }
                r.setObjects(crObjects);
            }
            r.setLastUpdatedBy("ConvertRiteAdmin");
            r.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
            r.setCreationDate(new java.sql.Date(new java.util.Date().getTime()));
            r.setCreatedBy("ConvertRiteAdmin");
            Role entityRes = super.addEntity(roleRepository, r);
            Role createdEntity = super.getEntityById(roleRepository, entityRes.getRoleId());
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CREATED);
                setStatus("success");
                setMessage("Successfully created role " + createdEntity.getRoleName());
                setPayload(generateResPo(createdEntity));
            }};
        } catch (
                CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("Role name " + roleCreationReqPo.getRoleName() + " is already available. It should be unique.");
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
    public BasicResPo getRoles(Long clientId, Long podId) {
        List<Role> roles = new ArrayList<>();
        if (podId != null && podId != 0) {
            roles = roleRepository.findAllByPodId(podId);
        } else {
            roles = roleRepository.findAllByClientId(clientId);
        }
        List<RoleResPo> res = new ArrayList<>();
        if (roles != null) {
            for (Role role : roles) {
                res.add(generateResPo(role));
            }
            ;
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved all roles");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getRoleById(Long roleId) {
        try {
            Role role = super.getEntityById(roleRepository, roleId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get role with id " + roleId);
                setPayload(generateResPo(role));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Role with id " + roleId + " is not found");
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
    public BasicResPo putRoleById(Long roleId, RoleCreationReqPo roleCreationReqPo) {
        try {
            Role role = roleRepository.findById(roleId).get();
            role.setRoleName(roleCreationReqPo.getRoleName());
            role.setDescription(roleCreationReqPo.getDescription());
            if (roleCreationReqPo.getPodId() != null) {
                Pod pod = new Pod();
                pod.setPodId(roleCreationReqPo.getPodId());
                role.setPod(pod);
            }
            if (roleCreationReqPo.getObjectIds() != null) {
                Set<CRObject> crObjects = new HashSet<CRObject>();
                for (Long objectId : roleCreationReqPo.getObjectIds()) {
                    CRObject cr = new CRObject();
                    cr.setObjectId(objectId);
                    crObjects.add(cr);
                }
                role.setObjects(crObjects);
            }
            role.setLastUpdatedBy("ConvertRiteAdmin");
            role.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
            Role updatedEntity = super.updateEntity(roleRepository, role);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully updated role " + updatedEntity.getRoleName());
                setPayload(generateResPo(updatedEntity));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Role with id " + roleId + " is not found");
                setPayload(ex);
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("Role name " + roleCreationReqPo.getRoleName() + " is already available. It should be unique.");
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
    public BasicResPo deleteRoleById(Long roleId) {
        try {
            Role role = super.getEntityById(roleRepository, roleId);
            super.deleteEntityById(roleRepository, roleId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully deleted role with name " + role.getRoleName());
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Role with id " + roleId + " not exists to delete");
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

    private RoleResPo generateResPo(Role r) {
        RoleResPo res = new RoleResPo();
        res.setRoleId(r.getRoleId());
        res.setRoleName(r.getRoleName());
        res.setDescription(r.getDescription());
        ClientResPo c = new ClientResPo();
        if (r.getClient() != null) {
            c.setClientId(r.getClient().getClientId());
            c.setClientName(r.getClient().getClientName());
        }
        res.setClient(c);
        PodBasicResPo podResPo = new PodBasicResPo();
        if (r.getPod() != null) {
            podResPo.setPodId(r.getPod().getPodId());
            podResPo.setPodName(r.getPod().getPodName());
        }
        res.setPod(podResPo);
        if (r.getObjects() != null) {
            List<Long> crObjectIds = new ArrayList<Long>();
            for (CRObject crObject : r.getObjects()) {
                crObjectIds.add(crObject.getObjectId());
            }
            res.setObjectIds(crObjectIds);
        }
        return res;
    }
}
