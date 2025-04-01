package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.exception.CRAdminException;
import com.rite.products.convertrite.adminapi.exception.CRNotAllowedException;
import com.rite.products.convertrite.adminapi.exception.CRNotFoundException;
import com.rite.products.convertrite.adminapi.exception.CRUniquenessException;
import org.hibernate.exception.ConstraintViolationException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.jpa.repository.JpaRepository;

public class BasicManagementService<T1, T2> {
    public T1 addEntity(JpaRepository<T1, T2> repository, T1 entity) {
        try {
            return repository.save(entity);
        } catch (Exception ex) {
            if (ex instanceof DataIntegrityViolationException && ex.getCause() instanceof ConstraintViolationException) {
                if (ex.getCause().getCause().getMessage().startsWith("ERROR: duplicate key value violates unique constraint")) {
                    throw new CRUniquenessException("Uniqueness violation", ex);
                }
            }
            throw new CRAdminException("Error in creating new entity", ex);
        }
    }

    public T1 getEntityById(JpaRepository<T1, T2> repository, T2 id) {
        return repository.findById(id).orElseThrow(() -> new CRNotFoundException("Entity not found with id " + id));
    }

    public T1 updateEntity(JpaRepository<T1, T2> repository, T1 entity) {
        try {
            return repository.save(entity);
        } catch (Exception ex) {
            if (ex instanceof DataIntegrityViolationException && ex.getCause() instanceof ConstraintViolationException) {
                if (ex.getCause().getCause().getMessage().startsWith("ERROR: duplicate key value violates unique constraint")) {
                    throw new CRUniquenessException(ex.getCause().getCause().getMessage(), ex);
                }
            }
            throw new CRAdminException("Error in updating entity", ex);
        }
    }

    public void deleteEntityById(JpaRepository<T1, T2> repository, T2 id) {
        if (repository.existsById(id)) {
            try {
                repository.deleteById(id);
            } catch (Exception ex) {
                if (ex instanceof DataIntegrityViolationException && ex.getCause() instanceof ConstraintViolationException) {
                    String message = ex.getCause().getCause().getMessage();
                    if (message.startsWith("ERROR: update or delete on table") && message.contains("violates foreign key constraint")) {
                        throw new CRNotAllowedException("Deletion not allowed as it is used in other entities.", ex);
                    }
                }
                throw new CRAdminException("Error in deleting entity", ex);
            }
        } else {
            throw new CRNotFoundException("Entity not found with id " + id);
        }
    }
}
