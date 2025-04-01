package com.rite.products.convertrite.adminapi.po;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.Column;
import lombok.Data;

@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class CrObjectsResPo {
    private Long objectId;
    private String objectName;
    private String objectCode;
    private String userObjectName;
    private String moduleCode;
    private Long parentObjectId;
    private String fbdiSheet;
    private String hdlSheet;
    private String parentObjectName;
    private String immediateParent;
    private Long batchSize;
    private String insertTableName;
    private String rejectionTableName;
    private String ctlFileName;
    private String xlsmFileName;
    private String loaderEndpoint;
    private String baseTables;
    private String conversionType;
    private String cldMetaDataTableName;
    private String cldTemplateCode;
    private String cldTemplateName;
}
