set search_path to unc_45998975;
set search_path to unc_46911166;

-- Para cada una de las siguientes restricciones de integridad sobre el esquema dado
-- - provea una implementación según el estándar SQL con el recurso declarativo más restrictivo posible, indicando su tipo y justificación correspondiente.
-- - si no es posible su implementación declarativa en PostgreSQL, indique y justifique cada uno de los eventos críticos requeridos para garantizar su cumplimiento e incluya la implementación completa de los triggers correspondientes en PostgreSQL. Explique en forma clara y concisa su funcionamiento.





-- 1.a) Al menos el 30% de las habitaciones de cada área deben disponer de lugar para acompañante.

-- ===============================================
--    Tabla/s        Atributo/s            Tipo
--   Habitacion      id_area/acompaniante  Tabla
-- ===============================================

    ALTER TABLE habitacion ADD CONSTRAINT check_lugar_acompaniante
        -- No existe X que no cumpla C
        CHECK(NOT EXISTS(SELECT 'X' FROM habitacion h
                                    GROUP BY h.id_area
                                    HAVING (SUM(h.acompaniante::int)::numeric)/(COUNT(*)) < 0.3 ));

-- Al implementar subconsuta y funciones de agregacion definimos los triggers ya que en Postgresql no se podria realizar la operacion.


-- ====================================================================================
-- IMPLEMENTACION CON TRIGGERS
-- TABLAS          INSERT            UPDATE                        DELETE      TIPO FOR
-- habitacion      Correcto   Correcto(Id_area/Acompaniante)      Correcto     FOR ROW
-- ====================================================================================


-- Implementacion :
-- Chequeamos que el nuevo registro que se inserto/modifico no supere el 70% de habitaciones con acompaniante [acompaniante = false]
-- En caso de que supere el 70% se lanzara una exception que impide la insercion/modificacion

    CREATE OR REPLACE FUNCTION fn_check_lugar_acompaniante()
    RETURNS TRIGGER AS $$
        BEGIN

                 IF EXISTS(SELECT 'X' FROM habitacion h
                     WHERE h.id_area = new.id_area AND h.acompaniante = false
                     GROUP BY h.id_area
                     HAVING COUNT(*)::numeric/(SELECT COUNT(*) FROM habitacion WHERE id_area = new.id_area) > 0.7)
                     THEN
                     RAISE EXCEPTION 'En el área % se ha intentado ingresar/modificar una habitación sin acompañante, superando el límite máximo permitido', NEW.id_area;
                     END IF;
                 -- Chequeo de que old area <> new area
                IF (tg_op = 'UPDATE' AND OLD.id_area <> NEW.id_area)
                 THEN

                end if;
             RETURN NEW;
        END;
        $$ LANGUAGE 'plpgsql';

-- Implementacion Trigger
-- Adaptamos el trigger de forma AFTER, ya que la implementacion de la misma nos facilita la solucion de distintos errores.
-- Esto ya que al tener que sacar porcentajes basados en las filas y realizar calculos, si consideramos utilizar BEFORE
-- Deberiamos considerar que la fila todavia no se ha insertado. Por lo que con AFTER se soluciona.

    CREATE OR REPLACE TRIGGER tr_check_lugar_acompaniante
    AFTER INSERT OR UPDATE OF id_area, acompaniante
    ON habitacion
    FOR EACH ROW
    EXECUTE FUNCTION fn_check_lugar_acompaniante();


    CREATE OR REPLACE FUNCTION fn_check_lugar_acompaniante_delete()
    RETURNS TRIGGER AS $$
        BEGIN
            -- Se valida si la fila que se elimino tenia acompaniante
                IF(old.acompaniante = true)
                    THEN
                    IF(EXISTS(SELECT 'X' FROM habitacion h
                        WHERE h.id_area = old.id_area AND h.acompaniante = false
                        GROUP BY h.id_area
                        HAVING COUNT(*)::numeric/(SELECT COUNT(*) FROM habitacion WHERE id_area = OLD.id_area) > 0.7))
                        THEN
                        RAISE EXCEPTION 'No se puede eliminar el area % ya que no cumple con los requisitos de las habitaciones', OLD.id_area;
                    END IF;
                END IF;
                RETURN OLD;
        END;
        $$ LANGUAGE 'plpgsql';

    CREATE OR REPLACE TRIGGER tr_check_lugar_acompaniante_delete
        AFTER DELETE
    ON HABITACION
    FOR EACH ROW
    EXECUTE FUNCTION fn_check_lugar_acompaniante_delete();




INSERT INTO habitacion (id_area, nro_habitacion, descripcion_accesorios, acompaniante, situacion) values (2,203, 'A', true, 'L');

Update habitacion set id_area = 2 where id_area = 1 and nro_habitacion = 103;
Delete from habitacion where id_area = 2 and nro_habitacion = 203;

DROP trigger tr_check_lugar_acompaniante on habitacion;
DROP trigger tr_check_lugar_acompaniante_delete on habitacion;

Delete from habitacion where id_area = 2;


























-- 1.b) El médico responsable de un área debe poseer la misma especialidad que la denominación del área.























-- Prueba de ejercicio 1

    SELECT h.id_area, (COUNT(*) * 100) /(SELECT COUNT(*) FROM habitacion WHERE id_area = h.id_area) as "Porcentaje acom" , 100 - ((COUNT(*) * 100) /(SELECT COUNT(*) FROM habitacion WHERE id_area = h.id_area)) as "Porcentaje sin" FROM habitacion h
    WHERE h.acompaniante = true
    GROUP BY h.id_area;


-- 1\. Médico responsable (necesario si tenés activa la clave foránea en AREA)
INSERT INTO medico (nro_matricula, tipo_matricula, apellido, nombre, especialidad, e_mail, telefono) VALUES (1001, 'M', 'Pérez', 'Juan', 'Cardiología', 'jperez@hospital.com', '2494112233');

-- 2\. Áreas de prueba
INSERT INTO area (id_area, denominacion, cant_habit_disponibles, matr_medico_resp, tipo_matr_medico_resp) VALUES (1, 'Cardiología', 4, 1001, 'M'), (2, 'Pediatría', 10, 1001, 'M'), (3, 'Traumatología', 5, 1001, 'M');

-- Área 1 (Total: 4 hab. | 2 con acompañante = 50% -&gt; CUMPLE OK)
INSERT INTO habitacion (id_area, nro_habitacion, descripcion_accesorios, acompaniante, situacion) VALUES (1, 101, 'TV, Oxígeno', true, 'L'), (1, 102, 'Oxígeno', true, 'L'), (1, 103, 'Básica', false, 'L'), (1, 104, 'Básica', false, 'L');

-- Área 2 (Total: 10 hab. | 3 con acompañante = 30% -&gt; CUMPLE JUSTO)
INSERT INTO habitacion (id_area, nro_habitacion, descripcion_accesorios, acompaniante, situacion) VALUES (2, 201, 'Cuna, TV', true, 'L'), (2, 202, 'Cuna, TV', true, 'L'), (2, 203, 'Cuna', true, 'L'), (2, 204, 'Básica', false, 'L'), (2, 205, 'Básica', false, 'L'), (2, 206, 'Básica', false, 'L'), (2, 207, 'Básica', false, 'L'), (2, 208, 'Básica', false, 'L'), (2, 209, 'Básica', false, 'L'), (2, 210, 'Básica', false, 'L');