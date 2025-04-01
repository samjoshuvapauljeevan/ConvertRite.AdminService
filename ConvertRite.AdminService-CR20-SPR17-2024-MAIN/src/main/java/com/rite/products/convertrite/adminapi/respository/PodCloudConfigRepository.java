package com.rite.products.convertrite.adminapi.respository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import com.rite.products.convertrite.adminapi.model.CloudLogin;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Repository
@Transactional(isolation = Isolation.SERIALIZABLE)
public interface PodCloudConfigRepository extends JpaRepository<CloudLogin, Integer> {

    List<CloudLogin> findByOrderByCredentialIdAsc();

    @Query("select c.podId from CloudLogin c where c.credentialId=:credentialId")
    Long findByCredentialId(Integer credentialId);

    CloudLogin findByClientIdAndPodIdAndModuleCode(int clientId, Long podId, String moduleCode);

    @Query("select c from CloudLogin c where c.clientId=:clientId order by c.credentialId")
    List<CloudLogin> findAllByClientId(@Param("clientId") Long clientId);

    List<CloudLogin> findByClientIdAndPodId(Long clientId, Long podId);

    @Transactional
    void deleteAllByClientIdAndPodId(Long clientId, Long podId);

    List<CloudLogin> findAllByClientIdAndPodId(Long clientId, Long podId);

    List<CloudLogin> findAllByPodId(Long podId);

}
