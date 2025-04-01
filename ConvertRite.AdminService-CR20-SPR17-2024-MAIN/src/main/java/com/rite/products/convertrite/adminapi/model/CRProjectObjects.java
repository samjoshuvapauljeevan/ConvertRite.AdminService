package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;
import lombok.Data;

import java.sql.Date;
@Data
@Entity
@Table(name = "cr_project_objects")
public class CRProjectObjects {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "project_obj_link_id")
    private Long  projectObjLinkId;
    @Column(name = "project_id")
    private Long  projectId;
    @Column(name = "object_id")
    private Long objectId;
    @Column(name = "creation_date")
    private Date   creationDate;
    @Column(name = "created_by")
    private String   createdBy;
    @Column(name = "last_update_date")
    private Date lastUpdateDate;
    @Column(name = "last_update_by")
    private String  lastUpdateBy;

}
