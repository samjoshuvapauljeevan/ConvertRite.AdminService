package com.rite.products.convertrite.adminapi.model;


import jakarta.persistence.*;
import lombok.Data;

import java.util.Date;

@Entity
@Table(name = "cr_client_license_links")
@Data
public class CRClientLicenseLinks {


    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "client_license_link_id")
    private Long clientLicenseLinkId;

    @Column(name = "client_id")
    private Long clientId;

    @Column(name = "license_id")
    private Long licenseId;

    @Column(name = "creation_date")
    private Date creationDate;

    @Column(name = "created_by")
    private String createdBy;

    @Column(name = "last_update_date")
    private Date lastUpdateDate;

    @Column(name = "last_update_by")
    private String lastUpdateBy;

}
