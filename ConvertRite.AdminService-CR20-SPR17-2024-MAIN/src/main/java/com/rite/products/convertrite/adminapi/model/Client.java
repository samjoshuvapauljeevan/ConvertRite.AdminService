package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;

import java.sql.Date;
import java.util.Set;

@Entity
@Table(name = "cr_client_information")
public class Client {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "client_id", columnDefinition = "serial")
    private Long clientId;

    @Column(name = "client_name")
    private String clientName;

    @Column(name = "client_logo")
    private byte[] client_logo;

    @Column(name = "client_logo_file_name")
    private String clientLogoFileName;

    @Column(name = "client_logo_file_type")
    private String clientLogoFileType;

    @OneToMany
    @JoinTable(
            name = "cr_client_license_links",
            joinColumns = @JoinColumn(name = "client_id"),
            inverseJoinColumns = @JoinColumn(name = "license_id"))
    private Set<License> licenses;

    @Column(name = "creation_date")
    private Date creationDate;
    @Column(name = "created_by")
    private String createdBy;
    @Column(name = "last_update_date")
    private Date lastUpdatedDate;
    @Column(name = "last_update_by")
    private String lastUpdatedBy;

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

    public byte[] getClientLogo() {
        return client_logo;
    }

    public void setClientLogo(byte[] client_logo) {
        this.client_logo = client_logo;
    }

    public String getClientLogoFileName() {
        return clientLogoFileName;
    }

    public void setClientLogoFileName(String clientLogoFileName) {
        this.clientLogoFileName = clientLogoFileName;
    }

    public String getClientLogoFileType() {
        return clientLogoFileType;
    }

    public void setClientLogoFileType(String clientLogoFileType) {
        this.clientLogoFileType = clientLogoFileType;
    }

    public Set<License> getLicenses() {
        return licenses;
    }

    public void setLicenses(Set<License> licenses) {
        this.licenses = licenses;
    }

    public Date getCreationDate() {
        return creationDate;
    }

    public void setCreationDate(Date creationDate) {
        this.creationDate = creationDate;
    }

    public String getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(String createdBy) {
        this.createdBy = createdBy;
    }

    public Date getLastUpdatedDate() {
        return lastUpdatedDate;
    }

    public void setLastUpdatedDate(Date lastUpdatedDate) {
        this.lastUpdatedDate = lastUpdatedDate;
    }

    public String getLastUpdatedBy() {
        return lastUpdatedBy;
    }

    public void setLastUpdatedBy(String lastUpdatedBy) {
        this.lastUpdatedBy = lastUpdatedBy;
    }
}
