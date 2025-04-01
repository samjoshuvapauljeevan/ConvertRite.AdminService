package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.CRObject;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Set;

public interface ObjectRepository extends JpaRepository<CRObject, Long> {


    @Query("SELECT  co FROM CrUserRoleLink cur,CrRoleObjectLink cro,CRObject co, CRProjectObjects cpo\n" +
            "WHERE cur.userId  =:userId AND cur.roleId  = cro.roleId AND cro.objectId =co.objectId AND cpo.projectId =:projectId\n" +
            "AND co.objectId = cpo.objectId AND parentObjectId IS NULL")
    Set<CRObject> getParentObjects(Long userId, Long projectId);
    @Query("select co FROM CrUserRoleLink cur,CrRoleObjectLink cro,CRObject co WHERE cur.userId =:userId AND cur.roleId = cro.roleId AND cro.objectId= co.objectId AND co.parentObjectId is not null")
    Set<CRObject> getAllObjectsByUserId(Long userId);

    @Query("SELECT c FROM CRObject c " +
            "INNER JOIN CRLicensedObjects l ON c.objectId = l.object_id " +
            "INNER JOIN CRClientLicenseLinks cl ON l.licenseId = cl.licenseId " +
            "WHERE cl.clientId = :clientId AND cl.licenseId IS NOT NULL " +
            "ORDER BY c.parentObjectId, c.objectId")
    List<CRObject> findByClientId(@Param("clientId") Long clientId);
    List<CRObject> findByModuleCode(String moduleCode);

    CRObject findByObjectNameIgnoreCase(String newObjectName);

    List<CRObject> findByParentObjectId(Long parentObjectId);

    @Query(value = "select c from CRObject c where c.objectName!='' and not c.objectName like '%-%' and c.parentObjectId is null order by c.objectName")
    List<CRObject> getParentObjects();

}

