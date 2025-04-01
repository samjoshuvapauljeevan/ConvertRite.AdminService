package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.service.DataSourceService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RequestMapping(value = "/api/convertriteadmin")
@RestController
public class DataSourceController {
    @Autowired
    DataSourceService dataSourceService;
    @GetMapping("/getDataSourceDetails")
    public BasicResPo getDataSourceDetails()  {
        BasicResPo resPo= dataSourceService.getDataSourceDetails();
        return resPo;
    }
}
