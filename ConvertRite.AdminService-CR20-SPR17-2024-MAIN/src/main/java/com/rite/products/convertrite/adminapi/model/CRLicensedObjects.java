package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;

@Entity
@Table(name = "cr_licensed_objects")
@Data
public class CRLicensedObjects {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public int obj_license_link_id;

    public int object_id;

    @Column(name = "license_id")
    public Long licenseId;

    public java.sql.Date creation_date;
    public String created_by;
    public java.sql.Date last_update_date;
    public String last_update_by;
}
