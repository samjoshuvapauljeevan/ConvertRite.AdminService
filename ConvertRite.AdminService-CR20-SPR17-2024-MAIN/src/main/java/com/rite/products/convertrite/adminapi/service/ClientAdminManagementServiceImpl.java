package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.exception.CRNotFoundException;
import com.rite.products.convertrite.adminapi.exception.CRUniquenessException;
import com.rite.products.convertrite.adminapi.model.*;
import com.rite.products.convertrite.adminapi.model.Module;
import com.rite.products.convertrite.adminapi.po.*;
import com.rite.products.convertrite.adminapi.respository.CREmailNotificationRepository;
import com.rite.products.convertrite.adminapi.respository.ClientAdminRepository;
import com.rite.products.convertrite.adminapi.respository.ModuleRepository;
import com.rite.products.convertrite.adminapi.utils.Constants;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Date;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static com.rite.products.convertrite.adminapi.utils.PasswordUtils.isValid;

@RequiredArgsConstructor
@Service
@Slf4j
@Transactional
public class ClientAdminManagementServiceImpl extends BasicManagementService<ClientAdmin, Long> implements ClientAdminManagementService {

    @Value("${spring.mail.username}")
    private String fromEmail;

    @Autowired
    ClientAdminRepository clientAdminRepository;

    @Autowired
    ModuleRepository moduleRepository;

    @Autowired
    PasswordEncoder encoder;

    @Autowired
    CREmailNotificationRepository crEmailNotificationRepository;

    public ResponseEntity<CREmailNotifications> saveCrEmailNotifications(String toEmail , String fromEmail , String subject , String status , String role){
        CREmailNotifications notification = new CREmailNotifications();
        notification.setToEmail(toEmail);
        notification.setFromEmail(fromEmail);
        notification.setSubject(subject);
        notification.setStatus(status);
        notification.setRole(role);
        notification.setCreatedBy("");
        notification.setCreationDate(new java.sql.Date(new java.util.Date().getTime()));
        notification.setLastUpdateDate(new java.sql.Date(new java.util.Date().getTime()));
        notification.setLastUpdatedBy("");
        CREmailNotifications savedNotification = crEmailNotificationRepository.save(notification);
        return ResponseEntity.ok(savedNotification);

    }

    @Autowired
    private EmailService emailService;
    @Override
    public BasicResPo createClientAdmin(ClientAdminCreationReqPo clientAdminCreationReqPo) {
        ClientAdmin c = new ClientAdmin();
        Client client = new Client();
        String defaultGeneratedPwd=null;
        client.setClientId(clientAdminCreationReqPo.getClientId());
        c.setClient(client);
        c.setClientAdminName(clientAdminCreationReqPo.getClientAdminName());
        c.setClientAdminUserName(clientAdminCreationReqPo.getClientAdminUserName());
        c.setIsFirstTimeLogin(true);

        if (clientAdminCreationReqPo.getPodIds() != null) {
            Set<Pod> pods = new HashSet<Pod>();
            for (Long podId : clientAdminCreationReqPo.getPodIds()) {
                Pod p = new Pod();
                p.setPodId(podId);
                pods.add(p);
            }
            c.setPods(pods);
        }
        c.setLastUpdatedBy("ConvertRiteAdmin");
        c.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
        c.setCreationDate(new java.sql.Date(new java.util.Date().getTime()));
        c.setCreatedBy("ConvertRiteAdmin");

        try {
            ClientAdmin entityRes = super.addEntity(clientAdminRepository, c);
            ClientAdmin createdEntity = super.getEntityById(clientAdminRepository, entityRes.getClientAdminId());
            saveCrEmailNotifications(createdEntity.getClientAdminUserName(),fromEmail,Constants.PSD_UPDATE_SUBJECT, CREmailNotificationsStatus.NEW.toString(),"clientAdmin");
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CREATED);
                setStatus("success");
                setMessage("Successfully created user " + createdEntity.getClientAdminName() + ". A temporary password has been sent to " + createdEntity.getClientAdminName() + " successfully. Please check your mail.");
                setPayload(generateResPo(createdEntity));
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("Client admin username " + clientAdminCreationReqPo.getClientAdminUserName() + " is already available. It should be unique.");
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
    public BasicResPo getClientAdmins() {
        log.info("==============getClientAdmins===========");
        List<ClientAdmin> cas = clientAdminRepository.findByOrderByClientAdminIdAsc();
        List<ClientAdminResPo> res = new ArrayList<>();
        if (cas != null) {
            for (ClientAdmin ca : cas) {
                res.add(generateResPo(ca));
            }
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved all client admins");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getClientAdminById(Long clientAdminId) {
        try {
            ClientAdmin clientAdmin = super.getEntityById(clientAdminRepository, clientAdminId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get client admin with id " + clientAdminId);
                setPayload(generateResPo(clientAdmin));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Client admin with id " + clientAdminId + " is not found");
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
    public BasicResPo getLicensedPodsByClientAdminId(Long clientAdminId) {
        try {
            ClientAdmin clientAdmin = super.getEntityById(clientAdminRepository, clientAdminId);
            Date currentDate = new Date(System.currentTimeMillis());
            List<Pod> validPods = clientAdmin.getPods().stream().filter(pod ->
                currentDate.before(pod.getLicense().getEffectiveEndDate())
            ).toList();

            List<PodBasicResPo> res = new ArrayList<>();
            if (validPods != null) {
                for (Pod p : validPods) {
                    res.add(generatePodResPo(p));
                }
                ;
            }

            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get licensed pods for client admin with id " + clientAdminId);
                setPayload(res);
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Client admin with id " + clientAdminId + " is not found");
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
    public BasicResPo putClientAdminById(Long clientAdminId, ClientAdminCreationReqPo clientAdminCreationReqPo) {
        try {
            ClientAdmin c = clientAdminRepository.findById(clientAdminId).get();
            if (clientAdminCreationReqPo.getClientId() != null) {
                Client client = new Client();
                client.setClientId(clientAdminCreationReqPo.getClientId());
                c.setClient(client);
            }

            if (clientAdminCreationReqPo.getClientAdminPassword() != null && clientAdminCreationReqPo.getClientAdminPassword().length() > 0) {
                c.setClientAdminPassword(encoder.encode(clientAdminCreationReqPo.getClientAdminPassword()));
                c.setIsFirstTimeLogin(false);
            }

            boolean isEmailExists = clientAdminRepository.existsByClientAdminUserName(clientAdminCreationReqPo.getClientAdminUserName());
            if (isEmailExists) {

            if (clientAdminCreationReqPo.getPodIds() != null) {
                Set<Pod> pods = new HashSet<Pod>();
                for (Long podId : clientAdminCreationReqPo.getPodIds()) {
                    Pod p = new Pod();
                    p.setPodId(podId);
                    pods.add(p);
                }
                c.setPods(pods);
            }

            c.setClientAdminName(clientAdminCreationReqPo.getClientAdminName());
            c.setClientAdminUserName(clientAdminCreationReqPo.getClientAdminUserName());
            c.setLastUpdatedBy("ConvertRiteAdmin");
            c.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
            ClientAdmin updatedEntity = super.updateEntity(clientAdminRepository, c);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully updated module " + updatedEntity.getClientAdminName());
                setPayload(generateResPo(updatedEntity));
            }};
        }
        c.setIsFirstTimeLogin(true);
        saveCrEmailNotifications(clientAdminCreationReqPo.getClientAdminUserName(), fromEmail, Constants.PSD_UPDATE_SUBJECT, CREmailNotificationsStatus.NEW.toString(),"clientAdmin");

            if (clientAdminCreationReqPo.getPodIds() != null) {
                Set<Pod> pods = new HashSet<Pod>();
                for (Long podId : clientAdminCreationReqPo.getPodIds()) {
                    Pod p = new Pod();
                    p.setPodId(podId);
                    pods.add(p);
                }
                c.setPods(pods);
            }

            c.setClientAdminName(clientAdminCreationReqPo.getClientAdminName());
            c.setClientAdminUserName(clientAdminCreationReqPo.getClientAdminUserName());
            c.setLastUpdatedBy("ConvertRiteAdmin");
            c.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
            ClientAdmin updatedEntity = super.updateEntity(clientAdminRepository, c);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Please check your mail after some time for temporary password which needs to be reset.");
                setPayload(generateResPo(updatedEntity));
            }};
    } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Client admin with id " + clientAdminId + " is not found");
                setPayload(ex);
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("Client admin username " + clientAdminCreationReqPo.getClientAdminUserName() + " is already available. It should be unique.");
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
    public BasicResPo deleteClientAdminById(Long clientAdminId) {
        try {
            ClientAdmin clientAdmin = super.getEntityById(clientAdminRepository, clientAdminId);
            super.deleteEntityById(clientAdminRepository, clientAdminId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully deleted client admin with name " + clientAdmin.getClientAdminName());
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Client admin with id " + clientAdminId + " not exists to delete");
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
    public BasicResPo getClientAdminModulesByAdminId(Long clientAdminId) {
        try {
            ClientAdmin clientAdmin = super.getEntityById(clientAdminRepository, clientAdminId);
            List<String> modules = new ArrayList<>();
            List<Long> objectIds = new ArrayList<>();
            List<CRObject> objects = new ArrayList<>();
            clientAdmin.getPods().forEach(pod ->{
                pod.getLicense().getObjects().forEach(crObject -> {
                    if (!modules.contains(crObject.getModuleCode())) {
                        modules.add(crObject.getModuleCode());
                    }
                    if(!objectIds.contains(crObject.getObjectId())){
                        objectIds.add(crObject.getObjectId());
                        objects.add(crObject);
                    }
                });
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
                    objects.forEach(crObject -> {
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
                setMessage("Successfully get client admin modules with id " + clientAdminId);
                setPayload(res);
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Client Admin with id " + clientAdminId + " is not found");
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
    public BasicResPo getClientAdminObjectsByAdminId(Long clientAdminId, String moduleCode) {
        try {
            List<CRObject> res;
            ClientAdmin clientAdmin = super.getEntityById(clientAdminRepository, clientAdminId);
            List<Long> objectIds = new ArrayList<>();
            List<CRObject> objects = new ArrayList<>();
            clientAdmin.getPods().forEach(pod ->{
                pod.getLicense().getObjects().forEach(crObject -> {
                    if (moduleCode != null && moduleCode.length() > 0) {
                        if(crObject.getModuleCode().equals(moduleCode) && !objectIds.contains(crObject.getObjectId())){
                            objectIds.add(crObject.getObjectId());
                            objects.add(crObject);
                        }
                    }
                    else if(!objectIds.contains(crObject.getObjectId())){
                        objectIds.add(crObject.getObjectId());
                        objects.add(crObject);
                    }
                });
            });
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully got client admin objects with clientadmin id " + clientAdminId);
                setPayload(objects);
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Client admin with id " + clientAdminId + " is not found");
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
    public BasicResPo updateClientAdminPwd(ResetPasswordPo resetPasswordPo) {
       try {
           log.info("Start of Update Password Method ===>");
          boolean isPasswordValid= isValid(resetPasswordPo.getClientAdminPassword());
          if(!isPasswordValid){
              throw new Exception("Password is invalid. It should contain at least 8 characters, including at least one number, one uppercase letter, and one lowercase letter.");
          }
           ClientAdmin clientAdmin = clientAdminRepository.findByClientAdminUserName(resetPasswordPo.getEmailId());
               clientAdmin.setClientAdminPassword(encoder.encode(resetPasswordPo.getClientAdminPassword()));
               clientAdmin.setIsFirstTimeLogin(false);
           return new BasicResPo() {{
               setStatusCode(HttpStatus.OK);
               setStatus("success");
               setMessage("Successfully UpdatedClient Admin Password for " + resetPasswordPo.getEmailId());
               setPayload(null);
           }};

       }catch (Exception ex){
           log.error("error : {} ", ex.getMessage(), ex);
           return new BasicResPo() {{
               setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
               setStatus("error");
               setMessage(ex.getMessage());
               setPayload(ex);
           }};
       }
    }

    private ClientAdminResPo generateResPo(ClientAdmin ca) {
        ClientAdminResPo res = new ClientAdminResPo();
        res.setClientAdminId(ca.getClientAdminId());
        ClientResPo c = new ClientResPo();
        if (ca.getClient() != null) {
            c.setClientId(ca.getClient().getClientId());
            c.setClientName(ca.getClient().getClientName());
        }
        res.setClient(c);
        res.setClientAdminName(ca.getClientAdminName());
        res.setClientAdminUserName(ca.getClientAdminUserName());
        res.setClientAdminPassword(ca.getClientAdminPassword());
        if (ca.getPods() != null) {
            List<PodBasicResPo> pods = new ArrayList<PodBasicResPo>();
            for (Pod pod : ca.getPods()) {
                PodBasicResPo podResPo = new PodBasicResPo();
                podResPo.setPodId(pod.getPodId());
                podResPo.setPodName(pod.getPodName());
                pods.add(podResPo);
            }
            res.setPods(pods);
        }
        return res;
    }

    private PodBasicResPo generatePodResPo(Pod pod){
        PodBasicResPo podResPo = new PodBasicResPo();
        podResPo.setPodId(pod.getPodId());
        podResPo.setPodName(pod.getPodName());
        return podResPo;
    }
}
