package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.ProjectCreationReqPo;
import com.rite.products.convertrite.adminapi.service.ProjectManagementService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@Tag(name = "11. Projects", description = "APIs for projects")
public class ProjectsController {

    @Autowired
    ProjectManagementService projectManagementService;

    @PostMapping("/api/convertriteadmin/clients/{client_id}/projects")
    public ResponseEntity<BasicResPo> createProject(@PathVariable(name = "client_id") Long clientId, @RequestBody ProjectCreationReqPo projectCreationReqPo) {
        projectCreationReqPo.setClientId(clientId);
        BasicResPo response = projectManagementService.createProject(projectCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clients/{client_id}/projects")
    public ResponseEntity<BasicResPo> getProjects(@PathVariable(name = "client_id") Long clientId, @RequestParam(name = "pod_id", required = false) Long podId) {
        BasicResPo response = projectManagementService.getProjects(clientId, podId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/projectsforpod")
    public ResponseEntity<BasicResPo> getProjectsForPOD(@RequestParam(name = "pod_id") Long podId) {
        BasicResPo response = projectManagementService.getProjectsForPOD(podId);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/clients/{client_id}/projects/{project_id}")
    public ResponseEntity<BasicResPo> getProject(@PathVariable(name = "client_id") Long clientId, @PathVariable Long project_id) {
        BasicResPo response = projectManagementService.getProjectById(project_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @PutMapping("/api/convertriteadmin/clients/{client_id}/projects/{project_id}")
    public ResponseEntity<BasicResPo> putProject(@PathVariable Long project_id, @RequestBody ProjectCreationReqPo projectCreationReqPo) {
        BasicResPo response = projectManagementService.putProjectById(project_id, projectCreationReqPo);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @DeleteMapping("/api/convertriteadmin/clients/{client_id}/projects/{project_id}")
    public ResponseEntity<BasicResPo> deleteProject(@PathVariable Long project_id) {
        BasicResPo response = projectManagementService.deleteProjectById(project_id);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @ResponseBody
    @RequestMapping(value="/api/convertriteadmin/getProjectsAndObjects",produces = "application/json")
    public ResponseEntity<BasicResPo> getProjectsAndObjects(@RequestParam(name = "clientId") Long clientId, @RequestParam(name = "podId") Long podId, @RequestParam(name = "projectName", required = false) String projectName) {
        BasicResPo response = projectManagementService.getProjectsAndObjects(clientId, podId, projectName);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @ResponseBody
    @RequestMapping(value="/api/convertriteadmin/copyObjects",produces = "application/json")
    public ResponseEntity<BasicResPo> copyObjects(@RequestParam(name = "sourcePodId") Long sourcePodId, @RequestParam(name = "targetPodId") Long targetPodId, @RequestParam(name = "projectName") String projectName, @RequestParam(name = "objectIds" , required = false) String objectIds) {
        BasicResPo response = projectManagementService.copyObjects(sourcePodId, targetPodId, projectName, objectIds);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @ResponseBody
    @RequestMapping(value="/api/convertriteadmin/viewCopyLogs",produces = "application/json")
    public ResponseEntity<BasicResPo> viewCopyLogs(@RequestParam(name = "sourcePOD") String sourcePOD) {
        BasicResPo response = projectManagementService.viewCopyLogs(sourcePOD);
        return new ResponseEntity<>(response, response.getStatusCode());
    }

    @GetMapping("/api/convertriteadmin/downloadLogClob")
    public void downloadLogClob(@RequestParam("copyId") Long copyId, HttpServletResponse response)
            throws Exception {
        try {
            projectManagementService.downloadLogClob(copyId, response);
        } catch (Exception e) {
            throw new Exception(e.getMessage());
        }
    }
}
