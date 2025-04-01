package com.rite.products.convertrite.adminapi.po;

import lombok.Data;

import java.sql.Timestamp;

@Data
public class CRCopyLogsResPo {
    private Long copyId;

    private String sourcePOD;

    private String destinationPOD;

    private String objectIds;

    private String projectName;

    private String status;

    private String errorMsg;

    private Timestamp creationDate;
}
