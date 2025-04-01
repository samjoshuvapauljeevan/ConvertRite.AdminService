package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.exception.CRNotFoundException;
import com.rite.products.convertrite.adminapi.exception.CRUniquenessException;
import com.rite.products.convertrite.adminapi.model.CRObject;
import com.rite.products.convertrite.adminapi.model.Client;
import com.rite.products.convertrite.adminapi.model.License;
import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.ClientResPo;
import com.rite.products.convertrite.adminapi.po.LicenseCreationReqPo;
import com.rite.products.convertrite.adminapi.po.LicenseResPo;
import com.rite.products.convertrite.adminapi.respository.LicenseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.*;

@RequiredArgsConstructor
@Service
public class LicenseManagementServiceImpl extends BasicManagementService<License, Long> implements LicenseManagementService {

    @Autowired
    LicenseRepository licenseRepository;

    @Override
    public BasicResPo createLicense(LicenseCreationReqPo licenseCreationReqPo) {

        License l = new License();
        l.setLicenseKey(licenseCreationReqPo.getLicenseKey());
        l.setPodLimit(licenseCreationReqPo.getPodLimit());
        l.setProjectLimit(licenseCreationReqPo.getProjectLimit());
        l.setAdditionalFeature(licenseCreationReqPo.getAdditionalFeature());
        l.setEffectiveStartDate(licenseCreationReqPo.getEffectiveStartDate());
        l.setEffectiveEndDate(licenseCreationReqPo.getEffectiveEndDate());
        if (licenseCreationReqPo.getObjectIds() != null) {
            Set<CRObject> crObjects = new HashSet<CRObject>();
            for (Long objectId : licenseCreationReqPo.getObjectIds()) {
                CRObject cr = new CRObject();
                cr.setObjectId(objectId);
                crObjects.add(cr);
            }
            l.setObjects(crObjects);
        }
        if (licenseCreationReqPo.getClientId() != null) {
            Client client = new Client();
            client.setClientId(licenseCreationReqPo.getClientId());
            l.setClient(client);
        }
        l.setLastUpdatedBy("ConvertRiteAdmin");
        l.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
        l.setCreationDate(new java.sql.Date(new java.util.Date().getTime()));
        l.setCreatedBy("ConvertRiteAdmin");
        try {
            License entityRes = super.addEntity(licenseRepository, l);
            License createdEntity = super.getEntityById(licenseRepository, entityRes.getLicenseId());
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CREATED);
                setStatus("success");
                setMessage("Successfully created license " + createdEntity.getLicenseKey());
                setPayload(generateResPo(createdEntity));
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("License key '" + licenseCreationReqPo.getLicenseKey() + "' already exists. Please enter a unique license key.");
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
    public BasicResPo getLicenses() {
        List<License> licenses = licenseRepository.findByOrderByLicenseIdAsc();
        List<LicenseResPo> res = new ArrayList<>();
        if (licenses != null) {
            for (License license : licenses) {
                res.add(generateResPo(license));
            }
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved all licenses");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getLicenseById(Long licenseId) {
        try {
            License license = super.getEntityById(licenseRepository, licenseId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get license with id " + licenseId);
                setPayload(generateResPo(license));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("License with id " + licenseId + " is not found");
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
    public BasicResPo putLicenseById(Long licenseId, LicenseCreationReqPo licenseCreationReqPo) {
        try {
            License l = licenseRepository.findById(licenseId).get();
            l.setLicenseKey(licenseCreationReqPo.getLicenseKey());
            l.setPodLimit(licenseCreationReqPo.getPodLimit());
            l.setProjectLimit(licenseCreationReqPo.getProjectLimit());
            l.setAdditionalFeature(licenseCreationReqPo.getAdditionalFeature());
            l.setEffectiveStartDate(licenseCreationReqPo.getEffectiveStartDate());
            l.setEffectiveEndDate(licenseCreationReqPo.getEffectiveEndDate());
            if (licenseCreationReqPo.getObjectIds() != null) {
                Set<CRObject> crObjects = new HashSet<CRObject>();
                for (Long objectId : licenseCreationReqPo.getObjectIds()) {
                    CRObject cr = new CRObject();
                    cr.setObjectId(objectId);
                    crObjects.add(cr);
                }
                l.setObjects(crObjects);
            }
            if (licenseCreationReqPo.getClientId() != null) {
                Client client = new Client();
                client.setClientId(licenseCreationReqPo.getClientId());
                l.setClient(client);
            }
            l.setLastUpdatedBy("ConvertRiteAdmin");
            l.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
            License updatedEntity = super.updateEntity(licenseRepository, l);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully updated license " + updatedEntity.getLicenseKey());
                setPayload(generateResPo(updatedEntity));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("License with id " + licenseId + " is not found");
                setPayload(ex);
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("License key '" + licenseCreationReqPo.getLicenseKey() + "' already exists. Please enter a unique license key.");
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
    public BasicResPo deleteLicenseById(Long licenseId) {
        try {
            License licenseEntity = super.getEntityById(licenseRepository, licenseId);
            super.deleteEntityById(licenseRepository, licenseId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("License key "+licenseEntity.getLicenseKey()+" is successfully deleted");}};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("License with id " + licenseId + " not exists to delete");
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

    private LicenseResPo generateResPo(License license) {
        LicenseResPo res = new LicenseResPo();
        res.setLicenseId(license.getLicenseId());
        res.setLicenseKey(license.getLicenseKey());
        res.setPodLimit(license.getPodLimit());
        res.setProjectLimit(license.getProjectLimit());
        res.setAdditionalFeature(license.getAdditionalFeature());
        res.setEffectiveStartDate(license.getEffectiveStartDate());
        res.setEffectiveEndDate(license.getEffectiveEndDate());
        if (license.getObjects() != null) {
            List<Long> crObjectIds = new ArrayList<Long>();
            for (CRObject crObject : license.getObjects()) {
                crObjectIds.add(crObject.getObjectId());
            }
            res.setObjectIds(crObjectIds);
        }
        if (license.getClient() != null) {
            ClientResPo client = new ClientResPo();
            Client licenseClient = license.getClient();
            client.setClientId(licenseClient.getClientId());
            client.setClientName(licenseClient.getClientName());
            res.setClient(client);
        }
        return res;
    }
}