package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.CrRsPodInformation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CrRsPodInformationRepo extends JpaRepository<CrRsPodInformation,Long> {
    @Query("select count(p) from CrRsPodInformation p where p.licenseId=:licenseId")
    Long getExistingPodCountWithLicenseId(@Param("licenseId") Long licenseId);
    List<CrRsPodInformation> findAllByLicenseId(Long clientId);

}
