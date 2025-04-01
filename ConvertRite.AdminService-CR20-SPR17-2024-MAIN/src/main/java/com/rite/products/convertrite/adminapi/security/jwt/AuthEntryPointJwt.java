package com.rite.products.convertrite.adminapi.security.jwt;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.rite.products.convertrite.adminapi.po.BasicResPo;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Slf4j
@Component
public class AuthEntryPointJwt implements AuthenticationEntryPoint {

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response, AuthenticationException authException)
            throws IOException, ServletException {
        log.error("Unauthorized error: {}", authException.getMessage());

        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);

        String message = authException.getMessage();

        if(authException instanceof BadCredentialsException) {
            message = "Incorrect password";
        }

        String finalMessage = message;

        BasicResPo responsePayload = new BasicResPo() {{
            setStatus("error");
            setMessage(finalMessage);
            setStatusCode(HttpStatus.UNAUTHORIZED);
            setPayload(authException);
        }};

        final ObjectMapper mapper = new ObjectMapper();
        mapper.writeValue(response.getOutputStream(), responsePayload);
    }
}
