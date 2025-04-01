package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface RoleRepository extends JpaRepository<Role, Long> {

    @Query("select r from Role r where r.podId=:podId order by r.roleId")
    List<Role> findAllByPodId(@Param("podId") Long podId);

    @Query("select r from Role r where r.clientId=:clientId order by r.roleId")
    List<Role> findAllByClientId(@Param("clientId") Long clientId);
}
