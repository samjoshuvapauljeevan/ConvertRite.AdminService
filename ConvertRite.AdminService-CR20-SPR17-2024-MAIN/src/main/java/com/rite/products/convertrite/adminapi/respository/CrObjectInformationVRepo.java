package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.CrObjectInformationV;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface CrObjectInformationVRepo extends JpaRepository<CrObjectInformationV,Long> {
    Optional<List<CrObjectInformationV>> findAllByParentObjectId(long parentObjectId);
}
