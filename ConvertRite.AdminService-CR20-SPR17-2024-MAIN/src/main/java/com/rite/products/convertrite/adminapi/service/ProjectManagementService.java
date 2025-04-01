package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.ProjectCreationReqPo;
import com.rite.products.convertrite.adminapi.po.ProjectResPo;
import jakarta.servlet.http.HttpServletResponse;

import java.util.List;

public interface ProjectManagementService {

    BasicResPo createProject(ProjectCreationReqPo projectCreationReqPo);

    BasicResPo getProjects(Long clientId, Long podId);

    BasicResPo getProjectById(Long projectId);

    BasicResPo putProjectById(Long projectId, ProjectCreationReqPo projectCreationReqPo);

    BasicResPo deleteProjectById(Long projectId);

    BasicResPo getProjectsAndObjects(Long clientId, Long podId, String projectName);

    BasicResPo copyObjects(Long sourcePodId, Long targetPodId, String projectName, String objectIds);

    BasicResPo getProjectsForPOD(Long podId);

    BasicResPo viewCopyLogs(String projectName);

    void downloadLogClob(Long copyId, HttpServletResponse response);
}