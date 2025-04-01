package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.exception.CRNotFoundException;
import com.rite.products.convertrite.adminapi.exception.CRUniquenessException;
import com.rite.products.convertrite.adminapi.model.Client;
import com.rite.products.convertrite.adminapi.model.License;
import com.rite.products.convertrite.adminapi.po.*;
import com.rite.products.convertrite.adminapi.respository.ClientRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@RequiredArgsConstructor
@Service
public class ClientManagementServiceImpl extends BasicManagementService<Client, Long> implements ClientManagementService {

    @Autowired
    ClientRepository clientRepository;

    @Override
    public BasicResPo createClient(ClientCreationReqPo clientCreationReqPo) {
        Client c = new Client();
        c.setClientName(clientCreationReqPo.getClientName());
        if (clientCreationReqPo.getLogo() != null) {
            try {
                c.setClientLogo(clientCreationReqPo.getLogo().getBytes());
                c.setClientLogoFileName(clientCreationReqPo.getLogo().getOriginalFilename());
                c.setClientLogoFileType(clientCreationReqPo.getLogo().getContentType());
            } catch (IOException e) {

            }
        }
        if (clientCreationReqPo.getLicenseIds() != null) {
            Set<License> licenses = new HashSet<>();
            for (Long licenseId : clientCreationReqPo.getLicenseIds()) {
                License license = new License();
                license.setLicenseId(licenseId);
                licenses.add(license);
            }
            c.setLicenses(licenses);
        }
        c.setLastUpdatedBy("ConvertRiteAdmin");
        c.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
        c.setCreationDate(new java.sql.Date(new java.util.Date().getTime()));
        c.setCreatedBy("ConvertRiteAdmin");

        try {
            Client entityRes = super.addEntity(clientRepository, c);
            Client createdEntity = super.getEntityById(clientRepository, entityRes.getClientId());
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CREATED);
                setStatus("success");
                setMessage("Successfully created client " + createdEntity.getClientName());
                setPayload(generateResPo(createdEntity));
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("Client name " + clientCreationReqPo.getClientName() + " is already available. It should be unique.");
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
    public BasicResPo getClients() {
        List<Client> clients = clientRepository.findByOrderByClientIdAsc();
        List<ClientResPo> res = new ArrayList<>();
        if (clients != null) {
            for (Client client : clients) {
                res.add(generateResPo(client));
            }
            ;
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved all clients");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getClientById(Long clientId) {
        try {
            Client client = super.getEntityById(clientRepository, clientId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get client with id " + clientId);
                setPayload(generateResPo(client));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Client with id " + clientId + " is not found");
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
    public BasicResPo getClientDetailsByClientId(Long clientId) {
        try {
            Client client = super.getEntityById(clientRepository, clientId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get client with id " + clientId);
                setPayload(client);
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Client with id " + clientId + " is not found");
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
    public BasicResPo putClientById(Long clientId, ClientCreationReqPo clientCreationReqPo) {
        try {
            Client c = clientRepository.findById(clientId).get();
            c.setClientName(clientCreationReqPo.getClientName());
            if (clientCreationReqPo.getLogo() != null && clientCreationReqPo.getLogo().getBytes().length > 0) {
                try {
                    c.setClientLogo(clientCreationReqPo.getLogo().getBytes());
                    c.setClientLogoFileName(clientCreationReqPo.getLogo().getOriginalFilename());
                    c.setClientLogoFileType(clientCreationReqPo.getLogo().getContentType());
                } catch (IOException e) {

                }
            }
            if (clientCreationReqPo.getLicenseIds() != null) {
                Set<License> licenses = new HashSet<>();
                for (Long licenseId : clientCreationReqPo.getLicenseIds()) {
                    License license = new License();
                    license.setLicenseId(licenseId);
                    licenses.add(license);
                }
                c.setLicenses(licenses);
            }
            c.setLastUpdatedBy("ConvertRiteAdmin");
            c.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
            Client updatedEntity = super.updateEntity(clientRepository, c);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully updated client " + updatedEntity.getClientName());
                setPayload(generateResPo(updatedEntity));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Client with id " + clientId + " is not found");
                setPayload(ex);
            }};
        } catch (CRUniquenessException ex) {
            if (ex.getMessage().contains("license_id")) {
                return new BasicResPo() {{
                    setStatusCode(HttpStatus.CONFLICT);
                    setStatus("error");
                    setMessage("Licenses with id " + clientCreationReqPo.getLicenseIds() + " is already used. It should be assigned to only one client.");
                    setPayload(ex);
                }};
            } else {
                return new BasicResPo() {{
                    setStatusCode(HttpStatus.CONFLICT);
                    setStatus("error");
                    setMessage("Client name " + clientCreationReqPo.getClientName() + " is already available. It should be unique.");
                    setPayload(ex);
                }};
            }
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
    public BasicResPo deleteClientById(Long clientId) {
        try {
            Client client = super.getEntityById(clientRepository, clientId);
            super.deleteEntityById(clientRepository, clientId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully deleted client with name " + client.getClientName());
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Client with id " + clientId + " not exists to delete");
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

    private ClientResPo generateResPo(Client c) {
        ClientResPo res = new ClientResPo();
        res.setClientId(c.getClientId());
        res.setClientName(c.getClientName());
        res.setLogo(c.getClientLogo());
        if (c.getLicenses() != null) {
            List<LicenseResPo> licenses = new ArrayList<>();
            for (License license : c.getLicenses()) {
                LicenseResPo lr = new LicenseResPo();
                lr.setLicenseId(license.getLicenseId());
                lr.setLicenseKey(license.getLicenseKey());
                licenses.add(lr);
            }
            res.setLicenses(licenses);
        }
        return res;
    }

    private ClientBasicResPo generateBasicResPo(Client c) {
        ClientBasicResPo res = new ClientBasicResPo();
        res.setClientId(c.getClientId());
        res.setClientName(c.getClientName());
        return res;
    }
}
