package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.CRTargetInterfaceColumn;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CRTargetInterfaceColumnRepository extends JpaRepository<CRTargetInterfaceColumn, Long> {

    List<CRTargetInterfaceColumn> findAllByObjectId(Long objectId);
}
