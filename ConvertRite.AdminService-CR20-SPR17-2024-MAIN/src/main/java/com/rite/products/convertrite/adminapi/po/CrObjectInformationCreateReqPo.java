package com.rite.products.convertrite.adminapi.po;

import lombok.Data;

@Data
public class CrObjectInformationCreateReqPo {
    private Long objInfoId;
    private Long objectId;
    private String info_type;
    private String info_value;
    private String info_description;
    private String additional_information1;
    private String additional_information2;
    private String additional_information3;
    private String additional_information4;
    private String additional_information5;
    private String insertOrDelete;
    private String created_by;
}
