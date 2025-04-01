package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;
import lombok.Data;

import java.sql.Date;

@Entity
@Table(name = "cr_rs_pod_information")
@Data
public class CrRsPodInformation {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "pod_id", columnDefinition = "serial")
    private Long podId;

    @Column(name = "pod_name")
    private String podName;

    @Column(name = "pod_db_user")
    private String podDbUser;

    @Column(name = "pod_db_password")
    private String podDbPassword;

    @Column(name = "pod_target_url")
    private String podTargetUrl;

    @Column(name = "pod_tablespace_size")
    private String tablespaceSize;

    @Column(name = "license_id", insertable = false, updatable = false)
    private Long licenseId;

    @OneToOne
    @JoinColumn(name ="license_id",referencedColumnName ="license_id")
    private License license;
    @OneToOne
    @JoinColumn(name ="client_id",referencedColumnName ="client_id")
    private Client client;
    @Column(name = "creation_date")
    private Date creationDate;
    @Column(name = "created_by")
    private String createdBy;
    @Column(name = "last_update_date")
    private Date lastUpdatedDate;
    @Column(name = "last_update_by")
    private String lastUpdatedBy;

}
