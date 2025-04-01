package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;

@Entity
@Table(name = "cr_cloud_import_object_links")
@Data
public class CRCloudImportObjectLink {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "cloud_import_object_link_id")
    public Long obj_import_link_id;
    @Column(name = "credential_id")
    public Long credentialId;
    @Column(name = "object_id")
    public Long objectId;

    public java.sql.Date creation_date;
    public String created_by;
    public java.sql.Date last_update_date;
    public String last_update_by;
}