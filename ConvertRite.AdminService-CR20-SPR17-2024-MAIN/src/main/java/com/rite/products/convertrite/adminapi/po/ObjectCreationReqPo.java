package com.rite.products.convertrite.adminapi.po;

public class ObjectCreationReqPo {
    private Long objectId;
    private String objectName;
    private String objectCode;
    private String userObjectName;
    private String moduleCode;
    private Long parentObjectId;
    private String fbdiSheet;
    private String hdlSheet;
    private String loaderEndpoint;
    private String reConQuery;
    private Long sequenceInParent;
    private String insertTableName;
    private String rejectionTableName;
    private String ctlFileName;
    private String xlsmFileName;
    private Long batchSize;
    private String immediateParent;
    private String baseTables;

    private String lastUpdatedBy;
    private String conversionType;
    public Long getObjectId() {
        return objectId;
    }

    public void setObjectId(Long objectId) {
        this.objectId = objectId;
    }

    public String getObjectName() {
        return objectName;
    }

    public void setObjectName(String objectName) {
        this.objectName = objectName;
    }

    public String getObjectCode() {
        return objectCode;
    }

    public void setObjectCode(String objectCode) {
        this.objectCode = objectCode;
    }

    public String getUserObjectName() {
        return userObjectName;
    }

    public void setUserObjectName(String userObjectName) {
        this.userObjectName = userObjectName;
    }

    public String getModuleCode() {
        return moduleCode;
    }

    public void setModuleCode(String moduleCode) {
        this.moduleCode = moduleCode;
    }

    public Long getParentObjectId() {
        return parentObjectId;
    }

    public void setParentObjectId(Long parentObjectId) {
        this.parentObjectId = parentObjectId;
    }

    public String getFbdiSheet() {
        return fbdiSheet;
    }

    public void setFbdiSheet(String fbdiSheet) {
        this.fbdiSheet = fbdiSheet;
    }

    public String getHdlSheet() {
        return hdlSheet;
    }

    public void setHdlSheet(String hdlSheet) {
        this.hdlSheet = hdlSheet;
    }

    public String getLoaderEndpoint() {
        return loaderEndpoint;
    }

    public void setLoaderEndpoint(String loaderEndpoint) {
        this.loaderEndpoint = loaderEndpoint;
    }

    public String getReConQuery() {
        return reConQuery;
    }

    public void setReConQuery(String reConQuery) {
        this.reConQuery = reConQuery;
    }

    public Long getSequenceInParent() {
        return sequenceInParent;
    }

    public void setSequenceInParent(Long sequenceInParent) {
        this.sequenceInParent = sequenceInParent;
    }

    public String getInsertTableName() {
        return insertTableName;
    }

    public void setInsertTableName(String insertTableName) {
        this.insertTableName = insertTableName;
    }

    public String getRejectionTableName() {
        return rejectionTableName;
    }

    public void setRejectionTableName(String rejectionTableName) {
        this.rejectionTableName = rejectionTableName;
    }

    public String getCtlFileName() {
        return ctlFileName;
    }

    public void setCtlFileName(String ctlFileName) {
        this.ctlFileName = ctlFileName;
    }

    public String getXlsmFileName() {
        return xlsmFileName;
    }

    public void setXlsmFileName(String xlsmFileName) {
        this.xlsmFileName = xlsmFileName;
    }

    public Long getBatchSize() {
        return batchSize;
    }

    public void setBatchSize(Long batchSize) {
        this.batchSize = batchSize;
    }



    public String getBaseTables() {
        return baseTables;
    }

    public void setBaseTables(String baseTables) {
        this.baseTables = baseTables;
    }


    public String getImmediateParent() {
        return immediateParent;
    }

    public void setImmediateParent(String immediateParent) {
        this.immediateParent = immediateParent;
    }

    public String getLastUpdatedBy() {
        return lastUpdatedBy;
    }

    public void setLastUpdatedBy(String lastUpdatedBy) {
        this.lastUpdatedBy = lastUpdatedBy;
    }

    public String getConversionType() {
        return conversionType;
    }

    public void setConversionType(String conversionType) {
        this.conversionType = conversionType;
    }
}





