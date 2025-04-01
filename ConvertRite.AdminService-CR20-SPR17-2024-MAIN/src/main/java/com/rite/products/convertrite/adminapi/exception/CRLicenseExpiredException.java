package com.rite.products.convertrite.adminapi.exception;

public class CRLicenseExpiredException extends RuntimeException {

    public CRLicenseExpiredException(String message) {
        super(message);
    }

    public CRLicenseExpiredException(String message, Throwable cause) {
        super(message, cause);
    }

    public CRLicenseExpiredException(Throwable cause) {
        super(cause);
    }
}
