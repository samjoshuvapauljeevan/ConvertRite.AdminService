package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;
import lombok.Data;

import java.sql.Date;
import java.util.Set;

@Entity
@Table(name = "cr_users")
@Data
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id", columnDefinition = "serial")
    private Long userId;

    @Column(name = "user_name")
    private String userName;

    @Column(name = "password")
    private String password;

    @Column(name = "person_name")
    private String personName;

    @Column(name = "email")
    private String email;

    @Column(name = "is_first_time_login")
    private Boolean isFirstTimeLogin;

    @Column(name = "user_login_type")
    private String userLoginType;

    @OneToOne
    @JoinColumn(name = "client_id", referencedColumnName = "client_id")
    private Client client;

    @Column(name = "client_id", insertable = false, updatable = false)
    private Long clientId;

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(
            name = "cr_user_role_links",
            joinColumns = @JoinColumn(name = "user_id"),
            inverseJoinColumns = @JoinColumn(name = "role_id"))
    Set<Role> roles;

    @Column(name = "creation_date")
    private Date creationDate;
    @Column(name = "created_by")
    private String createdBy;
    @Column(name = "last_update_date")
    private Date lastUpdatedDate;
    @Column(name = "last_update_by")
    private String lastUpdatedBy;
}
