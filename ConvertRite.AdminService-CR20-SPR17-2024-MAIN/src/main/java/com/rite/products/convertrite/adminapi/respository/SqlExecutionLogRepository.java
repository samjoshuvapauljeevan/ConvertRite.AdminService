package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.SqlExecutionLog;
import org.springframework.transaction.annotation.Transactional;
import org.apache.ibatis.annotations.Param;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.sql.Timestamp;
import java.util.List;

public interface SqlExecutionLogRepository extends JpaRepository<SqlExecutionLog, Long> {
    @Query(value = "SELECT e.sqlFilePath FROM SqlExecutionLog e WHERE e.clientId = :clientId AND e.success = TRUE ORDER BY e.createdTime DESC")
    List<String> findSuccessfulSqlFilePathsByClientId(@Param("clientId") Long clientId);

    // This method gets the latest version by created_time for each pod
    @Query("SELECT l.podId, MAX(l.createdTime) FROM SqlExecutionLog l WHERE l.clientId = :clientId AND l.success = TRUE GROUP BY l.podId")
    List<Object[]> findLatestTimestampsPerPodByClientId(@Param("clientId") Long clientId);

    SqlExecutionLog findFirstByPodIdAndClientIdAndCreatedTime(@Param("podId") Long podId, @Param("clientId") Long clientId, @Param("createdTime") Timestamp createdTime);

    @Transactional
    void deleteSqlExecutionLogByPodId(Long podId);}


