package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.model.ValidationObject;
import com.rite.products.convertrite.adminapi.po.ExecuteCustomObjectRequest;
import com.rite.products.convertrite.adminapi.po.ValidateSqlObjectRequest;

import java.io.IOException;
import java.util.List;
import java.util.Map;

public interface ValidationService {

    String compileAndUploadSql(ValidateSqlObjectRequest request, String username) throws IOException ;

    String executeCustomValidationObjects(ExecuteCustomObjectRequest request, String username) throws IOException;

    public Map<Long, List<ValidationObject>> fetchCustomObjectsMap(List<Long> objectIds);

}
