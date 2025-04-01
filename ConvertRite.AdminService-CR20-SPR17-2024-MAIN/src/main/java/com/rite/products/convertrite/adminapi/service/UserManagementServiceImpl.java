package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.exception.CRNotFoundException;
import com.rite.products.convertrite.adminapi.exception.CRUniquenessException;
import com.rite.products.convertrite.adminapi.model.*;
import com.rite.products.convertrite.adminapi.po.*;
import com.rite.products.convertrite.adminapi.respository.CREmailNotificationRepository;
import com.rite.products.convertrite.adminapi.respository.RoleRepository;
import com.rite.products.convertrite.adminapi.respository.UserRepository;
import com.rite.products.convertrite.adminapi.utils.Constants;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.sql.Date;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static com.rite.products.convertrite.adminapi.utils.PasswordUtils.isValid;

@RequiredArgsConstructor
@Service
@Slf4j
public class UserManagementServiceImpl extends BasicManagementService<User, Long> implements UserManagementService {

    @Value("${spring.mail.username}")
    private String fromEmail;

    @Autowired
    UserRepository userRepository;

    @Autowired
    RoleRepository roleRepository;

    @Autowired
    PasswordEncoder encoder;

    @Autowired
    private EmailService emailService;

    @Autowired
    CREmailNotificationRepository crEmailNotificationRepository;


    @Override
    public BasicResPo createUser(UserCreationReqPo userCreationReqPo) {
        log.info("=========createUser===========");
        try {
            User user = new User();
            user.setUserName(userCreationReqPo.getUserName());
            user.setPersonName(userCreationReqPo.getPersonName());
            user.setIsFirstTimeLogin(true);
            user.setEmail(userCreationReqPo.getEmail());
            user.setUserLoginType(userCreationReqPo.getUserLoginType());
            if (userCreationReqPo.getClientId() != null) {
                Client client = new Client();
                client.setClientId(userCreationReqPo.getClientId());
                user.setClient(client);
            }
            if (userCreationReqPo.getRoleIds() != null) {
                Set<Role> roles = new HashSet<Role>();
                for (Long roleId : userCreationReqPo.getRoleIds()) {
                    Role r = new Role();
                    r.setRoleId(roleId);
                    roles.add(r);
                }
                user.setRoles(roles);
            }
            user.setLastUpdatedBy("ConvertRiteAdmin");
            user.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
            user.setCreationDate(new java.sql.Date(new java.util.Date().getTime()));
            user.setCreatedBy("ConvertRiteAdmin");
            User entityRes = super.addEntity(userRepository, user);
            User createdEntity = super.getEntityById(userRepository, entityRes.getUserId());
            if(createdEntity.getUserLoginType().equalsIgnoreCase("Password")) {
                saveCrEmailNotifications(user.getEmail(), fromEmail, Constants.PSD_UPDATE_SUBJECT, CREmailNotificationsStatus.NEW.toString(),"user");

                return new BasicResPo() {{
                    setStatusCode(HttpStatus.CREATED);
                    setStatus("success");
                    setMessage("Successfully created user " + createdEntity.getUserName()  + ". A temporary password has been sent to " + user.getEmail() + " successfully. Please check your mail.");
                    setPayload(generateResPo(createdEntity, false));
                }};
            }
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CREATED);
                setStatus("success");
                setMessage("Successfully created user " + createdEntity.getUserName());
                setPayload(generateResPo(createdEntity, false));
            }};
        } catch (CRUniquenessException ex) {
           log.error("CRUniquenessException in createUser()----> {} ", ex.getMessage());
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("User with email '" + userCreationReqPo.getEmail() + "' already exists. Please enter unique email.");
                setPayload(ex);
            }};
        } catch (Exception ex) {
            log.error("Exception in createUser()----> {} ", ex.getMessage());
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage("User with username '" + userCreationReqPo.getUserName()+ "' already exists.");
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo getUsers(Long clientId) {
        List<User> users = userRepository.findAllByClientId(clientId);
        List<UserResPo> res = new ArrayList<>();
        if (users != null) {
            for (User user : users) {
                res.add(generateResPo(user, false));
            }
            ;
        }
        return new BasicResPo() {{
            setStatusCode(HttpStatus.OK);
            setStatus("success");
            setMessage("Successfully retrieved all user");
            setPayload(res);
        }};
    }

    @Override
    public BasicResPo getUserById(Long userId) {
        try {
            User user = super.getEntityById(userRepository, userId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get user with id " + userId);
                setPayload(generateResPo(user, false));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("User with id " + userId + " is not found");
                setPayload(ex);
            }};
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo getUserWithLicensedPodsByUserId(Long userId) {
        try {
            User user = super.getEntityById(userRepository, userId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get user with id " + userId);
                setPayload(generateResPo(user, true));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("User with id " + userId + " is not found");
                setPayload(ex);
            }};
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo getUserWithLicensedPodsByUserEmail(String userEmail) {
        try {
            User user = userRepository.findByEmail(userEmail);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get user with email " + userEmail);
                setPayload(generateResPo(user, true));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("User with email " + userEmail + " is not found");
                setPayload(ex);
            }};
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo getLicensedPodsByUserId(Long userId) {
        try {
            log.info("getLicensedPodsByUserId----> {} ", userId);
            User user = super.getEntityById(userRepository, userId);
            Date currentDate = new Date(System.currentTimeMillis());
            List<Pod> userPods = new ArrayList<>();
            user.getRoles().forEach(role -> {
                if (!userPods.contains(role.getPod())) {
                    userPods.add(role.getPod());
                    log.info("role.getPod()----> {} ", role.getPod());
                }
            });
            log.info("userPods----> {} ", userPods.get(0));
            List<Pod> validPods = userPods.stream().filter(pod ->
                    currentDate.before(pod.getLicense().getEffectiveEndDate())
            ).toList();

            List<PodBasicResPo> res = new ArrayList<>();
            if (validPods != null) {
                for (Pod p : validPods) {
                    res.add(generatePodResPo(p));
                }
            }
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully get licensed pods for user with id " + userId);
                setPayload(res);
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("User with id " + userId + " is not found");
                setPayload(ex);
            }};
        } catch (Exception ex) {
            log.error("Exception in getLicensedPodsByUserId--> {} ", ex);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo putUserById(Long userId, UserCreationReqPo userCreationReqPo) {
        try {
            User user = userRepository.findById(userId).get();
            user.setUserName(userCreationReqPo.getUserName());
            if (userCreationReqPo.getPassword() != null && userCreationReqPo.getPassword().length() > 0) {
                user.setPassword(encoder.encode(userCreationReqPo.getPassword()));
                user.setIsFirstTimeLogin(false);
            }
            Boolean userExists = userRepository.existsByEmail(userCreationReqPo.getEmail());
            if (userExists) {
                user.setPersonName(userCreationReqPo.getPersonName());
                user.setEmail(userCreationReqPo.getEmail());
                user.setUserLoginType(userCreationReqPo.getUserLoginType());
                if (userCreationReqPo.getRoleIds() != null) {
                    Set<Role> roles = new HashSet<Role>();
                    for (Long roleId : userCreationReqPo.getRoleIds()) {
                        Role role = new Role();
                        role.setRoleId(roleId);
                        roles.add(role);
                    }
                    user.setRoles(roles);
                }
                user.setLastUpdatedBy("ConvertRiteAdmin");
                user.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
                User updatedEntity = super.updateEntity(userRepository, user);
                return new BasicResPo() {{
                    setStatusCode(HttpStatus.OK);
                    setStatus("success");
                    setMessage("Successfully updated user " + updatedEntity.getUserName());
                    setPayload(generateResPo(updatedEntity, false));
                }};
            }

            user.setIsFirstTimeLogin(true);
            saveCrEmailNotifications(userCreationReqPo.getEmail(), fromEmail, Constants.PSD_UPDATE_SUBJECT, CREmailNotificationsStatus.NEW.toString(),"user");
            user.setPersonName(userCreationReqPo.getPersonName());
            user.setEmail(userCreationReqPo.getEmail());
            user.setUserLoginType(userCreationReqPo.getUserLoginType());
            if (userCreationReqPo.getRoleIds() != null) {
                Set<Role> roles = new HashSet<Role>();
                for (Long roleId : userCreationReqPo.getRoleIds()) {
                    Role role = new Role();
                    role.setRoleId(roleId);
                    roles.add(role);
                }
                user.setRoles(roles);
            }
            user.setLastUpdatedBy("ConvertRiteAdmin");
            user.setLastUpdatedDate(new java.sql.Date(new java.util.Date().getTime()));
            User updatedEntity = super.updateEntity(userRepository, user);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Please check your mail after some time for temporary password which needs to be reset.");
                setPayload(generateResPo(updatedEntity, false));
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("User with id " + userId + " is not found");
                setPayload(ex);
            }};
        } catch (CRUniquenessException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CONFLICT);
                setStatus("error");
                setMessage("User with email '" + userCreationReqPo.getEmail() + "' already exists. Please enter unique email.");
                setPayload(ex);
            }};
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo deleteUserById(Long userId) {
        try {
            User user = super.getEntityById(userRepository, userId);
            super.deleteEntityById(userRepository, userId);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.OK);
                setStatus("success");
                setMessage("Successfully deleted user with username " + user.getUserName());
            }};
        } catch (CRNotFoundException ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.NOT_FOUND);
                setStatus("error");
                setMessage("User with id " + userId + " not exists to delete");
            }};
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo getUserAuthType(String email) {
        try {
            if (userRepository.existsByEmail(email)) {
                User user = userRepository.findByEmail(email);
                AuthTypeResPo authTypeResponse = new AuthTypeResPo();
                authTypeResponse.setUserName(user.getUserName());
                authTypeResponse.setEmail(user.getEmail());
                authTypeResponse.setUserLoginType(user.getUserLoginType());
                return new BasicResPo() {{
                    setStatusCode(HttpStatus.OK);
                    setStatus("success");
                    setMessage("Successfully get user auth type with email " + email);
                    setPayload(authTypeResponse);
                }};
            } else {
                return new BasicResPo() {{
                    setStatusCode(HttpStatus.NOT_FOUND);
                    setStatus("error");
                    setMessage("User with email " + email + " is not found");
                }};
            }
        } catch (Exception ex) {
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage(ex.getMessage());
                setPayload(ex);
            }};
        }
    }

    @Override
    public BasicResPo forgotPassword(String email) {
        try {
            User user = userRepository.findByEmail(email);

            if (user == null) {
                log.info("User Not Registered with Email {} ", email);
            } else {
                User res = userRepository.save(user);
                String emailId = res.getEmail();
                String userName = res.getUserName();
                saveCrEmailNotifications(emailId,fromEmail,Constants.PSD_UPDATE_SUBJECT, CREmailNotificationsStatus.NEW.toString(),"user");
                log.info("Password Updated Successfully for Email {} ", emailId);
            }
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CREATED);
                setStatus("success");
                setMessage("A temporary password has been sent to " + email + " successfully. Please check your mail.");
            }};
        } catch (Exception e) {
            log.error("Error in sendSamplePassword {} ", e.getMessage());
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage("Error in sending temporary Password");
            }};
        }
    }

    public ResponseEntity<CREmailNotifications> saveCrEmailNotifications(String toEmail , String fromEmail , String subject , String status, String role){
        log.info("=========saveCrEmailNotifications===========");
        CREmailNotifications notification = new CREmailNotifications();
        notification.setToEmail(toEmail);
        notification.setFromEmail(fromEmail);
        notification.setSubject(subject);
        notification.setStatus(status);
        notification.setRole(role);
        notification.setCreatedBy("");
        notification.setCreationDate(new java.sql.Date(new java.util.Date().getTime()));
        notification.setLastUpdateDate(new java.sql.Date(new java.util.Date().getTime()));
        notification.setLastUpdatedBy("");
        CREmailNotifications savedNotification = crEmailNotificationRepository.save(notification);
        return ResponseEntity.ok(savedNotification);
    }

    @Override
    public BasicResPo updatePassword(String email, String password) {
        try {
            boolean isPasswordValid= isValid(password);
            if(!isPasswordValid){
                throw new Exception("Password is invalid. It should contain at least 8 characters, including at least one number, one uppercase letter, and one lowercase letter.");
            }
            User user = userRepository.findByEmail(email);
            if (user == null) {
                log.info("In updatePassword(), User Not Registered with Email {} ", email);
            } else {
                user.setPassword(encoder.encode(password));
                user.setIsFirstTimeLogin(false);
                User res = userRepository.save(user);
                String emailId = res.getEmail();
                log.info("In updatePassword(), Password Updated Successfully for Email {} ", emailId);
            }
            return new BasicResPo() {{
                setStatusCode(HttpStatus.CREATED);
                setStatus("success");
                setMessage("Password Updated Successfully");
            }};
        } catch (Exception e) {
            log.error("Error in updatePassword {} ", e.getMessage());
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage("Error in updatePassword");
            }};
        }
    }

    private UserResPo generateResPo(User user, boolean validateLicense) {
        UserResPo res = new UserResPo();
        res.setUserId(user.getUserId());
        res.setUserName(user.getUserName());
        res.setPassword(user.getPassword());
        res.setPersonName(user.getPersonName());
        res.setEmail(user.getEmail());
        res.setUserLoginType(user.getUserLoginType());
        if (user.getClient() != null) {
            ClientResPo clientInfo = new ClientResPo();
            clientInfo.setClientId(user.getClient().getClientId());
            clientInfo.setClientName(user.getClient().getClientName());
            res.setClient(clientInfo);
        }
        if (user.getRoles() != null) {
            List<RoleResPo> roles = new ArrayList<RoleResPo>();
            Date currentDate = new Date(System.currentTimeMillis());
            for (Role role : user.getRoles()) {
                if (validateLicense && role.getPod() != null && currentDate.before(role.getPod().getLicense().getEffectiveEndDate())) {
                    RoleResPo roleResPo = new RoleResPo();
                    roleResPo.setRoleId(role.getRoleId());
                    roleResPo.setRoleName(role.getRoleName());
                    if (role.getPod() != null) {
                        PodBasicResPo pod = new PodBasicResPo();
                        pod.setPodId(role.getPod().getPodId());
                        pod.setPodName(role.getPod().getPodName());
                        roleResPo.setPod(pod);
                    }
                    roles.add(roleResPo);
                } else if (!validateLicense) {
                    RoleResPo roleResPo = new RoleResPo();
                    roleResPo.setRoleId(role.getRoleId());
                    roleResPo.setRoleName(role.getRoleName());
                    if (role.getPod() != null) {
                        PodBasicResPo pod = new PodBasicResPo();
                        pod.setPodId(role.getPod().getPodId());
                        pod.setPodName(role.getPod().getPodName());
                        roleResPo.setPod(pod);
                    }
                    roles.add(roleResPo);
                }
            }
            res.setRoles(roles);
        }
        return res;
    }

    private PodBasicResPo generatePodResPo(Pod pod) {
        PodBasicResPo podResPo = new PodBasicResPo();
        podResPo.setPodId(pod.getPodId());
        podResPo.setPodName(pod.getPodName());
        return podResPo;
    }
}
