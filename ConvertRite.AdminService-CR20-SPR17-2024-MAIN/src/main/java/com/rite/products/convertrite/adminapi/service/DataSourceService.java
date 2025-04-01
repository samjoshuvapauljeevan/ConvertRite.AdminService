package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.po.DataSourcePropertiesPo;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class DataSourceService {
    @Value("${spring.datasource.url}")
    private String dataSourceUrl;
    @Value("${spring.datasource.username}")
    private String dataSourceUserName;
    @Value("${spring.datasource.password}")
    private String dataSourcePassword;

    public BasicResPo getDataSourceDetails() {
        BasicResPo resPo = new BasicResPo();
        DataSourcePropertiesPo dataSourcePropertiesPo = new DataSourcePropertiesPo();

        try {
            dataSourcePropertiesPo.setUrl(dataSourceUrl);
            dataSourcePropertiesPo.setUsername(dataSourceUserName);
            dataSourcePropertiesPo.setPassword(dataSourcePassword);

            resPo.setPayload(dataSourcePropertiesPo);
            resPo.setMessage("Successfully Fetched Datasource Details");
            resPo.setStatus("success");
            resPo.setStatusCode(HttpStatus.OK);
        } catch (Exception e) {
            log.error("Exception in getDataSourceDetails()--------> {} ", e.getMessage(), e);
        }
        return resPo;
    }
}
