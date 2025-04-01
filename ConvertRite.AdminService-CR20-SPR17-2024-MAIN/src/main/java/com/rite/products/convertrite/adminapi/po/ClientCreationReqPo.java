package com.rite.products.convertrite.adminapi.po;

import org.springframework.web.multipart.MultipartFile;

import java.util.List;

public class ClientCreationReqPo {
    private Long clientId;
    private String clientName;
    private MultipartFile logo;
    private List<Long> licenseIds;

    public Long getClientId() {
        return clientId;
    }

    public void setClientId(Long clientId) {
        this.clientId = clientId;
    }

    public String getClientName() {
        return clientName;
    }

    public void setClientName(String clientName) {
        this.clientName = clientName;
    }

    public MultipartFile getLogo() {
        return logo;
    }

    public void setLogo(MultipartFile logo) {
        this.logo = logo;
    }

    public List<Long> getLicenseIds() {
        return licenseIds;
    }

    public void setLicenseIds(List<Long> licenseIds) {
        this.licenseIds = licenseIds;
    }
}
