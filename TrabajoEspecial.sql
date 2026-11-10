set search_path to unc_45998975;


-- ====================================================================
--        ELABORACIÓN DE RESTRICCIONES - REGLAS DEL NEGOCIO
-- ====================================================================


-- Para cada una de las siguientes restricciones de integridad sobre el esquema dado
-- - provea una implementación según el estándar SQL con el recurso declarativo más restrictivo posible, indicando su tipo y justificación correspondiente.
-- - si no es posible su implementación declarativa en PostgreSQL, indique y justifique cada uno de los eventos críticos requeridos para garantizar su cumplimiento e incluya la implementación completa de los triggers correspondientes en PostgreSQL. Explique en forma clara y concisa su funcionamiento.


-- ===============================================================================================
-- 1.a) Al menos el 30% de las habitaciones de cada área deben disponer de lugar para acompañante.
-- ===============================================================================================


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
-- TABLAS          INSERT             UPDATE                        DELETE     TIPO FOR
-- habitacion      Correcto   Correcto(Id_area/Acompaniante)      Correcto     FOR ROW
-- ====================================================================================


-- IMPLEMENTACION :
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

-- IMPLEMENTACION TRIGGER
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





--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------





-- =====================================================================================================
-- 1.b) El médico responsable de un área debe poseer la misma especialidad que la denominación del área.
-- =====================================================================================================

-- Restriccion Segun el Estandar SQL

-- ===================================================================================================================================================
--    Tabla/s        Atributo/s                                                                                                             Tipo
--   Medico, Area         (medico) nro_matricula, (medico) tipo_matricula, (medico) especialidad, (area) matr_medico_resp, (area) tipo_matr_medico_resp, (area) denominacion     De base de datos (Assertion)
-- ===================================================================================================================================================


 CREATE ASSERTION check_medico_area
 CHECK (NOT EXISTS (
     SELECT 1
     FROM medico m JOIN area a ON (m.nro_matricula = a.matr_medico_resp AND m.tipo_matricula = a.tipo_matr_medico_resp)
     WHERE m.especialidad <> a.denominacion
     ));

-- Debido a que se trata de un assertion, la restriccion declarativa no se posible de implementar en postgreSql, por lo que
-- requiere de triggers.


-- =====================================================================================================================================
-- IMPLEMENTACION CON TRIGGERS
-- TABLAS          INSERT            UPDATE                                                                       DELETE      TIPO FOR
-- Medico         Incorrecto         Correcto (especialidad)                                                      Incorrecto     F.row
-- Area           Correcto           Correcto (denominacion, matr_medico_resp, tipo_matr_medico_resp)             Incorrecto     F.row
-- =====================================================================================================================================

-- IMPLEMENTACION [UPDATE] :
-- Chequeamos que al actualizar la especialidad del medico, exista al menos una area donde su especialidad coincida con la denominacion del area

CREATE OR REPLACE FUNCTION fn_check_medico()
    RETURNS TRIGGER AS $$
    BEGIN
        IF (EXISTS (
            SELECT 'X'
            FROM area
            WHERE matr_medico_resp = new.nro_matricula AND tipo_matr_medico_resp = new.tipo_matricula
            AND denominacion <> new.especialidad
        )) THEN
            RAISE EXCEPTION 'No se puede actualizar un medico cuya especialidad no coincida con la denominacion del area de la cual es reponsable';
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tr_check_medico
    BEFORE UPDATE of especialidad
    ON medico
    FOR EACH ROW
    EXECUTE FUNCTION fn_check_medico();


-- IMPLEMENTACION [INSERT/UPDATE]
-- Chequeamos que al insertar/modificar dentro de area exista un medico asociado a esa are donde su especialidad coincida con la denominacion del area
CREATE OR REPLACE FUNCTION fn_check_area() returns trigger as $$
    BEGIN
        IF (EXISTS(
            SELECT 1
            FROM medico
            WHERE nro_matricula = new.matr_medico_resp AND tipo_matricula = new.tipo_matr_medico_resp
            AND especialidad <> new.denominacion
        )) THEN
            RAISE EXCEPTION 'No se puede agregar o modificar un area cuya denominacion no coincida con la especialidad de su medico responsable';
        END IF;
        RETURN NEW;
    end;
    $$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tr_check_area
    BEFORE INSERT OR UPDATE of denominacion, tipo_matr_medico_resp, matr_medico_resp
    ON area
    FOR EACH ROW EXECUTE FUNCTION fn_check_area();





--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------





-- ====================================================================
--            SERVICIOS Y ACTUALIZACIÓN DE INFORMACIÓN
-- ====================================================================

-- Para los siguientes requerimientos, provea una solución completa para PostgreSQL utilizando el/los mecanismo/s que
-- considere adecuados y justifique su solución (no utilice sentencias de bucle: for, loop, etc.).


-- =====================================================================================================
-- 2.a) dada una fecha indicada por el usuario, verificar si el porcentaje de ocupación de habitaciones
-- para dicha fecha supera el 80%. De ser así, agregar en una tabla Ocupación (ya existente)
-- la fecha dada y el porcentaje de ocupación alcanzado.
-- =====================================================================================================


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




--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------




-- =====================================================================================================
-- 2.b) mantener automáticamente actualizadas tanto la cantidad de habitaciones disponibles en cada área
-- como la situación (libre/ocupada) de las habitaciones, a medida que éstas se ocupan o desocupan
-- (considere que los valores actuales son consistentes con los datos existentes en la base).
-- =====================================================================================================


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
                END IF;
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


--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------


-- ====================================================================
--              DEFINICIÓN Y ACTUALIZACIÓN DE VISTAS
-- ====================================================================


-- =====================================================================================================
-- 3.a) Vista que incluya sólo identificador y denominación de la/s área/s que posea/n
-- la mayor cantidad de internaciones iniciadas en el año en curso.
-- =====================================================================================================

-- IMPLEMENTACION :
-- Para garantizar que la vista sea automáticamente actualizable en PostgreSQL
-- encapsulamos la lógica compleja (JOIN, GROUP BY y función de ventana) dentro de
-- una subconsulta en la cláusula WHERE mediante la condición IN. De esta forma
-- la consulta principal opera únicamente sobre la tabla base area.


CREATE VIEW ranking_area AS
SELECT area.id_area, area.denominacion
FROM area
    WHERE id_area IN (
        WITH internacion_area AS (
        SELECT
            a.id_area,
            a.denominacion,
            rank() OVER (ORDER BY count(*) DESC) AS ranking
        FROM area a
        JOIN internacion i USING (id_area)
        -- filtramos aquellas fechas donde coinciden con la fecha actual (Current_date)
        WHERE extract(year FROM i.fecha_ingreso) = extract(year FROM current_date)
        GROUP BY a.id_area, a.denominacion
            )
        -- filtramos aquellas areas que forman parte del primer puesto en el ranking
        SELECT id_area
        FROM internacion_area
        WHERE ranking = 1
        );

-- Porque la vista definida es automaticamente actualizable en postgresSQL:
/*
Es automaticamente actualizable ya que las columnas del select estan basadas en una tabla base, ademas no se incluyen las siguiente
clausulas en la consulta principal:
- with (cte)
- funciones de agregacion
- funciones de agrupacion
- columnas del select que esten basadas en una subconsulta
- subconsultas en el from
 */

-- TESTEO NO INCLUIR EN LA ENTREGA FINAL
--Operaciones de Insercion para probar la vista
-- 1. Médicos
INSERT INTO MEDICO (nro_matricula, tipo_matricula, apellido, nombre, especialidad, e_mail, telefono) VALUES
(1001, 'P', 'Gomez', 'Juan', 'Cardiología', 'jgomez@hospital.com', '123456789'),
(1002, 'P', 'Perez', 'Maria', 'Pediatría', 'mperez@hospital.com', '987654321'),
(1003, 'N', 'Lopez', 'Carlos', 'Traumatología', 'clopez@hospital.com', '555444333');

-- 2. Áreas
INSERT INTO AREA (id_area, denominacion, cant_habit_disponibles, matr_medico_resp, tipo_matr_medico_resp) VALUES
(1, 'Cardiología', 2, 1001, 'P'),
(2, 'Pediatría', 1, 1002, 'P'),
(3, 'Traumatología', 3, 1003, 'N');

-- 3. Habitaciones
INSERT INTO HABITACION (id_area, nro_habitacion, descripcion_accesorios, acompaniante, situacion) VALUES
(1, 101, 'Cama eléctrica, monitor cardíaco', TRUE, 'O'),
(1, 102, 'Cama estándar', FALSE, 'L'),
(2, 201, 'Cuna, sillón acompañante', TRUE, 'O'),
(3, 301, 'Tracción esquelética', TRUE, 'L');

-- 4. Pacientes
INSERT INTO PACIENTE (id_paciente, apellido, nombre, obra_social, matr_med_cabecera, tipo_mat_med_cabecera) VALUES
(1, 'Alvarez', 'Pedro', 'OSDE', 1001, 'P'),
(2, 'Benitez', 'Sofia', 'SWISS', 1002, 'P'),
(3, 'Castro', 'Lucas', 'PAMI', 1001, 'P'),
(4, 'Diaz', 'Ana', NULL, 1003, 'N');

-- 5. Internaciones
-- Las fechas se construyen dinámicamente con make_date para apuntar al año en curso y a años pasados
INSERT INTO INTERNACION (id_paciente, id_area, nro_habitacion, fecha_ingreso, fecha_salida, diagnostico_ppal, matr_med_asignado, tipo_matr_med_asig) VALUES
-- Área 1: 3 internaciones en el año en curso
(1, 1, 101, make_date(extract(year from current_date)::int, 2, 10), make_date(extract(year from current_date)::int, 2, 15), 'Infarto agudo', 1001, 'P'),
(2, 1, 101, make_date(extract(year from current_date)::int, 3, 5),  make_date(extract(year from current_date)::int, 3, 10), 'Arritmia', 1001, 'P'),
(3, 1, 101, make_date(extract(year from current_date)::int, 4, 1),  NULL, 'Insuficiencia cardíaca', 1001, 'P'),

-- Área 2: 1 internacion en el año en curso y 2 de años previos
(4, 2, 201, make_date(extract(year from current_date)::int, 1, 20), NULL, 'Bronquiolitis', 1002, 'P'),
(1, 2, 201, make_date(extract(year from current_date)::int - 1, 5, 12), make_date(extract(year from current_date)::int - 1, 5, 18), 'Control previo', 1002, 'P'),
(2, 2, 201, make_date(extract(year from current_date)::int - 2, 8, 3), make_date(extract(year from current_date)::int - 2, 8, 10), 'Fiebre persistente', 1002, 'P');

SELECT * from ranking_area;

drop view ranking_area;



--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------



-- =====================================================================================================
-- 3.b) Vista que, para cada obra social, muestre los siguientes datos de las tres internaciones de mayor duración:
-- identificador, apellido y nombre del paciente, fecha de ingreso, fecha de salida, duración de la internación (en días),
-- posición en el ranking de la obra social. Nota: considerar únicamente las internaciones que poseen fecha de salida registrada.
-- =====================================================================================================

CREATE VIEW ranking_obra_social AS
WITH ranking_internacion AS (
    SELECT p.id_paciente, p.apellido, p.nombre, i.fecha_ingreso, i.fecha_salida, i.fecha_salida - i.fecha_ingreso AS duracion_internacion,
           dense_rank() OVER (
               PARTITION BY p.obra_social
               ORDER BY (i.fecha_salida - i.fecha_ingreso) DESC
               ) AS ranking_obrasocial
    FROM paciente p JOIN internacion i USING (id_paciente)
    WHERE i.fecha_salida IS NOT NULL
)
SELECT * FROM ranking_internacion
WHERE ranking_obrasocial <= 3;

--Justificacion de porque la vista no es automaticamente actualizable
/*
 A diferencia del inciso a, en esta consulta se solicitan datos en el select que provienen de tablas diferentes, lo que requiere un join entre
 ellas para obtenerlos y ademas se utilizan las siguientes clasusulas dentro de la definicion de la vista, que imposibilitan hacerla automaticamente
 actualizable:
 - Clausula with (cte)
 - Funcion de ventana (dense_rank)
 - Ensamble entre tablas (join)
 */

-- Para que la vista sea automaticamente actualizable [INSERT, UPDATE, DELETE] se deberia de integrar Triggers INSTEAD OF.


--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------



-- ====================================================================
--              ÍNDICES Y OPTIMIZACIÓN DE CONSULTAS
-- ====================================================================




--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------




-- ====================================================================
--                        CONTROL DE ACCESO
-- ====================================================================

-- =====================================================================================================
-- 5.a) Implemente los roles (de grupo y de login, con al menos un usuario de prueba por perfil)
-- y los privilegios necesarios para los 3 perfiles.
-- Indique en qué casos resulta necesario otorgar privilegios a nivel de columna y justifique.
-- =====================================================================================================

-- ROLES DE GRUPO / PRIVILEGIOS

-- Creamos los roles de grupo
CREATE ROLE admision;
CREATE ROLE medico;
CREATE ROLE auditoria;

-- Le otorgamos acceso al esquema a los 3 roles de grupo
grant usage on schema unc_46911166 to admision, medico, auditoria;

GRANT insert on paciente to admision;
GRANT insert, update (fecha_salida) on internacion to admision;
GRANT select on area, habitacion, medico, internacion to admision;

-- Le damos privilegios de actualizacion sobre una unica columna (diagnostico_ppal)
GRANT select, update (diagnostico_ppal) on internacion to medico;
GRANT select on paciente to medico;

-- Le otorgamos privilegios de consulta a la tabla ocupacion (2.a) y a la vista ranking_obra_social (3.b)
GRANT select on medico, internacion, area, paciente, habitacion, ocupacion, ranking_obra_social to auditoria;
GRANT execute on fn_porcentaje_ocupacion() to auditoria;

-- Creamos roles con LOGIN para testing
CREATE ROLE blasAdmision LOGIN PASSWORD 'admision123';
CREATE ROLE med_N_12345 LOGIN PASSWORD 'medico123';
CREATE ROLE hermesAuditoria LOGIN PASSWORD 'auditoria123';

-- Asignamos cada user a su rol de grupo correspondiente
GRANT admision TO blasAdmision;
GRANT medico TO med_N_12345;
GRANT auditoria TO hermesAuditoria;


-- Activamos el RLS para ambas tablas, ante ello deberemos crear distintas politicas, ya que al activar el RLS,
-- aquellos roles que tienen privilegios sobre esas tablas con el RLS activo, si no poseen una politica declarada se les denegara el acceso.




--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------




-- =====================================================================================================
-- 5.b) Implemente la restricción de visibilidad del perfil Médico
-- (que garantice que cada médico pueda ver y modificar únicamente
-- las internaciones que tiene asignadas y consultar los datos de los pacientes correspondientes)
-- mediante el mecanismo que considere más adecuado,
-- justificando la elección y sus limitaciones.
-- =====================================================================================================

-- SEGURIDAD A NIVEL FILA (RLS)

alter table internacion enable row level security;
alter table paciente enable row level security;

-- Creamos las politicas para medico, ya que no debe de tener accesco completo a todas las filas de la tabla.
-- En este caso, aquellas filas que corresponden con internaciones asisgnadas a ese mismo medico.
create policy medico_internacion on internacion
    for all
    to medico
    using ('med_' || internacion.tipo_matr_med_asig || '_' || internacion.matr_med_asignado::text = current_user)
    with check ('med_' || internacion.tipo_matr_med_asig || '_' || internacion.matr_med_asignado::text = current_user);

-- En este caso, aquellas filas que corresponden con los pacientes de las internaciones que esta asignado
create policy medico_pacientes on paciente
    for select
    to medico
    using (paciente.id_paciente in (
      select internacion.id_paciente
      from internacion
      where ('med_' || internacion.tipo_matr_med_asig || '_' || internacion.matr_med_asignado::text = current_user)
    ));

-- Creamos las politicas para aquellos roles en donde les afecta tener el RLS activo por tener privilegios sobre esas mismas tablas.
create policy admision_internacion on internacion
    for all
    to admision
    using (true)
    with check (true);

create policy auditoria_internacion on internacion
    for select
    to auditoria
    using (true);

create policy admision_paciente on paciente
    for insert
    to admision
    with check (true);

create policy auditoria_paciente on paciente
    for select
    to auditoria
    using (true);



--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------




-- ====================================================================
--                                NoSQL
-- ====================================================================

-- Plantee las operaciones que permitan resolver las siguientes consultas en la BD NoSQL MongoDB (*):

-- =====================================================================================================
-- 6.a) Listar los pacientes internados en este momento en Terapia Intensiva.
-- Para cada uno, mostrar el nombre del paciente, el número de habitación, la fecha de ingreso,
-- el diagnóstico principal y el apellido del médico asignado. Ordenar desde la internación más reciente a la más antigua.
-- =====================================================================================================


db.internaciones.find(
    -- Filtramos (WHERE)
        { "habitacion.area" : "Terapia Intensiva",
            fecha_salida : null },
        {
    -- Realizamos la projeccion
            _id : 0,
            "paciente.nombre" : 1,
            "habitacion.nro" : 1,
            fecha_ingreso : 1,
            diagnostico_ppal : 1,
            "medico_asignado.apellido" : 1
        }
    -- Ordenamos descendentemente
        ).sort({ "fecha_ingreso" : -1})


-- fecha_ingreso >= 2025-01-01 AND fecha_ingreso <= 2025-12-31
-- fecha_salida >= 2025-01-01 AND fecha_salida <= 2025-12-31
-- fecha_ingreso < 2025-01-01 AND fecha_salida >=  2025-12-31


--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------


-- =====================================================================================================
-- 6.b) Informar cuántas internaciones tuvo cada área durante 2025.
-- Mostrar sólo las áreas con más de 15 internaciones, ordenadas de mayor a menor cantidad.
-- =====================================================================================================

-- IMPLEMENTACION:
-- Filtrado: Al indicarnos que el tiempo transcurre durante 2025 procuramos 3 condiciones:
-- La fecha de ingreso transcurre como mucho hasta (2025-12-31), ya que es el ultimo dia del año 2025
-- Luego puede suceder 2 casos:
-- Que la fecha de salida no este definida (NULL)
-- Que la fecha de salida sea en el año 2025 (2025-01-01)

    db.internaciones.aggregate([
        {
            // Filtramos antes de agrupar
            $match : {
        fecha_ingreso: { $lte: ISODate("2025-12-31T23:59:59.999Z") },

         $or:[
             { fecha_salida: { $gte: ISODate("2025-01-01T00:00:00.000Z") } },
             { "fecha_salida": null } ]
            }
        },
            // Agrupamos dentro de la coleccion internaciones por area
        {
            $group : {
                _id : {
                    area : "$habitacion.id_area"
                },
            // Simulamos la funcion Count
                cantidad_internaciones : { $sum : 1 }
            }
        },
            // Filtramos (HAVING) aquellas cantidades que sean mayores a 15
        {
            $match : {
                cantidad_internaciones : { $gt : 15 }
            }
        },
            // Orddenamos de mayor a menor
        {
            $sort : { cantidad_internaciones : -1}
        }

        ]);


--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------


db.internaciones.aggregate([
    {
        $match : {
            fecha_salida : { $ne : null }
        }
    },

    {
    // Simulamos una CTE, para evitar codigo duplicado a la hora de realizar los calculos de promedio y maximo
        $project : {
            "habitacion.id_area" : 1,
            "duracion_dias" : {
                $divide : [
                    { $subtract : [ "$fecha_salida" , "$fecha_ingreso"]},
                    86400000
                    ]
            }
        }
    },

    {
        $group : {
                _id : {
                    area : "$habitacion.id_area"
                },
            // Simulamos la funcion Count
                cantidad_internaciones : { $sum : 1 },
            // Calculamos el promedio de dias
                promedio : { $avg : "$duracion_dias"},
            // Hayamos el maximo
                max_duracion_dias : { $max : "$duracion_dias"}
            }
    },

    {
        $project : {
            _id : 0,
            cantidad_internaciones : 1,
            promedio : {$round : ["$promedio", 1 ] } ,
            max_duracion_dias : {$round : ["$max_duracion_dias",1 ] }
        }
    },

    {
        $sort: { promedio : -1 }
        }
]);