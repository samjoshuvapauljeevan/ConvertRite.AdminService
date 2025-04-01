package com.rite.products.convertrite.adminapi.po;

import com.rite.products.convertrite.adminapi.model.CRObject;
import com.rite.products.convertrite.adminapi.model.CRProjectObjects;
import com.rite.products.convertrite.adminapi.model.Project;
import lombok.Data;

import java.util.List;

@Data
public class ProjectsWithObjectsPo {

    private Project projectsList;
    private CRProjectObjects objectsList;
    public ProjectsWithObjectsPo(Project projectsList, CRProjectObjects objectsList) {
        super();
        this.projectsList = projectsList;
        this.objectsList = objectsList;
    }

    public Project getProjectsList() {
        return projectsList;
    }

    public void setProjectsList(Project projectsList) {
        this.projectsList = projectsList;
    }

    public CRProjectObjects getObjectsList() {
        return objectsList;
    }

    public void setObjectsList(CRProjectObjects objectsList) {
        this.objectsList = objectsList;
    }

}
