package com.rite.products.convertrite.adminapi.exception;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

@RestControllerAdvice
@Slf4j
public class CRResponseExceptionHandler  extends  ResponseEntityExceptionHandler{
    @ExceptionHandler(Exception.class)
    protected ResponseEntity<Object> handleException(
            RuntimeException ex, WebRequest request) {
        log.error("Error in Admin Service--> {} ", ex.getMessage());
        String message = ex.getMessage();
        log.info("CRResponseExceptionHandler----> {} ", message);
        HttpStatus status = HttpStatus.INTERNAL_SERVER_ERROR;
        if(ex instanceof BadCredentialsException) {
            message = "Incorrect password";
            status = HttpStatus.UNAUTHORIZED;
        } else if (ex instanceof ExpiredJwtException) {
            message = "Session expired. Sign-in again to continue.";
            status = HttpStatus.UNAUTHORIZED;
        } else if (ex instanceof JwtException) {
            message = "Invalid token";
            status = HttpStatus.UNAUTHORIZED;
        } else if (ex instanceof CRLicenseExpiredException) {
            message = ex.getMessage();
            status = HttpStatus.PRECONDITION_FAILED;
        }

        String finalMessage = message;
        HttpStatus finalStatus = status;
        BasicResPo responsePayload = new BasicResPo() {{
            setStatus("error");
            setMessage(finalMessage);
            setStatusCode(finalStatus);
            setPayload(ex);
        }};

        return handleExceptionInternal(ex, responsePayload,
                new HttpHeaders(), responsePayload.getStatusCode(), request);
    }

}
