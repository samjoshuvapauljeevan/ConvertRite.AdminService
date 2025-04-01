package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.DataSyncExecutionLog;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DataSyncExecutionLogRepository extends JpaRepository<DataSyncExecutionLog, Long> {
}
