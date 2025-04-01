package com.rite.products.convertrite.adminapi.controller;

import com.rite.products.convertrite.adminapi.po.BasicResPo;
import com.rite.products.convertrite.adminapi.service.EmailService;
import jakarta.mail.MessagingException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/convertriteadmin/email")
public class EmailController {

    @Autowired
    private EmailService emailService;

    @PostMapping("/sendTempPassword")
    public BasicResPo sendTempPassword(@RequestParam String email, @RequestParam String role)  {
       BasicResPo resPo= emailService.sendTempPassword(email,role);
       return resPo;
    }
}

