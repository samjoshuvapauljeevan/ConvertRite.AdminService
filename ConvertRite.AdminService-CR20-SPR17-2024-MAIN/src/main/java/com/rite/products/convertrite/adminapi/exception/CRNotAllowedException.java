package com.rite.products.convertrite.adminapi.exception;

public class CRNotAllowedException extends RuntimeException {

    public CRNotAllowedException(String message) {
        super(message);
    }

    public CRNotAllowedException(String message, Throwable cause) {
        super(message, cause);
    }

    public CRNotAllowedException(Throwable cause) {
        super(cause);
    }
}
