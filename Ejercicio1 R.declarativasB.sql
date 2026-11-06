set search_path to unc_45998975;

-- 1.b) El médico responsable de un área debe poseer la misma especialidad que la denominación del área.

-- Restriccion Segun el Estandar SQL

--    Tabla/s        Atributo/s                                                                                                             Tipo
--   Medico, Area         (medico) nro_matricula, (medico) tipo_matricula, (medico) especialidad, (area) matr_medico_resp, (area) tipo_matr_medico_resp, (area) denominacion     De base de datos (Assertion)

-- CREATE ASSERTION check_medico_area
-- CHECK (NOT EXISTS (
--     SELECT 1
--     FROM medico m JOIN area a ON (m.nro_matricula = a.matr_medico_resp AND m.tipo_matricula = a.tipo_matr_medico_resp)
--     WHERE m.especialidad <> a.denominacion
--     ));

-- Debido a que se trata de un assertion, la restriccion declarativa no se posible de implementar en postgreSql, por lo que
-- requiere de triggers

--Eventos Criticos

-- TABLAS          INSERT            UPDATE                                                                       DELETE      TIPO FOR
-- Medico         Incorrecto         Correcto (especialidad)                                                      Incorrecto     F.row
-- Area           Correcto           Correcto (denominacion, matr_medico_resp, tipo_matr_medico_resp)             Incorrecto     F.row

CREATE OR REPLACE FUNCTION fn_check_medico()
    returns trigger as $$
    begin
        if (exists (
            select 'X'
            from area
            where matr_medico_resp = new.nro_matricula AND tipo_matr_medico_resp = new.tipo_matricula
            AND denominacion <> new.especialidad
        ))then
            raise exception 'No se puede actualizar un medico cuya especialidad no coincida con la denominacion del area de la cual es reponsable';
        end if;
        return new;
    end;
    $$ language plpgsql;

CREATE OR REPLACE TRIGGER tr_check_medico
    BEFORE UPDATE of especialidad
    ON medico
    FOR EACH ROW
    EXECUTE FUNCTION fn_check_medico();

CREATE OR REPLACE FUNCTION fn_check_area() returns trigger as $$
    begin
        if (exists(
            select 1
            from medico
            where nro_matricula = new.matr_medico_resp AND tipo_matricula = new.tipo_matr_medico_resp
            AND especialidad <> new.denominacion
        )) then
            raise exception 'No se puede agregar o modificar un area cuya denominacion no coincida con la especialidad de su medico responsable';
        end if;
        return new;
    end;
    $$ language plpgsql;

CREATE OR REPLACE TRIGGER tr_check_area
    BEFORE INSERT OR UPDATE of denominacion, tipo_matr_medico_resp, matr_medico_resp
    ON area
    FOR EACH ROW EXECUTE FUNCTION fn_check_area();





drop trigger tr_check_medico on medico;


UPDATE medico set especialidad = 'Sexologo' where nro_matricula = 1001;

INSERT INTO area (id_area, denominacion, cant_habit_disponibles, matr_medico_resp, tipo_matr_medico_resp) values (10, 'a', 1, 1001, 'M');

Delete from area where id_area = 10;












INSERT INTO medico (nro_matricula, tipo_matricula, apellido, nombre, especialidad, e_mail, telefono) VALUES  (1002, 'M', 'Gómez', 'Laura', 'Pediatría', 'lgomez@hospital.com', '2494445566'), (1003, 'M', 'Díaz', 'Carlos', 'Traumatología', 'cdiaz@hospital.com', '2494778899');