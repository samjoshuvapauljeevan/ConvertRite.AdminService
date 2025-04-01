package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;
import lombok.Data;

import java.sql.Date;
import java.util.Set;

@Entity
@Table(name = "cr_client_admin_information")
@Data
public class ClientAdmin {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "client_admin_id", columnDefinition = "serial")
    private Long clientAdminId;

    @OneToOne
    @JoinColumn(name = "client_id", referencedColumnName = "client_id")
    private Client client;

    @Column(name = "client_admin_name")
    private String clientAdminName;

    @Column(name = "client_Admin_User_Name")
    private String clientAdminUserName;

    @Column(name = "client_Admin_Password")
    private String clientAdminPassword;
    @Column(name = "is_first_time_login")
    private Boolean isFirstTimeLogin;
    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(
            name = "cr_client_admin_pod_access",
            joinColumns = @JoinColumn(name = "client_admin_id"),
            inverseJoinColumns = @JoinColumn(name = "pod_id"))
    Set<Pod> pods;

    @Column(name = "creation_date")
    private Date creationDate;
    @Column(name = "created_by")
    private String createdBy;
    @Column(name = "last_update_date")
    private Date lastUpdatedDate;
    @Column(name = "last_update_by")
    private String lastUpdatedBy;

}
