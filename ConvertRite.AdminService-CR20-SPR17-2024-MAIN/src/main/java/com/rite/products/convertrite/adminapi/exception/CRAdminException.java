package com.rite.products.convertrite.adminapi.exception;

public class CRAdminException extends RuntimeException {

    public CRAdminException(String message) {
        super(message);
    }

    public CRAdminException(String message, Throwable cause) {
        super(message, cause);
    }

    public CRAdminException(Throwable cause) {
        super(cause);
    }
}
