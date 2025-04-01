package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.RiteAdmin;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RiteAdminRepository extends JpaRepository<RiteAdmin, Long> {
    RiteAdmin findByRiteAdminUserName(String userName);

    Boolean existsByRiteAdminUserName(String userName);
}
