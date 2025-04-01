package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.exception.CRNotFoundException;
import com.rite.products.convertrite.adminapi.model.ClientAdmin;
import com.rite.products.convertrite.adminapi.model.RiteAdmin;
import com.rite.products.convertrite.adminapi.model.User;
import com.rite.products.convertrite.adminapi.respository.ClientAdminRepository;
import com.rite.products.convertrite.adminapi.respository.RiteAdminRepository;
import com.rite.products.convertrite.adminapi.respository.UserRepository;
import com.rite.products.convertrite.adminapi.security.jwt.JwtUtils;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@RequiredArgsConstructor
@Service
@Slf4j
public class AuthServiceImpl implements UserDetailsService {

    @Autowired
    UserRepository userRepository;

    @Autowired
    ClientAdminRepository clientAdminRepository;

    @Autowired
    RiteAdminRepository riteAdminRepository;
    @Autowired
    HttpServletRequest request;
    @Autowired
    JwtUtils jwtUtils;
    @Override
    public UserDetails loadUserByUsername(String userName) {
        AuthUserDetailsImpl authUserDetailsImpl = null;
        // try {
        String jwt = parseJwt(request);
        if(jwt!=null) {
            String role= jwtUtils.getRolesFromJwtToken(jwt).get(0);
            //Constants.ROLE.set(role);
            request.setAttribute("ROLE",role);
        }
        //String role = Constants.ROLE.get();
        //log.info("Constants.ROLE=---> {} ", role);
        String role = request.getAttribute("ROLE").toString();
        log.info("request.ROLE=---> {} ", request.getAttribute("ROLE"));
        if (userRepository.existsByEmail(userName)&&role.equalsIgnoreCase("ROLE_USER")) {
            log.info("existsByEmail {}", userRepository.existsByEmail(userName));
            User user = userRepository.findByEmail(userName);
            authUserDetailsImpl = new AuthUserDetailsImpl(user.getUserId(), user.getEmail(), user.getPassword(), "ROLE_USER");
        } else if (clientAdminRepository.existsByClientAdminUserName(userName)&&role.equalsIgnoreCase("ROLE_CLIENTADMIN")) {
            log.info("existsByClientAdminUserName {} ", clientAdminRepository.existsByClientAdminUserName(userName));
            ClientAdmin clientAdmin = clientAdminRepository.findByClientAdminUserName(userName);
            authUserDetailsImpl = new AuthUserDetailsImpl(clientAdmin.getClientAdminId(), clientAdmin.getClientAdminUserName(), clientAdmin.getClientAdminPassword(), "ROLE_CLIENTADMIN");
        } else if (riteAdminRepository.existsByRiteAdminUserName(userName)&&role.equalsIgnoreCase("ROLE_RITEADMIN")) {
            log.info("existsByRiteAdminUserName {} ", riteAdminRepository.existsByRiteAdminUserName(userName));
            RiteAdmin riteAdmin = riteAdminRepository.findByRiteAdminUserName(userName);
            authUserDetailsImpl = new AuthUserDetailsImpl(riteAdmin.getRiteAdminId(), riteAdmin.getRiteAdminUserName(), riteAdmin.getRiteAdminPassword(), "ROLE_RITEADMIN");
        }

        if (authUserDetailsImpl == null) {
            throw new CRNotFoundException("User with the username '" + userName + "' does not exist.");
        }
        log.info("authUserDetailsImpl : {}", authUserDetailsImpl);
        //    }
//        catch(Exception e){
//            e.printStackTrace();
//        }
        return authUserDetailsImpl;
    }

    private String parseJwt(HttpServletRequest request) {
        String headerAuth = request.getHeader("Authorization");

        if (StringUtils.hasText(headerAuth) && headerAuth.startsWith("Bearer ")) {
            return headerAuth.substring(7, headerAuth.length());
        }

        return null;
    }

    public UserDetails loadUserByEmail(String email) {
        AuthUserDetailsImpl authUserDetailsImpl = null;
        if (userRepository.existsByEmail(email)) {
            User user = userRepository.findByEmail(email);
            authUserDetailsImpl = new AuthUserDetailsImpl(user.getUserId(), user.getUserName(), user.getPassword(), "ROLE_USER");
        }
        if (authUserDetailsImpl == null) {
            throw new CRNotFoundException("User with the email '" + email + "' does not exist.");
        }
        return authUserDetailsImpl;
    }
}
