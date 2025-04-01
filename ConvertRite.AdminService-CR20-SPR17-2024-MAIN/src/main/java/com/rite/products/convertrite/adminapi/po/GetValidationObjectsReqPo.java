package com.rite.products.convertrite.adminapi.po;

import java.util.List;
import lombok.Data;

@Data
public class GetValidationObjectsReqPo {
    private List<Long> objectIdLi;
}