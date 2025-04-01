package com.rite.products.convertrite.adminapi.po;

import java.util.List;

public class ClientResPo {
    private Long clientId;
    private String clientName;
    private byte[] logo;

    private List<LicenseResPo> licenses;

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

    public byte[] getLogo() {
        return logo;
    }

    public void setLogo(byte[] logo) {
        this.logo = logo;
    }

    public List<LicenseResPo> getLicenses() {
        return licenses;
    }

    public void setLicenses(List<LicenseResPo> licenses) {
        this.licenses = licenses;
    }
}
