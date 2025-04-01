package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.CRObject1;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface Object1Repository extends JpaRepository<CRObject1, Long> {

    List<CRObject1> findByObjectIdIn(List<Long> objectId);
}