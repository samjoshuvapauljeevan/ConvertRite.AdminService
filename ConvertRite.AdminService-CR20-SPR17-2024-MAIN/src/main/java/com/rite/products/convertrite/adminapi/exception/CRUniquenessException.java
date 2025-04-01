package com.rite.products.convertrite.adminapi.exception;

public class CRUniquenessException extends RuntimeException {

    public CRUniquenessException(String message) {
        super(message);
    }

    public CRUniquenessException(String message, Throwable cause) {
        super(message, cause);
    }

    public CRUniquenessException(Throwable cause) {
        super(cause);
    }
}
