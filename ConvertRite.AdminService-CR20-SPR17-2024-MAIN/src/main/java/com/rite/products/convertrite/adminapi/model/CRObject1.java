package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;
import lombok.Data;

import java.sql.Date;
import java.util.List;

@Data
@Entity
@Table(name = "cr_objects")
public class CRObject1 {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "object_id", columnDefinition = "serial")
    private Long objectId;

    @Column(name = "object_name")
    private String objectName;

    @Column(name = "object_code")
    private String objectCode;

    @Column(name = "user_object_name")
    private String userObjectName;

    @Column(name = "module_code")
    private String moduleCode;

    @Column(name = "parent_object_id")
    private Long parentObjectId;

    @Column(name = "fbdi_sheet")
    private String fbdiSheet;

    @Column(name = "hdl_sheet")
    private String hdlSheet;

    @Column(name = "loader_endpoint")
    private String loaderEndpoint;

    @Column(name = "re_con_query")
    private String reConQuery;

    @Column(name = "sequence_in_parent")
    private Long sequenceInParent;

    @Column(name = "interface_table_name")
    private String insertTableName;

    @Column(name="rejection_table_name")
    private String rejectionTableName;

    @Column(name="ctl_file_name")
    private String ctlFileName;

    @Column(name="xlsm_file_name")
    private String xlsmFileName;

    @Column(name="immediate_parent")
    private String immediateParent;

    @Column(name="batch_size")
    private Long batchSize;

    @Column(name="base_tables")
    private String baseTables;

    @Column(name = "creation_date")
    private Date creationDate;
    @Column(name = "created_by")
    private String createdBy;
    @Column(name = "last_update_date")
    private Date lastUpdatedDate;
    @Column(name = "last_update_by")
    private String lastUpdatedBy;
    @OneToMany
    @JoinColumn(name = "object_id")
    private List<CrObjectInformation> crObjectInformation;


}
