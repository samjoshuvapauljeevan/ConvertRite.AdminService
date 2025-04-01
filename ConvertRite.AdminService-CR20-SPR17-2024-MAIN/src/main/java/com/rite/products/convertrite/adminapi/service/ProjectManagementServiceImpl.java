package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.exception.CRAdminException;
import com.rite.products.convertrite.adminapi.exception.CRNotFoundException;
import com.rite.products.convertrite.adminapi.exception.CRUniquenessException;
import com.rite.products.convertrite.adminapi.model.*;
import com.rite.products.convertrite.adminapi.po.*;
import com.rite.products.convertrite.adminapi.respository.LicenseRepository;
import com.rite.products.convertrite.adminapi.respository.MasterDbRepository;
import com.rite.products.convertrite.adminapi.respository.PodRepository;
import com.rite.products.convertrite.adminapi.respository.ProjectRepository;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.Reader;
import java.sql.*;
import java.util.*;

@RequiredArgsConstructor
@Service
@Slf4j
public class ProjectManagementServiceImpl extends BasicManagementService<Project, Long> implements ProjectManagementService {

    @Autowired
    ProjectRepository projectRepository;

    @Autowired
    PodRepository podRepository;
    @Autowired
    MasterDbRepository masterDbRepository;

    @Autowired
    LicenseRepository licenseRepository;

    @Value("${oracle.datasource.url}")
    private String url;
    @Value("${oracle.datasource.username}")
    private String username;
    @Value("${oracle.datasource.password}")
    private String password;

    @Override
    public BasicResPo createProject(ProjectCreationReqPo projectCreationReqPo) {
        try {
            checkProjectLimit(projectCreationReqPo);
            Project r = new Project();
            r.setProjectName(projectCreationReqPo.getProjectName());
            r.setProjectCode(projectCreationReqPo.getProjectCode());
            Client c = new Client();
            c.setClientId(projectCreationReqPo.getClientId());
            r.setClient(c);
            Pod pod = new Pod();
            pod.setPodId(projectCreationReqPo.getPodId());
            r.setPod(pod);
            if (projectCreationReqPo.getObjectIds() != null) {
                Set<CRObject> crObjects = new HashSet<CRObject>();
                for (Long objectId : projectCreationReqPo.getObjectIds()) {
                    CRObject cr = new CRObject();
                    cr.setObjectId(objectId);
                    crObjects.add(cr);
                }
                r.setObjects(crObjects);
            }
            r.setLastUpdatedBy("ConvertRiteAdmin");
            r.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
            r.setCreationDate(new java.sql.Date(new java.util.Date().getTime()));
            r.setCreatedBy("ConvertRiteAdmin");
            Project entityRes = super.addEntity(projectRepository, r);
            Project createdEntity = super.getEntityById(projectRepository, entityRes.getProjectId());
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CREATED);
                setStatus("success");
                setMessage("Successfully created project " + createdEntity.getProjectName());
                setPayload(generateResPo(createdEntity));
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("Project name " + projectCreationReqPo.getProjectName() + " is already available. It should be unique.");
                setPayload(ex);
            }};
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo getProjects(Long clientId, Long podId) {
        List<Project> projects = new ArrayList<>();
        if (podId != null && podId != 0) {
            projects = projectRepository.findAllByPodId(podId);
        } else {
            projects = projectRepository.findAllByClientId(clientId);
        }
        List<ProjectResPo> res = new ArrayList<>();
        if (projects != null) {
            for (Project project : projects) {
                res.add(generateResPo(project));
            }
            ;
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved all projects");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getProjectById(Long projectId) {
        try {
            Project project = super.getEntityById(projectRepository, projectId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get project with id " + projectId);
                setPayload(generateResPo(project));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Project with id " + projectId + " is not found");
                setPayload(ex);
            }};
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo putProjectById(Long projectId, ProjectCreationReqPo projectCreationReqPo) {
        try {
            Project project = projectRepository.findById(projectId).get();
            project.setProjectName(projectCreationReqPo.getProjectName());
            project.setProjectCode(projectCreationReqPo.getProjectCode());
            if (projectCreationReqPo.getPodId() != null) {
                Pod pod = new Pod();
                pod.setPodId(projectCreationReqPo.getPodId());
                project.setPod(pod);
            }
            if (projectCreationReqPo.getObjectIds() != null) {
                Set<CRObject> crObjects = new HashSet<CRObject>();
                for (Long objectId : projectCreationReqPo.getObjectIds()) {
                    CRObject cr = new CRObject();
                    cr.setObjectId(objectId);
                    crObjects.add(cr);
                }
                project.setObjects(crObjects);
            }
            project.setLastUpdatedBy("ConvertRiteAdmin");
            project.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
            Project updatedEntity = super.updateEntity(projectRepository, project);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully updated project " + updatedEntity.getProjectName());
                setPayload(generateResPo(updatedEntity));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Project with id " + projectId + " is not found");
                setPayload(ex);
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("Project name " + projectCreationReqPo.getProjectName() + " is already available. It should be unique.");
                setPayload(ex);
            }};
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo deleteProjectById(Long projectId) {
        try {
            Project project = super.getEntityById(projectRepository, projectId);
            super.deleteEntityById(projectRepository, projectId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully deleted project with name " + project.getProjectName());
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("Project with id " + projectId + " not exists to delete");
            }};
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }


    private void checkProjectLimit(ProjectCreationReqPo projectCreationReqPo) {
        Long existingProjectCount = projectRepository.getExistingProjectCountWithPodId(projectCreationReqPo.getPodId());
        Pod pod = podRepository.findById(projectCreationReqPo.getPodId()).get();
        License license = licenseRepository.findById(pod.getLicenseId()).get();
        if (license.getProjectLimit() <= existingProjectCount) {
            throw new CRAdminException("Existing projects already reached project limit : " + license.getProjectLimit());
        }
    }

    private ProjectResPo generateResPo(Project r) {
        ProjectResPo res = new ProjectResPo();
        res.setProjectId(r.getProjectId());
        res.setProjectName(r.getProjectName());
        res.setProjectCode(r.getProjectCode());
        ClientResPo c = new ClientResPo();
        if (r.getClient() != null) {
            c.setClientId(r.getClient().getClientId());
            c.setClientName(r.getClient().getClientName());
        }
        res.setClient(c);
        PodBasicResPo podResPo = new PodBasicResPo();
        if (r.getPod() != null) {
            podResPo.setPodId(r.getPod().getPodId());
            podResPo.setPodName(r.getPod().getPodName());
        }
        res.setPod(podResPo);
        if (r.getObjects() != null) {
            List<Long> crObjectIds = new ArrayList<Long>();
            for (CRObject crObject : r.getObjects()) {
                crObjectIds.add(crObject.getObjectId());
            }
            res.setObjectIds(crObjectIds);
        }
        return res;
    }

    @Override
    public BasicResPo getProjectsAndObjects(Long clientId, Long podId, String projectName) {
        log.info("========getProjectsAndObjects======");
        BasicResPo res = null;
        try {
            List<Project> projects;
            if (projectName != null && projectName.length() > 0) {
                projects = projectRepository.findAllByClientIdAndPodIdAndProjectName(clientId, podId, projectName);
            } else {
                projects = projectRepository.findAllByClientIdAndPodId(clientId, podId);
            }
            log.info("projects--> {}", projects.size());
            List list = new ArrayList();
            for (Project p : projects) {
                Project proj = new Project();
                proj.setProjectId(p.getProjectId());
                proj.setProjectId(p.getProjectId());
                proj.setProjectName(p.getProjectName());
                proj.setProjectCode(p.getProjectName());
                proj.setLastUpdatedBy("ConvertRite");
                Set crProjectsObjectsList = new HashSet();
                for (CRObject objPo : p.getObjects()) {
                    CRObject crProjectsObjects = new CRObject();
                    crProjectsObjects.setObjectId(objPo.getObjectId());
                    crProjectsObjects.setObjectCode(objPo.getObjectCode());
                    crProjectsObjects.setObjectName(objPo.getObjectName());
                    crProjectsObjects.setParentObjectId(objPo.getParentObjectId());
                    crProjectsObjects.setModuleCode(objPo.getModuleCode());
                    crProjectsObjects.setCldMetaDataTableName(objPo.getCldMetaDataTableName());
                    crProjectsObjects.setInsertTableName(objPo.getInsertTableName());
                    crProjectsObjects.setCldTemplateCode(objPo.getCldTemplateCode());
                    crProjectsObjects.setBaseTables(objPo.getBaseTables());
                    crProjectsObjects.setCldTemplateName(objPo.getCldTemplateName());
                    crProjectsObjects.setConversionType(objPo.getConversionType());
                    crProjectsObjectsList.add(crProjectsObjects);
                }
                proj.setObjects(crProjectsObjectsList);
                list.add(proj);
            }
            res = new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setPayload(list);
                setMessage("Successfully fetched Projects and Objects Data");
            }};
        } catch (Exception ex) {
            res = new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
            ex.printStackTrace();
        }
        return res;
    }

    @Override
    public BasicResPo copyObjects(Long sourcePodId, Long targetPodId, String projectName, String objectIds) {
        BasicResPo res = new BasicResPo();
        Connection conn = null;
        PreparedStatement seqStmnt = null ;
        PreparedStatement logStmnt = null;
        CallableStatement callableStatement = null;
        Long copyId = 0l;
        if(sourcePodId.equals(targetPodId)){
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("Copy From and Copy To cannot be the same POD.");
            }};
        }
        try {
            log.info("sourcePodId---> {} targetPodId---> {}  projectName---> {}  objectIds---> {}",
                    sourcePodId ,targetPodId, projectName, objectIds);
            Pod sourcePod = podRepository.findById(sourcePodId).get();
            Pod targetPod = podRepository.findById(targetPodId).get();
            //List<MasterDb> list = masterDbRepository.findAll();

            String runFunc = "{ ? = call CR_COPY_FUNC(?,?,?,?,?) }"; // Function call string
            conn = DriverManager.getConnection(url, username, password);

            seqStmnt = conn.prepareStatement(
                    "select CR_COPY_ID_SEQ.NEXTVAL FROM dual");
            ResultSet rs = seqStmnt.executeQuery();
            if (rs.next()) {
                copyId = rs.getLong("NEXTVAL");
            }
            callableStatement = conn.prepareCall(runFunc);
            callableStatement.registerOutParameter(1, java.sql.Types.CLOB); // Return value
            callableStatement.setString(2, sourcePod.getPodDbUser());
            callableStatement.setString(3, targetPod.getPodDbUser());
            callableStatement.setString(4, projectName);
            callableStatement.setString(5, objectIds);
            callableStatement.setString(6, copyId.toString());
            // Run the function
            callableStatement.execute();
            // Get the return value
            String returnValue = callableStatement.getString(1);
            log.info("returnValue---> {} ", returnValue);

            res = buildResponsefromCopyLog(conn, copyId);
            if ("SUCCESS".equalsIgnoreCase(res.getStatus())) {
                res.setMessage("Successfully copied " + projectName + "Project Setups from Source:" + sourcePod.getPodName() + " to Target:" + targetPod.getPodName());
            } else if ("WARNING".equalsIgnoreCase(res.getStatus())) {
                res.setMessage("Copied " + projectName + "Project Setups from Source:" + sourcePod.getPodName() + " to Target:" + targetPod.getPodName() + " with some issues. Please check the log.");
            }
        } catch (Exception ex) {
            log.error("Error in copyObjects ----> {} ", ex);
            return buildResponsefromCopyLog(conn, copyId);
        } finally {
            try{
                if (seqStmnt != null)
                    seqStmnt.close();
                if (callableStatement != null)
                    callableStatement.close();
                if (conn != null)
                    conn.close();
            } catch (SQLException se) {
                log.error("Error in closing SQL connection and statements: {} ", se.getMessage());
            }
        }
        return res;
    }

    @Override
    public BasicResPo getProjectsForPOD(Long podId) {
        BasicResPo res = new BasicResPo();
        Connection conn = null;
        PreparedStatement stmt = null;
        Pod pod = podRepository.findById(podId).get();
        if (pod == null) {
            res.setStatus("error");
            res.setMessage("No POD exists for the given pod id");
            res.setStatusCode(HttpStatus.EXPECTATION_FAILED);
            return res;
        }
        try {
            log.info("Creating db connection to pod Id : {} ", pod.getPodId());
            conn = DriverManager.getConnection(pod.getPodTargetUrl(), pod.getPodDbUser(), pod.getPodDbPassword());
            stmt = conn.prepareStatement("select project_id, project_name from cr_projects");
            ResultSet rs = stmt.executeQuery();
            List<Project> projectsList = new ArrayList<>();
            while (rs.next()) {
                Project project = new Project();
                project.setProjectId(rs.getLong("project_id"));
                project.setProjectName(rs.getString("project_name"));
                projectsList.add(project);
            }
            if(projectsList.isEmpty()){
                res.setMessage("No projects found for the given pod id " + podId);
            } else {
                res.setMessage("Successfully retrieved projects for the given pod id " + podId);
            }
            res.setStatus("success");
            res.setStatusCode(HttpStatus.OK);
            res.setPayload(projectsList);
        } catch (Exception e) {
            log.info("Error while retrieving projects: {} ", e);
            res.setStatus("error");
            res.setMessage("Error while retrieving projects having templates for the given pod id, "+ podId);
            res.setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
            res.setPayload(e);
        } finally {
            try {
                if (stmt != null)
                    stmt.close();
                if (conn != null)
                    conn.close();
            } catch (SQLException se) {
                log.info("Error closing SQL connection and statements: {} ", se.getMessage());
            }
            return res;
        }
    }

    private BasicResPo buildResponsefromCopyLog (Connection conn, Long copyId) {
        BasicResPo res = new BasicResPo();
        try {
            PreparedStatement logStmnt = conn.prepareStatement(
                    "select log_clob, status, error_msg from cr_copy_log where copy_id=?");
            logStmnt.setLong(1, copyId);
            ResultSet rsLog = logStmnt.executeQuery();
            String logClob = null;
            String errorMsg = null;
            String copyStatus = null;
            if (rsLog.next()) {
                copyStatus = rsLog.getString("status");
                logClob = rsLog.getString("log_clob");
                errorMsg = rsLog.getString("error_msg");
            }
            log.info("Copy status: {} ", copyStatus);
            log.info("log clob: {} ", logClob);
            if ("ERROR".equalsIgnoreCase(copyStatus)) {
                log.info("Error Message: {} ", errorMsg);
                res.setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                res.setStatus(copyStatus);
                res.setMessage(errorMsg);
                res.setPayload(logClob);
            } else {
                res.setStatusCode(HttpStatus.OK);
                res.setStatus(copyStatus);
                res.setPayload(logClob);
            }
        } catch (Exception e) {
            log.error("Error during buildResponsefromCopyLog:",e);
            res.setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
            res.setStatus("error");
            res.setMessage(e.getMessage());
            res.setPayload(e);
        }
        return res;
    }

    @Override
    public BasicResPo viewCopyLogs(String sourcePOD) {
        String copyLogQuery = "select copy_id, source_pod, destination_pod, object_ids, project_name, status, error_msg, creation_date from cr_copy_log " +
                              " where source_pod='" + sourcePOD + "' order by copy_id desc fetch first 30 rows only";
        Connection connection = null;
        List<CRCopyLogsResPo> copyLogsResPoList = new ArrayList<>();
        try {
            connection = DriverManager.getConnection(url, username, password);
            try (PreparedStatement copyLogsStatement = connection.prepareStatement(copyLogQuery)) {
                ResultSet rs = copyLogsStatement.executeQuery();
                while (rs.next()) {
                    copyLogsResPoList.add(getCrCopyLogsResPo(rs));
                }
            }
        } catch (SQLException ex) {
            new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("failed");
                setMessage("Failed to retrieve copy logs");
            }};
        } finally {
            try {
                connection.close();
            } catch (SQLException e) {
                throw new RuntimeException("Exception while closing the connection");
            }
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved copy logs");
            setPayload(copyLogsResPoList);
        }};
    }

    private static CRCopyLogsResPo getCrCopyLogsResPo(ResultSet rs) throws SQLException {
        CRCopyLogsResPo cRCopyLogsResPo = new CRCopyLogsResPo();
        cRCopyLogsResPo.setCopyId(rs.getLong("copy_id"));
        cRCopyLogsResPo.setSourcePOD(rs.getString("source_pod"));
        cRCopyLogsResPo.setDestinationPOD(rs.getString("destination_pod"));
        cRCopyLogsResPo.setObjectIds(rs.getString("object_ids"));
        cRCopyLogsResPo.setProjectName(rs.getString("project_name"));
        String status = rs.getString("status");
        cRCopyLogsResPo.setStatus(status);
        String errMsg = rs.getString("error_msg");
        if("WARNING".equalsIgnoreCase(status)) {
            errMsg = "COPIED WITH WARNINGS, PLEASE CHECK THE LOG";
        }
        cRCopyLogsResPo.setErrorMsg(errMsg);
        cRCopyLogsResPo.setCreationDate(rs.getTimestamp ("creation_date"));
        return cRCopyLogsResPo;
    }

    @Override
    public void downloadLogClob(Long copyId, HttpServletResponse response) {
        String copyLogQuery = "select log_clob from cr_copy_log where copy_id=" + copyId;
        Connection connection = null;
        try {
            connection = DriverManager.getConnection(url, username, password);
            try (PreparedStatement copyLogsStatement = connection.prepareStatement(copyLogQuery)) {
                ResultSet rs = copyLogsStatement.executeQuery();
                if (rs.next()) {
                    String res = clobToString(rs.getClob("log_clob"));
                    PrintWriter writer = response.getWriter();
                    writer.write(res);
                }
            } catch (IOException e) {
                throw new RuntimeException(e);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        } catch (SQLException ex) {
            log.error("Failed to download ");
        } finally {
            try {
                connection.close();
            } catch (SQLException e) {
                throw new RuntimeException("Exception while closing the connection");
            }
        }
    }

    private static String clobToString(Clob data) throws Exception {
        StringBuilder sb = new StringBuilder();
        try {
            Reader reader = data.getCharacterStream();
            BufferedReader br = new BufferedReader(reader);

            String line;
            while (null != (line = br.readLine())) {
                log.debug(line + "::::::line");
                sb.append(line);
                sb.append("\n");
            }
            br.close();
        } catch (SQLException e) {
            throw new Exception(e.getMessage());
        } catch (IOException e) {
            throw new Exception(e.getMessage());
        }
        return sb.toString();
    }
}
