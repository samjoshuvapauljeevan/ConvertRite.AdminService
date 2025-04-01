package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.CRCloudImportObjectLink;

import java.util.List;
import java.util.Set;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;
@Repository
public interface CRCloudImportObjectLinkRepository extends JpaRepository<CRCloudImportObjectLink, Long> {


    @Query("select c.objectId from CRCloudImportObjectLink c where c.credentialId=:credentialId")
    List<Long> findAllByCredentialId(@Param("credentialId")Integer credentialId);
    @Query("select c from CRCloudImportObjectLink c where c.credentialId=:credentialId")
    List<CRCloudImportObjectLink> getAllByCredentialId(@Param("credentialId")Long credentialId);

    @Transactional
    void deleteAllByCredentialId(Integer credentialId);
    @Query("select c.credentialId from CRCloudImportObjectLink c where c.objectId=:objectId")
    Set<Integer> findAllByObjectId(@Param("objectId")Long objectId);


    @Query("select c.objectId from CRCloudImportObjectLink c where c.credentialId=:credentialId")
    List<Long> findAllByCredentialId(@Param("credentialId") Long credentialId);


    @Transactional
    void deleteAllByCredentialId(Long credentialId);

}
