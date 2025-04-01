package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.MasterDb;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface MasterDbRepository extends JpaRepository<MasterDb,Long> {
}
