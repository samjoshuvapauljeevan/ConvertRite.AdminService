package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;
import lombok.Data;

import java.sql.Date;

@Entity
@Data
@Table(name="cr_email_notifications")
public class CREmailNotifications {
@Id
@GeneratedValue(strategy = GenerationType.IDENTITY)
    private  long notificationId;
    private String toEmail;
    private String fromEmail;
    private String subject;
    private String status;
    private String role;
    private  Date creationDate;
    private String createdBy;
    private Date lastUpdateDate;
    private  String lastUpdatedBy;


}
