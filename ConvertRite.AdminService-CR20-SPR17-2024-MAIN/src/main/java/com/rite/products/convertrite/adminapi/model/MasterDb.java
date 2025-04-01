package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;
import lombok.Data;

@Data
@Entity
@Table(name = "cr_master_db_information")
public class MasterDb {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "master_db_credential_id", columnDefinition = "serial")
    private Long credentialId;

    @Column(name = "client_id")
    private Long clientId;
    @Column(name = "license_id")
    private Long licenseId;
    @Column(name = "master_db_host")
    private String masterDbHost;
    @Column(name = "master_db_user_name")
    private String masterDbUserName;
    @Column(name = "master_db_password")
    private String masterDbPassword;

}
