package com.rite.products.convertrite.adminapi.po;

import lombok.Data;

import java.util.List;

@Data
public class CopyParentObjRes {
    private String parentObjectName;
    private List<String> childObjectNames;
    private List<CopyObjAndObjectInfoRes> CopyObjAndObjectInfoResLi;
}
