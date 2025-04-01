package com.rite.products.convertrite.adminapi.po;

import com.rite.products.convertrite.adminapi.model.CRObject;
import com.rite.products.convertrite.adminapi.model.CRTargetInterfaceColumn;
import com.rite.products.convertrite.adminapi.model.CrObjectInformation;
import lombok.Data;

import java.util.List;

@Data
public class CopyObjAndObjectInfoRes {
    private CRObject crObject;
    private List<CrObjectInformation> crObjectInformationList;
    private List<CRTargetInterfaceColumn> cRTargetInterfaceColumns;
}
