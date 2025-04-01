package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.ClientCreationReqPo;

public interface ClientManagementService {

    BasicResPo createClient(ClientCreationReqPo clientCreationReqPo);

    BasicResPo getClients();

    BasicResPo getClientById(Long clientId);

    BasicResPo getClientDetailsByClientId(Long clientId);

    BasicResPo putClientById(Long clientId, ClientCreationReqPo clientCreationReqPo);

    BasicResPo deleteClientById(Long clientId);
}