package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.CrRsPodInformation;
import com.rite.products.convertrite.adminapi.model.CrRsPodInformation1;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CrRsPodInformationRepo1 extends JpaRepository<CrRsPodInformation1,Long> {
       List<CrRsPodInformation1> findAllByLicenseId(Long clientId);
}
