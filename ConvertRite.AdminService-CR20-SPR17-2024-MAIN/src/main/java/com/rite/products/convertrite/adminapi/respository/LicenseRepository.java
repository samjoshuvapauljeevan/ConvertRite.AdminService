package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.License;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface LicenseRepository extends JpaRepository<License, Long> {
    List<License> findByOrderByLicenseIdAsc();
}
