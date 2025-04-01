package com.rite.products.convertrite.adminapi.service;


import java.util.*;
import java.util.stream.Collectors;

import com.rite.products.convertrite.adminapi.exception.CRNotFoundException;
import com.rite.products.convertrite.adminapi.po.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.rite.products.convertrite.adminapi.model.CRCloudImportObjectLink;
import com.rite.products.convertrite.adminapi.model.CRLicensedObjects;
import com.rite.products.convertrite.adminapi.model.CRObject;
import com.rite.products.convertrite.adminapi.model.CloudLogin;
import com.rite.products.convertrite.adminapi.model.Pod;
import com.rite.products.convertrite.adminapi.respository.CRCloudImportObjectLinkRepository;
import com.rite.products.convertrite.adminapi.respository.CRLicensedObjectsRepository;
import com.rite.products.convertrite.adminapi.respository.ObjectRepository;
import com.rite.products.convertrite.adminapi.respository.PodCloudConfigRepository;
import com.rite.products.convertrite.adminapi.respository.PodRepository;


import lombok.extern.slf4j.Slf4j;

@Service
@Slf4j
public class PodCloudConfigServiceImpl extends BasicManagementService<CloudLogin, Long> implements PodCloudConfigService {
    @Autowired
    PodCloudConfigRepository podCloudConfigRepo;
    @Autowired
    PodRepository podRepository;
    @Autowired
    ObjectRepository objectRepository;
    @Autowired
    CRLicensedObjectsRepository cRLicensedObjRepo;
    @Autowired
    CRCloudImportObjectLinkRepository cRCloudImportObjLinkRepo;

    public BasicResPo createPodCloudConfig(PodCloudConfigReqPo req) {
        List<CloudLogin> cloudLogins = new ArrayList<>();
        List<CRCloudImportObjectLink> crCloudImportObjectLinkList = new ArrayList<>();
        try {
            log.info("inside try block");

            Pod pod = podRepository.findById(req.getPodId()).get();
            List<CRLicensedObjects> crLicensedObjList = null;
            log.info("pod.getLicense().getLicenseId()--> {} ", pod.getLicense().getLicenseId());
            if (pod.getLicense() != null) {
                crLicensedObjList = cRLicensedObjRepo.findAllByLicenseId(pod.getLicense().getLicenseId());
                log.info("crLicensedObjList size --> {} ", crLicensedObjList.size());
            }
            List<CRObject> crObjList = objectRepository.findAll();
            List<CRObject> filtedList = null;
            List<ModulesReqPo> list = req.getModules();

            if (req.getIsUpdate() == true) {
                List<CloudLogin> listOfCL = podCloudConfigRepo.findAllByClientIdAndPodId(req.getClientId(), req.getPodId());
                if (listOfCL.size() > 0) {
                    podCloudConfigRepo.deleteAllByClientIdAndPodId(req.getClientId(), req.getPodId());
                    listOfCL.forEach(item -> {
                        log.info("item.getCredentialId()--> {} ", item.getCredentialId());
                        cRCloudImportObjLinkRepo.deleteAllByCredentialId(item.getCredentialId());
                    });
                }else {
                    log.info("====else====");
                }
            }
            // Looping Given List of Modules
            for (ModulesReqPo mod : list) {
                log.info("mod--> {} ", mod.getModuleCode());
                //  boolean isDuplicatesFound= checkForDuplicates(req.getClient_id(),req.getPod_id(),mod.getModuleCode());

                CloudLogin cloudLogin = new CloudLogin();
                cloudLogin.setClientId(req.getClientId());
                cloudLogin.setPodId(req.getPodId());
                cloudLogin.setUrl(req.getUrl());
                cloudLogin.setModuleCode(mod.getModuleCode());
                cloudLogin.setUsername(mod.getUserName());
                cloudLogin.setPassword(mod.getPassword());
                cloudLogin.setCreation_date(new java.sql.Date(new java.util.Date().getTime()));
                cloudLogin.setCreated_by("ConvertRiteAdmin");
                CloudLogin clLogin = podCloudConfigRepo.save(cloudLogin);
                // Filterd CRObjectids Based ModuleCode
                if (mod.getModuleCode().equals("All")) {
                    filtedList = crObjList;
                }
                // Filtered CRObjectids Based on ModuleCode
                filtedList = crObjList.stream().filter(str -> str.getModuleCode().equals(mod.getModuleCode()))
                        .collect(Collectors.toList());
                log.info("filtedList--> {} ", filtedList.size());
                // Filter filtered list for Licensed Object ids
                for (CRObject crObj : filtedList) {
                    for (CRLicensedObjects crLicensedObj : crLicensedObjList) {

                        if (crObj.getObjectId() == crLicensedObj.getObject_id()) {
                            // log.info(crObj.getObjectId() + "==" + crLicensedObj.getObject_id());

                            CRCloudImportObjectLink cRCloudImportObjLink = new CRCloudImportObjectLink();
                            // CloudLogin clLogin = podCloudConfigRepo.save(cloudLogin);
                            // log.info("clLogin.getCredential_id()-->" + clLogin.getCredentialId());
                            cloudLogin.setCredentialId(clLogin.getCredentialId());
                            cRCloudImportObjLink.setCredentialId(clLogin.getCredentialId());
                            cRCloudImportObjLink.setObjectId(crObj.getObjectId());
                            cRCloudImportObjLink.setCreation_date(new java.sql.Date(new java.util.Date().getTime()));
                            cRCloudImportObjLink.setCreated_by("ConvertRiteAdmin");

                            crCloudImportObjectLinkList.add(cRCloudImportObjLink);
                        }
                    }
                }
                cloudLogins.add(cloudLogin);
            }
            cRCloudImportObjLinkRepo.saveAll(crCloudImportObjectLinkList);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CREATED);
                setStatus("success");
                setMessage("Successfully created pod cloud configuration");
                setPayload(cloudLogins);
            }};
        } catch (Exception ex) {
            ex.printStackTrace();
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    public BasicResPo getAllPodCloudConfigs() {
        List<CloudLogin> podCloudConfigList = podCloudConfigRepo.findAll();
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved PodCloud Config Details");
            setPayload(generateResPo(podCloudConfigList));
        }};
    }

    public BasicResPo getAllPodCloudConfigs(Long clientId) {

        BasicResPo res = new BasicResPo();
        try {
            log.info("client--> {} ", clientId);
            List<CloudLogin> podCloudConfigList = podCloudConfigRepo.findAllByClientId(clientId);
            log.info("podCloudConfigList.size()--> {} ", podCloudConfigList.size());

            res.setStatusCode(HttpStatus.OK);
            res.setStatus("success");
            res.setMessage("Successfully retrieved PodCloud Config Details");
            res.setPayload(generateResPo(podCloudConfigList));
            if (podCloudConfigList.size() == 0) {
                res.setStatusCode(HttpStatus.NOT_FOUND);
                res.setStatus("error");
                res.setMessage("PodCloud Config Details Not Found");
                res.setPayload(null);
            }
        } catch (Exception e) {
            e.printStackTrace();
            res.setStatusCode(HttpStatus.NOT_FOUND);
            res.setStatus("error");
            res.setMessage("Error in  retrieving PodCloud Config Details");
            res.setPayload(null);
        }
        return res;
    }

    public BasicResPo getPodCloudConfigsByClientId(Long clientId) {
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved objects");
            setPayload(podCloudConfigRepo.findAllByClientId(clientId));
        }};
    }

    public BasicResPo deletePodCloudConfig(Long clientId, Long podId) {
        try {
            List<CloudLogin> listOfCL = podCloudConfigRepo.findAllByClientIdAndPodId(clientId, podId);
            if (listOfCL.size() > 0) {
                for (CloudLogin cl : listOfCL) {
                    podCloudConfigRepo.deleteById(Math.toIntExact(cl.getCredentialId()));
                    cRCloudImportObjLinkRepo.deleteAllByCredentialId(cl.getCredentialId());
                }
            }
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Pod Cloud Config Deleted Successfully");
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Cloud config with id " + podId + " not exists to delete");
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

    private Object generateResPo(List<CloudLogin> podCloudConfigList) {
        HashSet<PodCloudConfigReqPo1> list4 = new HashSet<>();
        try {
            List<GetAllPodCloudConfigsResPo> list = new ArrayList<GetAllPodCloudConfigsResPo>();
            ObjectMapper mapper = new ObjectMapper();
            mapper.disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);

            Map<Long, Map<Long, List<CloudLogin>>> multipleFieldsMapList = podCloudConfigList.stream()
                    .collect(
                            Collectors.groupingBy(CloudLogin::getClientId,
                                    Collectors.groupingBy(CloudLogin::getPodId)));
            HashSet<CloudLogin> set = new HashSet<>();
            podCloudConfigList.forEach(obj -> {
                //log.info("obj.getClientId()+obj.getPodId()---->" + obj.getClientId() + obj.getPodId());
                CloudLogin cloudLogin = new CloudLogin();
                cloudLogin.setClientId(obj.getClientId());
                cloudLogin.setPodId(obj.getPodId());
                set.add(cloudLogin);
            });

            HashSet<PodCloudConfigReqPo1> finalresSet = new HashSet<>();

            Map<String, Object> map = new HashMap();
            List list5 = new ArrayList<>();
            for (CloudLogin obj : set) {
               // log.info("obj.getClientId()+obj.getPodId()---->" + obj.getClientId() + obj.getPodId());
                CloudLogin cloudLogin = new CloudLogin();
                cloudLogin.setClientId(obj.getClientId());
                cloudLogin.setPodId(obj.getPodId());
                set.add(cloudLogin);
                List<CloudLogin> list2 = multipleFieldsMapList.get(obj.getClientId()).get(obj.getPodId());

                List list3 = new ArrayList();
                if (list2.size() > 1) {
                    PodCloudConfigReqPo1 res = new PodCloudConfigReqPo1();
                    for (CloudLogin cl : list2) {
                        ModulesReqPo mreq = new ModulesReqPo();
                        mreq.setModuleCode(cl.getModuleCode());
                        mreq.setUserName(cl.getUsername());
                        mreq.setPassword(cl.getPassword());
                        list3.add(mreq);
                        // PodCloudConfigReqPo1 res = new PodCloudConfigReqPo1();
                        res.setCredentialId(cl.getCredentialId());
                        res.setPodId(cl.getPodId());
                        res.setPodDbUserName(cl.getUsername());
                        res.setModules(list3);
                        res.setClientId(cl.getClientId());
                        res.setUrl(cl.getUrl());
                        Optional<Pod> res2 = podRepository.findById(cl.getPodId());
                        if(res2.isPresent()){
                            Pod pod=res2.get();
                            //log.info("pod.getPodId()-->" + pod.getPodId());
                            res.setPodName(pod.getPodName());
                            res.setPodDbUserName(pod.getPodDbUser());
                            res.setTableSpace(pod.getTablespaceSize());
                        }
                        map.put("obj", res);
                        // list5.add(res);
                    }
                    list4.add(res);
                } else {
                    List modList = new ArrayList();
                    //map.put("objjjj",list2.get(0));
                    CloudLogin cl = list2.get(0);
                    ModulesReqPo mreq = new ModulesReqPo();
                    mreq.setModuleCode(cl.getModuleCode());
                    mreq.setUserName(cl.getUsername());
                    mreq.setPassword(cl.getPassword());
                    modList.add(mreq);
                    PodCloudConfigReqPo1 res = new PodCloudConfigReqPo1();
                    res.setCredentialId(cl.getCredentialId());
                    res.setPodId(cl.getPodId());
                    res.setPodDbUserName(cl.getUsername());
                    res.setModules(modList);
                    res.setClientId(cl.getClientId());
                    res.setUrl(cl.getUrl());
                    Optional<Pod> res1 = podRepository.findById(cl.getPodId());
                    if(res1.isPresent()) {
                        Pod pod = res1.get();
                        //log.info("pod.getPodId()-->" + pod.getPodId());
                        res.setPodName(pod.getPodName());
                        res.setPodDbUserName(pod.getPodDbUser());
                        res.setTableSpace(pod.getTablespaceSize());
                    }
                    // list5.add(res);
                    list4.add(res);
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        }
        return list4;
    }

    private PodCloudConfigReqPo1 mapp(List<GetAllPodCloudConfigsResPo> list, int i) {
        PodCloudConfigReqPo1 res = new PodCloudConfigReqPo1();
        res.setCredentialId(list.get(i).getCredentialId());
        res.setPodId(list.get(i).getPodId());
        res.setPodName(list.get(i).getPodName());
        res.setClientId(list.get(i).getClientId());
        res.setUrl(list.get(i).getUrl());
        res.setPodDbUserName(list.get(i).getPodDbUserName());
        res.setTableSpace(list.get(i).getTableSpace());

        ModulesReqPo mreq = new ModulesReqPo();
        mreq.setModuleCode(list.get(i).getModuleCode());
        mreq.setUserName(list.get(i).getUsername());
        mreq.setPassword(list.get(i).getPassword());
        List modulesList = new ArrayList<>();
        modulesList.add(mreq);
        res.setModules(modulesList);
        return res;
    }

    private boolean checkForDuplicates(int clientId, Long podId, String moduleCode) {

        CloudLogin cloudLogin = podCloudConfigRepo.findByClientIdAndPodIdAndModuleCode(clientId, podId, moduleCode);
        boolean isDuplicatesFound = false;
        if (cloudLogin != null) {
            isDuplicatesFound = true;
        }
        return isDuplicatesFound;
    }


    public BasicResPo updatePodCloudConfig(UpdatePodCloudConfigReqPo req) {
        CloudLogin cloudLogin = new CloudLogin();

        cloudLogin.setCredentialId(req.getCredentialId());
        cloudLogin.setClientId(req.getClientId());
        cloudLogin.setPodId(req.getPodId());
        cloudLogin.setModuleCode(req.getModuleCode());
        cloudLogin.setUsername(req.getUserName());
        cloudLogin.setPassword(req.getPassword());
        cloudLogin.setUrl(req.getUrl());
        //cloudLogin.setLast_update_date();
        //update Cloud Login Details Table

        CloudLogin res = podCloudConfigRepo.save(cloudLogin);
        List<CRCloudImportObjectLink> existedList = cRCloudImportObjLinkRepo.getAllByCredentialId(req.getCredentialId());
        List<CRCloudImportObjectLink> updatedList = new ArrayList<>();
        //update Import Object Links Table
        List<Long> objList = req.getObjectIds();
        objList.forEach(id -> {
            CRCloudImportObjectLink obj = new CRCloudImportObjectLink();
            existedList.forEach(item -> {
                if (!id.equals(item.getObjectId())) {
                    obj.setCredentialId(req.getCredentialId());
                    obj.setObjectId(id);
                    updatedList.add(obj);
                }
            });
        });

        if (updatedList.size() > 0) {
            cRCloudImportObjLinkRepo.deleteAllByCredentialId(req.getCredentialId());
            cRCloudImportObjLinkRepo.saveAll(updatedList);
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully updated pod cloud config");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getConfigsByClientIdAndPodId(Long clientId, Long podId) {
        try {
            List<CloudLogin> cldLogin = podCloudConfigRepo.findByClientIdAndPodId(clientId, podId);
             log.info("cldLogin--> {} ", cldLogin);
             if(cldLogin.size()==0){
                 return new BasicResPo() {{
                     setStatusCode(HttpStatus.OK);
                     setStatus("success");
                     setMessage("No Data Found");
                     setPayload(cldLogin);
                 }};
             }else{
                 return new BasicResPo() {{
                     setStatusCode(HttpStatus.OK);
                     setStatus("success");
                     setMessage("Successfully retrieved the Details ");
                     setPayload(cldLogin.get(0));
                 }};
             }


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
    public BasicResPo getPodCloudConfigs(Long podId) {
        List<CloudLogin> podCloudConfigList = podCloudConfigRepo.findAllByPodId(podId);
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved objects");
            setPayload(generateResPo(podCloudConfigList));
        }};
    }
}