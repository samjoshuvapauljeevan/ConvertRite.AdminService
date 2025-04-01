package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.CrObjectInformation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;

public interface ObjectInformationRepository extends JpaRepository<CrObjectInformation, Long> {

    List<CrObjectInformation> findByObjectIdOrderByObjInfoIdAsc(Long objectId);

    @Query("SELECT objInfoId FROM CrObjectInformation")
    List<Long> findAllIds();
}
