package com.rite.products.convertrite.adminapi.respository;

import com.rite.products.convertrite.adminapi.model.User;
import jakarta.transaction.Transactional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
@Transactional
@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    @Query("select u from User u where u.clientId=:clientId order by u.userId")
    List<User> findAllByClientId(@Param("clientId") Long clientId);

    User findByUserName(String userName);
    User findByEmail(String email);

    Boolean existsByUserName(String userName);
    Boolean existsByEmail(String email);
}
