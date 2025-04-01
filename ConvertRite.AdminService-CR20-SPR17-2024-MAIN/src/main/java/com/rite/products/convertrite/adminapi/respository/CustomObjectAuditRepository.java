package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.ValidationObjectAudit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface CustomObjectAuditRepository extends JpaRepository<ValidationObjectAudit, Long> {
}