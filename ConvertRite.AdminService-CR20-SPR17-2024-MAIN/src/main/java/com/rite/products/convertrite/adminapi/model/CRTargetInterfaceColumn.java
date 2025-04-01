package com.rite.products.convertrite.adminapi.model;

import lombok.Data;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GenerationType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Temporal;
import jakarta.persistence.TemporalType;

import java.util.Date;

@Data
@Entity
@Table(name = "CR_TARGET_INTF_COLUMN_LIST")
public class CRTargetInterfaceColumn {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "COLUMN_LIST_ID", columnDefinition = "serial")
    private Integer columnListId;

    @Column(name = "TARGET_SYSTEM", length = 1000)
    private String targetSystem;

    @Column(name = "TARGET_SYSTEM_VERSION", length = 1000)
    private String targetSystemVersion;

    @Column(name = "OBJECT_ID", nullable = false)
    private Long objectId;

    @Column(name = "COLUMN_NAME", length = 1000, nullable = false)
    private String columnName;

    @Column(name = "PHYSICAL_COLUMN_NAME", length = 1000, nullable = false)
    private String physicalColumnName;

    @Column(name = "USER_COLUMN_NAME", length = 1000, nullable = false)
    private String userColumnName;

    @Column(name = "COLUMN_DESCRPTION", length = 1000)
    private String columnDescription;

    @Column(name = "COLUMN_SEQUENCE", length = 1000)
    private String columnSequence;

    @Column(name = "COLUMN_TYPE", length = 1000)
    private String columnType;

    @Column(name = "COLUMN_WIDTH", length = 1000)
    private String columnWidth;

    @Column(name = "NULL_ALLOWED_FLAG", length = 1000)
    private String nullAllowedFlag;

    @Column(name = "TRANSLATE_FLAG", length = 1)
    private String translateFlag;

    @Column(name = "PRECISION", length = 1000)
    private String precision;

    @Column(name = "SCALE", length = 1000)
    private String scale;

    @Column(name = "DOMAIN_CODE", length = 1000)
    private String domainCode;

    @Column(name = "DENORM_PATH", length = 1000)
    private String denormPath;

    @Column(name = "ROUTING_MODE", length = 1000)
    private String routingMode;

    @Column(name = "CLOUD_VERSION", length = 1000)
    private String cloudVersion;

    @Column(name = "ELIGIBLE_TO_BE_SECURED", length = 1000)
    private String eligibleToBeSecured;

    @Column(name = "SECURITY_CLASSIFICATION", length = 1000)
    private String securityClassification;

    @Column(name = "SEC_CLASSIFICATION_OVERRIDE", length = 1000)
    private String secClassificationOverride;

    @Column(name = "ATTRIBUTE1", length = 150)
    private String attribute1;

    @Column(name = "ATTRIBUTE2", length = 150)
    private String attribute2;

    @Column(name = "ATTRIBUTE3", length = 150)
    private String attribute3;

    @Column(name = "ATTRIBUTE4", length = 150)
    private String attribute4;

    @Column(name = "ATTRIBUTE5", length = 150)
    private String attribute5;

    @Column(name = "CREATION_DATE", nullable = false)
    @Temporal(TemporalType.DATE)
    private Date creationDate;

    @Column(name = "CREATED_BY", length = 200, nullable = false)
    private String createdBy;

    @Column(name = "LAST_UPDATE_DATE")
    @Temporal(TemporalType.DATE)
    private Date lastUpdateDate;

    @Column(name = "LAST_UPDATED_BY", length = 200)
    private String lastUpdatedBy;

}
