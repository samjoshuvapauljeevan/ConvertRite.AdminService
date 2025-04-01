package com.rite.products.convertrite.adminapi.po;

import lombok.Data;

@Data
public class ResetPasswordPo {
    private String emailId;
    private String clientAdminPassword;

}
