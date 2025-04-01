package com.rite.products.convertrite.adminapi.respository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.rite.products.convertrite.adminapi.model.CRLicensedObjects;

public interface CRLicensedObjectsRepository extends JpaRepository<CRLicensedObjects, Integer> {

    List<CRLicensedObjects> findAllByLicenseId(Long licenseId);

}
