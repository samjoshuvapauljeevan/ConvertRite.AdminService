package com.rite.products.convertrite.adminapi.utils;

import lombok.extern.slf4j.Slf4j;
import oracle.jdbc.pool.OracleDataSource;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import java.sql.Connection;

@Slf4j
@Component
public class DataSourceUtil {

    @Value("${oracle.datasource.hostname}")
    private String datasourceHostName;
    @Value("${oracle.datasource.port}")
    private int datasourcePort;
    @Value("${oracle.datasource.username}")
    private String datasourceUserName;
    @Value("${oracle.datasource.password}")
    private String datasourcePassword;
    @Value("${oracle.datasource.sid}")
    private String dataSourceName;

    public Connection createOracleConnection() throws Exception {
        Connection con = null;
        log.info("createOracleConnection---> {} ", datasourceHostName);
        try {
            // System.out.println("datasourceHostName:::::"+datasourceHostName+"datasourceUserName::::::"+datasourceUserName+"datasourcePassword::::"+datasourcePassword+"dataSourceName:::::"+dataSourceName+"datasourcePort::"+datasourcePort);
            Class.forName("oracle.jdbc.driver.OracleDriver");
            OracleDataSource dataSource = new OracleDataSource();
            dataSource.setServerName(datasourceHostName);
            dataSource.setUser(datasourceUserName);
            dataSource.setPassword(datasourcePassword);
            dataSource.setServiceName(dataSourceName);
            dataSource.setPortNumber(datasourcePort);
            dataSource.setDriverType("thin");
            con = dataSource.getConnection();
        } catch (Exception e) {
            log.error(e.getMessage());
            throw new Exception(e.getMessage());
        }
        return con;
    }

    /*public Connection createPostgresConnection() throws Exception {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl("jdbc:postgresql://localhost:5434/master");
        config.setUsername("admin");
        config.setPassword("root");
        config.addDataSourceProperty("cachePrepStmts", "true");
        config.addDataSourceProperty("prepStmtCacheSize", "250");
        config.addDataSourceProperty("prepStmtCacheSqlLimit", "2048");
        HikariDataSource ds = new HikariDataSource(config);
        return ds.getConnection();
    }*/
}
