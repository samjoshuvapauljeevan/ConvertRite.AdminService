package com.rite.products.convertrite.adminapi.po;

import lombok.Data;

import java.sql.Date;
import java.util.List;

@Data
public class LicenseCreationReqPo {
    private Long licenseId;
    private String licenseKey;
    private Long podLimit;
    private Long projectLimit;
    private String additionalFeature;
    private Date effectiveStartDate;
    private Date effectiveEndDate;
    private List<Long> objectIds;
    private Long clientId;
}
