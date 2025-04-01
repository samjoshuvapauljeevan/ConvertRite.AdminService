package com.rite.products.convertrite.adminapi.po;

import lombok.Data;

import java.sql.Date;
import java.util.List;

@Data
public class LicenseResPo {
    private Long licenseId;
    private String licenseKey;
    private Long podLimit;
    private Long projectLimit;
    private String additionalFeature;
    private Date effectiveStartDate;
    private Date effectiveEndDate;
    private List<Long> objectIds;
    private ClientResPo client;
}
