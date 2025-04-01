package com.rite.products.convertrite.adminapi.service;

import com.rite.products.convertrite.adminapi.model.CREmailNotifications;
import com.rite.products.convertrite.adminapi.model.CREmailNotificationsStatus;
import com.rite.products.convertrite.adminapi.model.ClientAdmin;
import com.rite.products.convertrite.adminapi.model.User;
import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.respository.CREmailNotificationRepository;
import com.rite.products.convertrite.adminapi.respository.ClientAdminRepository;
import com.rite.products.convertrite.adminapi.respository.UserRepository;
import com.rite.products.convertrite.adminapi.utils.Constants;
import com.rite.products.convertrite.adminapi.utils.PasswordUtils;
import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mail.MailAuthenticationException;
import org.springframework.mail.MailException;
import org.springframework.mail.MailSendException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.List;

@Service
@Slf4j
public class EmailService {
    @Value("${spring.mail.username}")
    private String fromEmail;

    @Value("${spring.mail.support-email}")
    private String supportemail;

    @Value("${spring.mail.user}")
    private String isUser;

    @Value("${spring.mail.admin}")
    private String isAdmin;

    @Autowired
    private JavaMailSender emailSender;

    @Autowired
    ClientAdminRepository clientAdminRepository;

    @Autowired
    CREmailNotificationRepository crEmailNotificationRepository;

    @Autowired
    UserRepository userRepository;

    @Autowired
    PasswordEncoder encoder;


    public boolean sendEmail(String toEmail, String fromEmail, String subject, String content) {
        try {
            log.info("Sending email to --> {}", toEmail);
            MimeMessage message = emailSender.createMimeMessage();
            message.setFrom(fromEmail);
            MimeMessageHelper helper;
            helper = new MimeMessageHelper(message, true);
            helper.setFrom(fromEmail);
            helper.setTo(toEmail);
            helper.setSubject(subject);
            helper.setText(content, true);
            emailSender.send(message);

        } catch (MailAuthenticationException e) {
            log.error("Authentication failed while sending email to --> {}, Error --> {}", toEmail, e.getMessage(), e);
            return false;
        } catch (MailSendException e) {
            log.error("Failed to send email to --> {}, Error --> {}", toEmail, e.getMessage(), e);
            return false;
        } catch (MessagingException e) {
            log.error("Messaging error while sending email to --> {}, Error --> {}", toEmail, e.getMessage(), e);
            return false;
        } catch (MailException e) {
            log.error("Mail error while sending email to --> {}, Error --> {}", toEmail, e.getMessage(), e);
            return false;
        } catch (Exception e) {
            log.error("Unknown error occurred while sending email to --> {}, Error --> {}", toEmail, e.getMessage(), e);
            return false;
        }
        return true;
    }

    public boolean sendVerificationEmail(String name, String convertRiteLink, String toEmail, String fromEmail, String text) {
        String appName = "Convertrite";
        String generatedPassword = text; // Assume this is assigned dynamically elsewhere in your code.
        String logoUrl = "https://cr20.convertrite.com/Admin/css/images/convertrite_logo.png"; // Replace with the actual URL of your logo
        String riteLogoUrl = "https://cr20.convertrite.com/Admin/css/images/RiteLogoNew.png"; // Replace with the actual URL of your logo
        String subject = Constants.PSD_UPDATE_SUBJECT; // Ensure Constants.PSD_UPDATE_SUBJECT is defined
        String supportEmail = "support@convertrite.com"; // Define support email address

        // HTML content for the email
        String htmlContent = "<html><head><style>"
                + "body { font-family: Arial, sans-serif; background-color: #f9f9f9; padding: 20px; }"
                + "h2 { color: #333; }"
                + "span {padding: 8px; border: 1px dashed #999; }"
                + ".right { text-align: center;  height: 50px; margin-bottom: 30px; }"
                + ".center { display: block;  height: 30%; }"
                + ".logo { border-radius: 10px; height: 40px; padding: 5px;margin-bottom:10px;float:right;}"
                + "</style></head><body>"
                + "<div>"
                + "<img src=\"" + riteLogoUrl + "\" alt=\"Rite Logo\" class=\"logo\">"
                + "</div>"
                + "<div>"
                + "<img src=\"" + logoUrl + "\" alt=\"Convertrite Logo\" class=\"right\" style=\"mix-blend-mode:multiply;\">\n"
                + "</div>"
                + "<h2>Welcome to " + appName + "!</h2>"
                + "<p>Dear " + name + ",</p>"
                + "<p>Your account has been successfully created. Below is your temporary password. Please use this password to log in and change it immediately after your first login to ensure the security of your account.</p>"
                + "<p><strong>Email:</strong> " + toEmail + "</p>"
                + "<p><strong>Password:</strong> <span>" + generatedPassword + "</span></p>"
                + "<p>Please click here to <a href=\"" + convertRiteLink + "\">Reset Password</a></p>"
                + "<p>If you did not request this account, please disregard this email. If you have any concerns, contact us immediately at " + supportEmail + ".</p>"
                + "<p>Thank you for choosing " + appName + "!</p>"
                + "<p>Best Regards,<br>" + appName + " Team</p>"
                + "</body></html>";

        return sendEmail(toEmail, fromEmail, subject, htmlContent);
    }


    public ResponseEntity<CREmailNotifications> saveCrEmailNotifications(String toEmail, String fromEmail, String subject, String status, String role) {
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


    public BasicResPo sendTempPassword(String email, String role) {
        try {
            String emailId = null;
            String roles = null;

            if ("clientAdmin".equals(role)) {
                roles = "clientAdmin";
                ClientAdmin clientAdmin = clientAdminRepository.findByClientAdminUserName(email);
                if (clientAdmin != null) {
                    clientAdmin.setIsFirstTimeLogin(true);
                    ClientAdmin res = clientAdminRepository.save(clientAdmin);
                    log.info("adminres: {}", res);
                    emailId = res.getClientAdminUserName();
                }
            } else if ("user".equals(role)) {
                roles = "user";
                User user = userRepository.findByEmail(email);
                if (user != null) {
                    user.setIsFirstTimeLogin(true);
                    User res = userRepository.save(user);
                    emailId = res.getEmail();
                }
            }

            if (emailId == null) {
                log.info("User Not Registered with Email: {} ", email);
            } else {
                log.info("Password Updated Successfully for Email: {}", emailId);
                saveCrEmailNotifications(emailId, fromEmail, Constants.PSD_UPDATE_SUBJECT, CREmailNotificationsStatus.NEW.toString(), roles);
            }

            return new BasicResPo() {{
                setStatusCode(HttpStatus.CREATED);
                setStatus("success");
                setMessage("A temporary password has been sent to " + email + " successfully. Please check your mail.");
            }};
        } catch (Exception e) {
            log.error("Error in sendTempPassword: {} ", e.getMessage(), e);
            return new BasicResPo() {{
                setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
                setStatus("error");
                setMessage("Error in sending temporary password.");
            }};
        }
    }

    @Scheduled(fixedRateString = "${spring.mail.schedule-time}")
    public void processPendingEmailNotifications() {
        List<String> statuses = Arrays.asList("NEW", "ERROR");
        List<CREmailNotifications> pendingEmails = crEmailNotificationRepository.findByStatusIn(statuses);

        for (CREmailNotifications emailNotification : pendingEmails) {
            log.info("=============Checking for new Emails=================== {} ", emailNotification.getToEmail().trim());
            if (CREmailNotificationsStatus.NEW.toString().trim().equals(emailNotification.getStatus().trim()) || CREmailNotificationsStatus.ERROR.toString().trim().equals(emailNotification.getStatus().trim())) {
                ClientAdmin clientAdmin = clientAdminRepository.findByClientAdminUserName(emailNotification.getToEmail().trim());
                User user = userRepository.findByEmail(emailNotification.getToEmail().trim());
                String defaultGeneratedPwd = PasswordUtils.generatePassword();
                String pwd =encoder.encode(defaultGeneratedPwd);
                if (clientAdmin == null) {
                    log.info("clientAdmin Not Registered with Email--> {} ", emailNotification.getToEmail());
                }
                if (user == null) {
                    log.info("User Not Registered with Email --> {} ", emailNotification.getToEmail());
                }
                if (clientAdmin != null && emailNotification.getRole().trim().equals("clientAdmin")) {
                    log.info("Password Updated Successfully for clientAdmin {} ", clientAdmin.getClientAdminUserName());
                    log.info("=============defaultGeneratedPwd=======clientAdmin============ {} ", defaultGeneratedPwd);
                    clientAdmin.setClientAdminPassword(pwd);
                    ClientAdmin clientAdminres = clientAdminRepository.save(clientAdmin);
                    try {
                        boolean isSent = sendVerificationEmail(
                                clientAdmin.getClientAdminName(),
                                isAdmin,
                                clientAdmin.getClientAdminUserName(),
                                fromEmail,
                                defaultGeneratedPwd
                        );
                        if (isSent) {
                            emailNotification.setStatus(CREmailNotificationsStatus.SENT.toString());
                        } else {
                            emailNotification.setStatus(CREmailNotificationsStatus.ERROR.toString());
                        }
                    } catch (Exception e) {
                        emailNotification.setStatus(CREmailNotificationsStatus.ERROR.toString());
                    } finally {
                        crEmailNotificationRepository.save(emailNotification);
                    }
                }
                if (user != null && emailNotification.getRole().trim().equals("user")) {
                    log.info("Password Updated Successfully for User: {}", user.getEmail());
                    log.info("=============defaultGeneratedPwd=======User============ {} ", defaultGeneratedPwd);
                    user.setPassword(pwd);
                    User res = userRepository.save(user);
                    String emailId = user.getEmail();
                    try {
                        boolean isSent = sendVerificationEmail(
                                user.getUserName(),
                                isUser,
                                emailId,
                                fromEmail,
                                defaultGeneratedPwd
                        );
                        if (isSent) {
                            emailNotification.setStatus(CREmailNotificationsStatus.SENT.toString());
                        } else {
                            emailNotification.setStatus(CREmailNotificationsStatus.ERROR.toString());
                        }
                    } catch (Exception e) {
                        emailNotification.setStatus(CREmailNotificationsStatus.ERROR.toString());
                        e.printStackTrace();
                    } finally {
                        crEmailNotificationRepository.save(emailNotification);
                    }
                }
            }
        }
    }
}
