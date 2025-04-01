package com.rite.products.convertrite.adminapi.exception;

public class CRNotFoundException extends RuntimeException {

    public CRNotFoundException(String message) {
        super(message);
    }

    public CRNotFoundException(String message, Throwable cause) {
        super(message, cause);
    }

    public CRNotFoundException(Throwable cause) {
        super(cause);
    }
}
