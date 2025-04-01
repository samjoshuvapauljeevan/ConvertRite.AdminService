package com.rite.products.convertrite.adminapi.po;

import java.util.List;

public class ModuleWithObjectsResPo {
    private Long moduleId;
    private String moduleName;
    private String moduleCode;
    private List<ObjectBasicResPo> crObjects;

    public Long getModuleId() {
        return moduleId;
    }

    public void setModuleId(Long moduleId) {
        this.moduleId = moduleId;
    }

    public String getModuleName() {
        return moduleName;
    }

    public void setModuleName(String moduleName) {
        this.moduleName = moduleName;
    }

    public String getModuleCode() {
        return moduleCode;
    }

    public void setModuleCode(String moduleCode) {
        this.moduleCode = moduleCode;
    }

    public List<ObjectBasicResPo> getCrObjects() {
        return crObjects;
    }

    public void setCrObjects(List<ObjectBasicResPo> crObjects) {
        this.crObjects = crObjects;
    }
}
