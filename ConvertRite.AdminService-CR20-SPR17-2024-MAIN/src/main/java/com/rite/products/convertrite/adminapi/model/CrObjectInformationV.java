package com.rite.products.convertrite.adminapi.model;

import jakarta.persistence.*;
import lombok.Data;

@Data
@Entity
@Table(name = "cr_object_information_view")
public class CrObjectInformationV {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "object_id", columnDefinition = "serial")
    private Long objectId;

    @Column(name = "parent_object_id")
    private Long parentObjectId;

    @Column(name ="info_value")
    private String infoValue;
}
