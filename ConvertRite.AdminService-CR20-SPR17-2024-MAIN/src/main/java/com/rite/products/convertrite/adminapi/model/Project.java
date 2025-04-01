package com.rite.products.convertrite.adminapi.model;


import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import org.codehaus.jackson.annotate.JsonIgnore;

import java.io.Serializable;
import java.sql.Date;
import java.util.Set;

@Entity
@Table(name = "cr_projects")
public class Project implements Serializable {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "project_id", columnDefinition = "serial")
    private Long projectId;

    @Column(name = "project_name")
    private String projectName;

    @Column(name= "project_code")
    private String projectCode;

    @OneToOne
    @JoinColumn(name = "client_id", referencedColumnName = "client_id")
    private Client client;

    @Column(name = "client_id", insertable = false, updatable = false)
    private Long clientId;

    @OneToOne
    @JoinColumn(name = "pod_id", referencedColumnName = "pod_id")
    private Pod pod;

    @Column(name = "pod_id", insertable = false, updatable = false)
    private Long podId;
    @JsonIgnoreProperties
    @ManyToMany
    @JoinTable(name = "cr_project_objects",
            joinColumns = @JoinColumn(name = "project_id"),
            inverseJoinColumns = @JoinColumn(name = "object_id"))
    Set<CRObject> objects;

    @Column(name = "creation_date")
    private Date creationDate;
    @Column(name = "created_by")
    private String createdBy;
    @Column(name = "last_update_date")
    private Date lastUpdatedDate;
    @Column(name = "last_update_by")
    private String lastUpdatedBy;

    public Long getProjectId() {
        return projectId;
    }

    public void setProjectId(Long projectId) {
        this.projectId = projectId;
    }

    public String getProjectName() {
        return projectName;
    }

    public void setProjectName(String projectName) {
        this.projectName = projectName;
    }

    public String getProjectCode() {
        return projectCode;
    }

    public void setProjectCode(String projectCode) {
        this.projectCode = projectCode;
    }

    public Client getClient() {
        return client;
    }

    public void setClient(Client client) {
        this.client = client;
    }

    public Long getClientId() {
        return clientId;
    }

    public void setClientId(Long clientId) {
        this.clientId = clientId;
    }

    public Pod getPod() {
        return pod;
    }

    public void setPod(Pod pod) {
        this.pod = pod;
    }

    public Long getPodId() {
        return podId;
    }

    public void setPodId(Long podId) {
        this.podId = podId;
    }

    public Set<CRObject> getObjects() {
        return objects;
    }

    public void setObjects(Set<CRObject> objects) {
        this.objects = objects;
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
