package com.rite.products.convertrite.adminapi.po;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class CopyObjAndObjectInfoReq {
    @NotNull(message = "oldObjectId cannot be null")
    private Long oldObjectId;
    @NotEmpty(message="objectNameSuffix cannot be empty")
    private String objectNameSuffix;
}
