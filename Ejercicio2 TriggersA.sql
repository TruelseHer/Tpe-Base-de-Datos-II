set search_path to unc_45998975;

-- Para los siguientes requerimientos, provea una solución completa para PostgreSQL utilizando el/los mecanismo/s que considere adecuados y justifique su solución (no utilice sentencias de bucle: for, loop, etc.).

-- 2.a) dada una fecha indicada por el usuario, verificar si el porcentaje de ocupación de habitaciones para dicha fecha supera el 80%. De ser así, agregar en una tabla Ocupación (ya existente) la fecha dada y el porcentaje de ocupación alcanzado.


-- Creacion de tabla Ocupacion
CREATE TABLE Ocupacion (
    fecha_ingreso date NOT NULL,
    porc_ocup numeric NOT NULL,
    CONSTRAINT pk_ocupacion PRIMARY KEY (fecha_ingreso)
);

-- Utilizacion de variable auxiliar para guardar el porcentaje de ocupacion, debido a mayor simplicidad y mayor eficiencia (se reduce el numero de consultas)
-- a la hora de obtener dicho porcentaje
-- El porcentaje esta determinado por la division entre el numero de habitaciones ocupadas y el total de habitaciones

CREATE OR REPLACE PROCEDURE fn_porcentaje_ocupacion (fecha_ingreso_usuario date)
    LANGUAGE plpgsql
AS $$
    DECLARE
    porcentaje_ocupacion numeric;
    BEGIN
        porcentaje_ocupacion := ((SELECT COUNT(DISTINCT (i.id_area, i.nro_habitacion)) FROM internacion i
                            WHERE (i.fecha_ingreso <= fecha_ingreso_usuario) AND (i.fecha_salida IS NULL OR i.fecha_salida >= fecha_ingreso_usuario))::numeric
                / (SELECT COUNT(*) FROM habitacion h ));

        IF (porcentaje_ocupacion > 0.8)
        THEN
        INSERT INTO Ocupacion (fecha_ingreso, porc_ocup) VALUES (fecha_ingreso_usuario, porcentaje_ocupacion);
        END IF;
    END; $$;

-- CALL fn_porcentaje_ocupacion(x fecha)

-- 2.b) mantener automáticamente actualizadas tanto la cantidad de habitaciones disponibles en cada área como la situación (libre/ocupada) de las habitaciones,
-- a medida que éstas se ocupan o desocupan (considere que los valores actuales son consistentes con los datos existentes en la base).


--    TABLA/S       INSERT                     UPDATE                             DELETE
--    HABITACION   correcto    correcto(situacion, id_area)                      correcto
--    INTERNACION  correcto    correcto(fecha_salida,nro_habitacion, id_area)    correcto

CREATE OR REPLACE FUNCTION fn_habitacion ()
    RETURNS TRIGGER AS $$
    BEGIN
        -- Si se actualiza el atributo id_area
            IF (old.id_area <> new.id_area)
        THEN
                IF(new.situacion = 'L')
                    THEN
                    -- Sumamos 1 a la nueva area
                    UPDATE area SET cant_habit_disponibles = cant_habit_disponibles + 1 WHERE id_area = new.id_area;
                end if;
                    -- Restamos 1 a la area antigua
                 UPDATE area SET cant_habit_disponibles = cant_habit_disponibles - 1 WHERE id_area = old.id_area;
           ELSE
                -- En caso de que se inserte o se actualize la situacion a L, sumamos 1
            IF (new.situacion = 'L' AND (tg_op = 'INSERT' OR old.situacion = 'O'))
        THEN
        UPDATE area SET cant_habit_disponibles = cant_habit_disponibles + 1 WHERE id_area = new.id_area;
            END IF;

        -- En caso de que se actualize la situacion a O
        IF (new.situacion = 'O' AND old.situacion = 'L')
        THEN
        UPDATE area SET cant_habit_disponibles = cant_habit_disponibles - 1 WHERE id_area = old.id_area;
        END IF;
            END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE 'plpgsql';

CREATE OR REPLACE TRIGGER tr_habitacion
    BEFORE INSERT OR UPDATE OF situacion, id_area
    ON HABITACION
    FOR EACH ROW
    EXECUTE FUNCTION fn_habitacion();

CREATE OR REPLACE FUNCTION fn_habitacion_delete()
    RETURNS TRIGGER AS $$
    BEGIN
        IF (old.situacion = 'L')
            THEN
            UPDATE area SET cant_habit_disponibles = cant_habit_disponibles - 1 WHERE id_area = old.id_area;
        END IF;
        RETURN OLD;
    END;
    $$ LANGUAGE 'plpgsql';

CREATE OR REPLACE TRIGGER tr_habitacion_delete
    BEFORE DELETE
    ON habitacion
    FOR EACH ROW
    EXECUTE FUNCTION fn_habitacion_delete();


-- Si cambia fecha salida a null --> Situacion O------------------- Hecho
-- Si cambia fecha salida a X fecha --> Situacion L --------------- Hecho
-- Lo de arriba considerarlo tambien con insert

-- Si cambia [area/nro_habitacion] actualizo segun lo de arriba ---- Hecho

CREATE OR REPLACE FUNCTION fn_internacion ()
    RETURNS TRIGGER AS $$
    BEGIN
        IF (new.fecha_salida IS NULL AND (tg_op = 'INSERT' OR old.fecha_salida IS NOT NULL))
            THEN
            UPDATE habitacion SET situacion = 'O' WHERE id_area = new.id_area AND nro_habitacion = new.nro_habitacion;
        end if;

        IF (new.fecha_salida IS NOT NULL AND (tg_op = 'INSERT' OR old.fecha_salida IS NULL))
            THEN
            UPDATE habitacion SET situacion = 'L' WHERE id_area = new.id_area AND nro_habitacion = new.nro_habitacion;
        end if;

        IF (old.id_area <> new.id_area OR old.nro_habitacion <> new.nro_habitacion)
            THEN
             IF (new.fecha_salida IS NULL AND old.fecha_salida IS NOT NULL)
            THEN
            UPDATE habitacion SET situacion = 'O' WHERE id_area = new.id_area AND nro_habitacion = new.nro_habitacion;

             IF (new.fecha_salida IS NOT NULL AND old.fecha_salida IS NULL)
            THEN
            UPDATE habitacion SET situacion = 'L' WHERE id_area = new.id_area AND nro_habitacion = new.nro_habitacion;
        end if;

        end if;
             IF (EXISTS(SELECT 'X' FROM internacion i
                 WHERE i.id_area = old.id_area AND i.id_area = old.nro_habitacion AND i.fecha_salida IS NULL))
                 THEN
                 UPDATE habitacion set situacion =  'O' WHERE id_area = old.id_area AND nro_habitacion = old.nro_habitacion;
             ELSE
                  UPDATE habitacion set situacion =  'L' WHERE id_area = old.id_area AND nro_habitacion = old.nro_habitacion;
             end if;
        end if;
        RETURN NEW;
    end;
    $$ LANGUAGE 'plpgsql';


CREATE OR REPLACE TRIGGER tr_internacion
    BEFORE INSERT OR UPDATE OF id_area, nro_habitacion, fecha_salida
    ON internacion
    FOR EACH ROW
    EXECUTE FUNCTION fn_internacion ();

CREATE OR REPLACE FUNCTION fn_internacion_delete ()
    RETURNS TRIGGER AS $$
    BEGIN
     IF (EXISTS(SELECT 'X' FROM internacion i
                 WHERE i.id_area = old.id_area AND i.id_area = old.nro_habitacion AND i.fecha_salida IS NULL))
                 THEN
                 UPDATE habitacion set situacion =  'O' WHERE id_area = old.id_area AND nro_habitacion = old.nro_habitacion;
             ELSE
                  UPDATE habitacion set situacion =  'L' WHERE id_area = old.id_area AND nro_habitacion = old.nro_habitacion;
             end if;
     RETURN OLD;
    end;
    $$ LANGUAGE 'plpgsql';

CREATE OR REPLACE TRIGGER tr_internacion_delete
    BEFORE DELETE
    ON internacion
    FOR EACH ROW
    EXECUTE FUNCTION fn_internacion_delete ();