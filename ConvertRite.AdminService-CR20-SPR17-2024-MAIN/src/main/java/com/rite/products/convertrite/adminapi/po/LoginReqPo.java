package com.rite.products.convertrite.adminapi.po;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class LoginReqPo {
    @NotBlank
    private String username;
    @NotBlank
    private String password;
    @NotBlank
    private String role;
}
