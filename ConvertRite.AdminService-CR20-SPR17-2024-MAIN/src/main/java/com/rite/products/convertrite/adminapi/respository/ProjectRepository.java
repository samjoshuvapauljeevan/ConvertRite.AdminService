package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.Project;
import com.rite.products.convertrite.adminapi.po.ProjectsWithObjectsPo;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface ProjectRepository extends JpaRepository<Project, Long> {

    @Query("select p from Project p where p.podId=:podId order by p.projectId")
    List<Project> findAllByPodId(@Param("podId") Long podId);

    @Query("select p from Project p where p.clientId=:clientId order by p.projectId")
    List<Project> findAllByClientId(@Param("clientId") Long clientId);

    @Query("select count(p) from Project p where p.podId=:podId")
    Long getExistingProjectCountWithPodId(@Param("podId") Long podId);

    @Transactional
    @Query("select p from Project p where  p.clientId=:clientId and p.podId=:podId order by p.projectId")
    List<Project> findAllByClientIdAndPodId(Long clientId, Long podId);

    @Transactional
    @Query("select p from Project p where  p.clientId=:clientId and p.podId=:podId and p.projectName=:projectName order by p.projectId")
    List<Project> findAllByClientIdAndPodIdAndProjectName(Long clientId, Long podId, String projectName);
}
