package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.Pod;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface PodRepository extends JpaRepository<Pod, Long> {
    List<Pod> findByOrderByPodIdAsc();

    @Query("select count(p) from Pod p where p.licenseId=:licenseId")
    Long getExistingPodCountWithLicenseId(@Param("licenseId") Long licenseId);

    @Query("select distinct p.client.clientId from Pod p")
    List<Long> findAllUniqueClientIds();

    @Query("select p from Pod p where p.client.clientId=:clientId order by p.podId")
    List<Pod> getPodsByClientId(@Param("clientId") Long clientId);

    @Query("select p from Pod p, ClientAdmin ca where ca.clientAdminId=:clientAdminId and ca.client.clientId= p.client.clientId order by p.podId")
    List<Pod> getPodsByClientAdminId(@Param("clientAdminId") Long clientAdminId);

    @Modifying
    @Transactional
    @Query(value= "delete from cr_client_admin_pod_access where pod_id = :podId", nativeQuery = true)
    void deletePodClientAdminLinks(@Param("podId") Long podId);

    @Modifying
    @Transactional
    @Query(value = "delete from cr_role_obj_links where role_id in (select role_id from cr_roles where pod_id=:podId)", nativeQuery = true)
    void deletePodRoleObjectLinks(@Param("podId") Long podId);

    @Modifying
    @Transactional
    @Query(value = "delete from cr_user_role_links where role_id in (select role_id from cr_roles where pod_id=:podId)", nativeQuery = true)
    void deletePodRoleUserLinks(@Param("podId") Long podId);

    @Modifying
    @Transactional
    @Query(value = "delete from cr_roles where pod_id=:podId", nativeQuery = true)
    void deletePodRoles(@Param("podId") Long podId);

    @Modifying
    @Transactional
    @Query(value = "delete from cr_cloud_import_object_links where credential_id in (select credential_id from cr_cloud_login_details where pod_id=:podId)", nativeQuery = true)
    void deletePodCredentialObjectLinks(@Param("podId") Long podId);

    @Modifying
    @Transactional
    @Query(value = "delete from cr_cloud_login_details where pod_id=:podId", nativeQuery = true)
    void deletePodCredentials(@Param("podId") Long podId);

    @Modifying
    @Transactional
    @Query(value = "delete from cr_project_objects where project_id in (select project_id from cr_projects where pod_id=:podId)", nativeQuery = true)
    void deletePodProjectObjectLinks(@Param("podId") Long podId);

    @Modifying
    @Transactional
    @Query(value = "delete from cr_projects where pod_id=:podId", nativeQuery = true)
    void deletePodProjects(@Param("podId") Long podId);

    @Modifying
    @Transactional
    @Query(value = "delete from cr_pod_information where pod_id=:podId", nativeQuery = true)
    void deletePodInformationById(@Param("podId") Long podId);}
