package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.Client;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ClientRepository extends JpaRepository<Client, Long> {
    List<Client> findByOrderByClientIdAsc();
}
