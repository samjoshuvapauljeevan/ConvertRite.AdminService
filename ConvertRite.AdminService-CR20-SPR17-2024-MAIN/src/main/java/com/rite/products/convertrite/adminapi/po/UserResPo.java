package com.rite.products.convertrite.adminapi.po;

import java.util.List;

public class UserResPo {
    private Long userId;
    private String userName;
    private String password;
    private String personName;
    private String email;
    private String userLoginType;
    private ClientResPo client;
    private List<RoleResPo> roles;

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public String getUserName() {
        return userName;
    }

    public void setUserName(String userName) {
        this.userName = userName;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getPersonName() {
        return personName;
    }

    public void setPersonName(String personName) {
        this.personName = personName;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getUserLoginType() {
        return userLoginType;
    }

    public void setUserLoginType(String userLoginType) {
        this.userLoginType = userLoginType;
    }
    public ClientResPo getClient() {
        return client;
    }

    public void setClient(ClientResPo client) {
        this.client = client;
    }

    public List<RoleResPo> getRoles() {
        return roles;
    }

    public void setRoles(List<RoleResPo> roles) {
        this.roles = roles;
    }
}
