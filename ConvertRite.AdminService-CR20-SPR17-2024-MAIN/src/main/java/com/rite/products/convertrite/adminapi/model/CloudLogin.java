package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;

@Entity
@Table(name = "cr_cloud_login_details")
@Data
public class CloudLogin {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "credential_id")
    public Long credentialId;
    @Column(name = "client_id")
    public Long clientId;
    @Column(name = "pod_id")
    public Long podId;

    public String url;
    @Column(name = "module_code")
    public String moduleCode;
    public String username;
    public String password;
    public java.sql.Date creation_date;
    public String created_by;
    public java.sql.Date last_update_date;
    public String last_update_by;
}
