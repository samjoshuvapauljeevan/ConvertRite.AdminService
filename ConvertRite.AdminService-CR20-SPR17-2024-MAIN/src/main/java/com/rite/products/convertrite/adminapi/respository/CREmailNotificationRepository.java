package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.CREmailNotifications;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface CREmailNotificationRepository extends JpaRepository<CREmailNotifications, Long> {
    List<CREmailNotifications> findByStatusIn(List<String> statuses);
}
