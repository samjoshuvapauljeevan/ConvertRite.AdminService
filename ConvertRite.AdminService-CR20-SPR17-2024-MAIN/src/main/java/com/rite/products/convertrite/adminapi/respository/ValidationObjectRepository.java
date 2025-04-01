package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.ValidationObject;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ValidationObjectRepository extends JpaRepository<ValidationObject, Long> {


    @Query("SELECT c FROM ValidationObject c WHERE c.filename = :filename")
    Optional<ValidationObject> findByFilename(String filename);

    @Query("SELECT c FROM ValidationObject c WHERE c.objectId IN :objectIds")
    List<ValidationObject> findByObjectIds(List<Long> objectIds);

}