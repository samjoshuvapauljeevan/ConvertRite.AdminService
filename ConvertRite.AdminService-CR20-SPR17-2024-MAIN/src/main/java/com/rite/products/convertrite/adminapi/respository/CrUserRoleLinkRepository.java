package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.CrUserRoleLink;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface CrUserRoleLinkRepository extends JpaRepository<CrUserRoleLink,Long> {
}
