package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;
import lombok.Data;

import java.util.Date;

@Data
@Entity
@Table(name = "cr_role_obj_links")
public class CrRoleObjectLink {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "obj_role_link_id")
    private Long objRoleLinkId;

    @Column(name = "object_id")
    private Long objectId;
    @Column(name = "role_id")
    private Long roleId;

    @Column(name = "creation_date")
    private Date creationDate;

    @Column(name = "created_by")
    private String createdBy;

    @Column(name = "last_update_date")
    private Date lastUpdateDate;

    @Column(name = "last_update_by")
    private String lastUpdateBy;
}
