package com.rite.products.convertrite.adminapi.po;

import java.util.List;

public class LoginResPo {
    private String token;
    private String type = "Bearer";
    private Long id;
    private String username;
    private String email;
    private List<String> roles;
    private Boolean isFirstTimeLogin;
    private String additionalFeature;




    public LoginResPo(String token, Long id, String username, List<String> roles, Boolean isFirstTimeLogin, String additionalFeature) {
        this.token = token;
        this.id = id;
        this.username = username;
        this.roles = roles;
        this.isFirstTimeLogin = isFirstTimeLogin;
        this.additionalFeature = additionalFeature;

    }

    public Boolean getFirstTimeLogin() {
        return isFirstTimeLogin;
    }

    public void setFirstTimeLogin(Boolean firstTimeLogin) {
        isFirstTimeLogin = firstTimeLogin;
    }

    public String getAccessToken() {
        return token;
    }

    public void setAccessToken(String accessToken) {
        this.token = accessToken;
    }

    public String getTokenType() {
        return type;
    }

    public void setTokenType(String tokenType) {
        this.type = tokenType;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public List<String> getRoles() {
        return roles;
    }

    public String getAdditionalFeature() {
        return additionalFeature;
    }

    public void setAdditionalFeature(String additionalFeature) {
        this.additionalFeature = additionalFeature;
    }
}
