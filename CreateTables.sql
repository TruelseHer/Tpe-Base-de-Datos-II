-- Created by Redgate Data Modeler (https://datamodeler.redgate-platform.com)
-- Last modification date: 2025-03-11 18:07:02.523

set search_path to unc_45998975;
set search_path to unc_46911166;

-- tables
-- Table: AREA
CREATE TABLE AREA (
    id_area int  NOT NULL,
    denominacion varchar(40)  NOT NULL,
    cant_habit_disponibles int  NOT NULL,
    matr_medico_resp int  NOT NULL,
    tipo_matr_medico_resp char(1)  NOT NULL,
    CONSTRAINT AREA_pk PRIMARY KEY (id_area)
);

-- Table: HABITACION
CREATE TABLE HABITACION (
    id_area int  NOT NULL,
    nro_habitacion int  NOT NULL,
    descripcion_accesorios varchar(40)  NOT NULL,
    acompaniante boolean  NOT NULL,
    situacion char(1)  NOT NULL,
    CONSTRAINT HABITACION_pk PRIMARY KEY (id_area,nro_habitacion)
);

-- Table: INTERNACION
CREATE TABLE INTERNACION (
    id_paciente int  NOT NULL,
    id_area int  NOT NULL,
    nro_habitacion int  NOT NULL,
    fecha_ingreso date  NOT NULL,
    fecha_salida date  NULL,
    diagnostico_ppal varchar(255)  NOT NULL,
    matr_med_asignado int  NOT NULL,
    tipo_matr_med_asig char(1)  NOT NULL,
    CONSTRAINT INTERNACION_pk PRIMARY KEY (id_paciente,id_area,nro_habitacion,fecha_ingreso)
);

-- Table: MEDICO
CREATE TABLE MEDICO (
    nro_matricula int  NOT NULL,
    tipo_matricula char(1)  NOT NULL,
    apellido varchar(40)  NOT NULL,
    nombre varchar(40)  NOT NULL,
    especialidad varchar(40)  NOT NULL,
    e_mail varchar(40)  NOT NULL,
    telefono varchar(15)  NOT NULL,
    CONSTRAINT MEDICO_pk PRIMARY KEY (nro_matricula,tipo_matricula)
);

-- Table: PACIENTE
CREATE TABLE PACIENTE (
    id_paciente int  NOT NULL,
    apellido varchar(40)  NOT NULL,
    nombre varchar(40)  NOT NULL,
    obra_social char(10)  NULL,
    matr_med_cabecera int  NULL,
    tipo_mat_med_cabecera char(1)  NULL,
    CONSTRAINT PACIENTE_pk PRIMARY KEY (id_paciente)
);

-- foreign keys
-- Reference: FK_AREA_MEDICO (table: AREA)
ALTER TABLE AREA ADD CONSTRAINT FK_AREA_MEDICO
    FOREIGN KEY (matr_medico_resp, tipo_matr_medico_resp)
    REFERENCES MEDICO (nro_matricula, tipo_matricula)
    ON DELETE  CASCADE
    ON UPDATE  CASCADE
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: FK_HABITACION_AREA (table: HABITACION)
ALTER TABLE HABITACION ADD CONSTRAINT FK_HABITACION_AREA
    FOREIGN KEY (id_area)
    REFERENCES AREA (id_area)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: FK_INTERNACION_HABITACION (table: INTERNACION)
ALTER TABLE INTERNACION ADD CONSTRAINT FK_INTERNACION_HABITACION
    FOREIGN KEY (id_area, nro_habitacion)
    REFERENCES HABITACION (id_area, nro_habitacion)
    ON UPDATE  CASCADE
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: FK_INTERNACION_MEDICO (table: INTERNACION)
ALTER TABLE INTERNACION ADD CONSTRAINT FK_INTERNACION_MEDICO
    FOREIGN KEY (matr_med_asignado, tipo_matr_med_asig)
    REFERENCES MEDICO (nro_matricula, tipo_matricula)
    ON UPDATE  CASCADE
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: FK_INTERNACION_PACIENTE (table: INTERNACION)
ALTER TABLE INTERNACION ADD CONSTRAINT FK_INTERNACION_PACIENTE
    FOREIGN KEY (id_paciente)
    REFERENCES PACIENTE (id_paciente)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: FK_PACIENTE_MEDICO (table: PACIENTE)
ALTER TABLE PACIENTE ADD CONSTRAINT FK_PACIENTE_MEDICO
    FOREIGN KEY (matr_med_cabecera, tipo_mat_med_cabecera)
    REFERENCES MEDICO (nro_matricula, tipo_matricula)
    ON DELETE  SET NULL
    ON UPDATE  SET NULL
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- End of file.