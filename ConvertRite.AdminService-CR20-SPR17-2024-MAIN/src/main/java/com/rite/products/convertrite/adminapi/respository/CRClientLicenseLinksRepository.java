package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.CRClientLicenseLinks;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CRClientLicenseLinksRepository extends JpaRepository<CRClientLicenseLinks,Long> {
    CRClientLicenseLinks findByClientId(Long clientId);

    @Query("select l.additionalFeature from CRClientLicenseLinks crl join License l on crl.licenseId = l.licenseId where crl.clientId = :clientId")
    String findAdditionalFeaturesByClientId(@Param("clientId") Long clientId);

}
