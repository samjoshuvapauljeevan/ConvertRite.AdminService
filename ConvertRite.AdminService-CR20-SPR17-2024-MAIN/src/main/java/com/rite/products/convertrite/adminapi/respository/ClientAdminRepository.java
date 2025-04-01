package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.ClientAdmin;
import jakarta.transaction.Transactional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Transactional
@Repository
public interface ClientAdminRepository extends JpaRepository<ClientAdmin, Long> {
    List<ClientAdmin> findByOrderByClientAdminIdAsc();

    ClientAdmin findByClientAdminUserName(String userName);

    Boolean existsByClientAdminUserName(String userName);
}
