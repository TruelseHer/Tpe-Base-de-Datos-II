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

-- ====================================================================================
-- IMPLEMENTACION CON TRIGGERS
--    TABLA/S       INSERT                     UPDATE                             DELETE
--    HABITACION   correcto    correcto(situacion, id_area)                      correcto
--    INTERNACION  correcto    correcto(fecha_salida,nro_habitacion, id_area)    correcto
-- ====================================================================================

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


CREATE OR REPLACE FUNCTION fn_habitacion ()
    RETURNS TRIGGER AS $$
    BEGIN
        -- Caso que se realize un INSERT
        IF(TG_OP = 'INSERT' AND new.situacion = 'L')
            THEN
            UPDATE area SET cant_habit_disponibles = cant_habit_disponibles + 1 WHERE id_area = new.id_area;


        -- Caso que se realize un UPDATE

        ELSIF (TG_OP = 'UPDATE')
            THEN
            -- CASO 1 : Cambia el area
            IF (new.id_area <> old.id_area)
                THEN
                -- Caso en que el area vieja tenga L: le debemos quitar 1 ya que tiene un espacio libre menos
                IF (old.situacion = 'L')
                    THEN
                    UPDATE area SET cant_habit_disponibles = cant_habit_disponibles -1 WHERE id_area = old.id_area;
                end if;
                -- Caso en que el area nueva tenga L: le debemos sumar 1
                IF (new.situacion = 'L') THEN
                    UPDATE area SET cant_habit_disponibles = cant_habit_disponibles + 1 WHERE id_area = new.id_area;
                end if;
              -- CASO 2 : Cambia de situacion
            ELSIF (old.situacion <> new.situacion)
                THEN
                IF (old.situacion = 'O')
                    THEN
                    UPDATE area SET cant_habit_disponibles = cant_habit_disponibles + 1 WHERE id_area = new.id_area;
                end if;

                IF (old.situacion = 'L')
                    THEN
                    UPDATE area SET cant_habit_disponibles = cant_habit_disponibles - 1 WHERE id_area = new.id_area;
                end if;
            end if;
        end if;
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


CREATE OR REPLACE FUNCTION fn_internacion()
RETURNS TRIGGER AS $$
BEGIN
    -- CASO 1: Se cambió el paciente de habitación (UPDATE de id_area o nro_habitacion)
    IF (TG_OP = 'UPDATE' AND (OLD.id_area IS DISTINCT FROM NEW.id_area OR OLD.nro_habitacion IS DISTINCT FROM NEW.nro_habitacion)) THEN

        -- Caso en el que la habitacion vieja se libera si no le quedan otras internaciones activas
        IF NOT EXISTS (
            SELECT 1
            FROM internacion
            WHERE id_area = OLD.id_area
              AND nro_habitacion = OLD.nro_habitacion
              AND fecha_salida IS NULL
              AND id_paciente <> OLD.id_paciente
        ) THEN
            UPDATE habitacion
            SET situacion = 'L'
            WHERE id_area = OLD.id_area
              AND nro_habitacion = OLD.nro_habitacion;
        END IF;

        -- Caso en el que si la internacion esta activa en la habitacion nueva, la marcamos ocupada
        IF (NEW.fecha_salida IS NULL) THEN
            UPDATE habitacion
            SET situacion = 'O'
            WHERE id_area = NEW.id_area
              AND nro_habitacion = NEW.nro_habitacion;
        END IF;

    -- CASO 2: Realizas INSERT o UPDATE respecto a la fecha_salida
    ELSE
        -- Caso en el que sigue internado
        IF (NEW.fecha_salida IS NULL) THEN
            UPDATE habitacion
            SET situacion = 'O'
            WHERE id_area = NEW.id_area
              AND nro_habitacion = NEW.nro_habitacion;

        -- Caso en el que se le da de alta, primero corroboramos si no quedan otros pacientes en la habitacion
        ELSIF (NEW.fecha_salida IS NOT NULL) THEN
            IF NOT EXISTS (
                SELECT 1
                FROM internacion
                WHERE id_area = NEW.id_area
                  AND nro_habitacion = NEW.nro_habitacion
                  AND fecha_salida IS NULL
                  -- Excluimos al paciente actual
                  AND id_paciente <> NEW.id_paciente
            ) THEN
                UPDATE habitacion
                SET situacion = 'L'
                WHERE id_area = NEW.id_area
                  AND nro_habitacion = NEW.nro_habitacion;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE TRIGGER tr_internacion
    BEFORE INSERT OR UPDATE OF id_area, nro_habitacion, fecha_salida
    ON internacion
    FOR EACH ROW
    EXECUTE FUNCTION fn_internacion ();

CREATE OR REPLACE FUNCTION fn_internacion_delete ()
    RETURNS TRIGGER AS $$
    BEGIN
     IF (EXISTS(SELECT 'X' FROM internacion i
                 WHERE i.id_area = old.id_area AND i.nro_habitacion = old.nro_habitacion AND i.fecha_salida IS NULL))
                 THEN
                 UPDATE habitacion set situacion =  'O' WHERE id_area = old.id_area AND nro_habitacion = old.nro_habitacion;
             ELSE
                  UPDATE habitacion set situacion =  'L' WHERE id_area = old.id_area AND nro_habitacion = old.nro_habitacion;
             end if;
     RETURN OLD;
    end;
    $$ LANGUAGE 'plpgsql';

-- IMPLEMENTACION:
-- Realizamos trigger AFTER, ya que dentro del exists a la hora de chequear las filas, si el trigger
-- esta definido como BEFORE, se contemplaria
-- la fila que se desea eliminar. Por ende para realizarlo de forma mas sencilla utilizamos AFTER.
CREATE OR REPLACE TRIGGER tr_internacion_delete
    AFTER DELETE
    ON internacion
    FOR EACH ROW
    EXECUTE FUNCTION fn_internacion_delete ();