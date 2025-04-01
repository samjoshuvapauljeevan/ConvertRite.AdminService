package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;

import java.sql.Date;
import java.util.Set;

@Entity
@Table(name = "cr_license_information")
public class License {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "license_id", columnDefinition = "serial")
    private Long licenseId;

    @Column(name = "license_key")
    private String licenseKey;

    @Column(name = "pod_limit")
    private Long podLimit;

    @Column(name = "project_limit")
    private Long projectLimit;

    @Column(name = "additional_feature")
    private String additionalFeature;


    @Column(name = "effective_start_date")
    private Date effectiveStartDate;

    @Column(name = "effective_end_date")
    private Date effectiveEndDate;

    @ManyToMany
    @JoinTable(
            name = "cr_licensed_objects",
            joinColumns = @JoinColumn(name = "license_id"),
            inverseJoinColumns = @JoinColumn(name = "object_id"))
    Set<CRObject> objects;

    @OneToOne
    @JoinTable(
            name = "cr_client_license_links",
            joinColumns = @JoinColumn(name = "license_id"),
            inverseJoinColumns = @JoinColumn(name = "client_id"))
    private Client client;

    @Column(name = "creation_date")
    private Date creationDate;
    @Column(name = "created_by")
    private String createdBy;
    @Column(name = "last_update_date")
    private Date lastUpdatedDate;
    @Column(name = "last_update_by")
    private String lastUpdatedBy;

    public Long getLicenseId() {
        return licenseId;
    }

    public void setLicenseId(Long licenseId) {
        this.licenseId = licenseId;
    }

    public String getLicenseKey() {
        return licenseKey;
    }

    public void setLicenseKey(String licenseKey) {
        this.licenseKey = licenseKey;
    }

    public Long getPodLimit() {
        return podLimit;
    }

    public void setPodLimit(Long podLimit) {
        this.podLimit = podLimit;
    }

    public Long getProjectLimit() {
        return projectLimit;
    }

    public void setProjectLimit(Long projectLimit) {
        this.projectLimit = projectLimit;
    }

    public String getAdditionalFeature() {
        return additionalFeature;
    }

    public void setAdditionalFeature(String additionalFeature) {
        this.additionalFeature = additionalFeature;
    }

    public Date getEffectiveStartDate() {
        return effectiveStartDate;
    }

    public void setEffectiveStartDate(Date effectiveStartDate) {
        this.effectiveStartDate = effectiveStartDate;
    }

    public Date getEffectiveEndDate() {
        return effectiveEndDate;
    }

    public void setEffectiveEndDate(Date effectiveEndDate) {
        this.effectiveEndDate = effectiveEndDate;
    }

    public Set<CRObject> getObjects() {
        return objects;
    }

    public void setObjects(Set<CRObject> objects) {
        this.objects = objects;
    }

    public Client getClient() {
        return client;
    }

    public void setClient(Client client) {
        this.client = client;
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
