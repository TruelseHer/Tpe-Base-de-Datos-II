set search_path to unc_45998975;
set search_path to unc_46911166;

-- 3.a) Vista que incluya sólo identificador y denominación de la/s área/s que posea/n la mayor cantidad de internaciones iniciadas
-- en el año en curso.

-- Implementacion :
-- Para garantizar que la vista sea automáticamente actualizable en PostgreSQL
-- encapsulamos la lógica compleja (JOIN, GROUP BY y función de ventana) dentro de
-- una subconsulta en la cláusula WHERE mediante la condición IN. De esta forma
-- la consulta principal opera únicamente sobre la tabla base area.


CREATE VIEW ranking_area AS
SELECT area.id_area, area.denominacion
FROM area
    where id_area in (
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

-- Porque la vista definida es automaticamente actualizable en postgresSQL
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

-- 3.b) Vista que, para cada obra social, muestre los siguientes datos de las tres internaciones de mayor duración:
-- identificador, apellido y nombre del paciente, fecha de ingreso, fecha de salida, duración de la internación (en días),
-- posición en el ranking de la obra social. Nota: considerar únicamente las internaciones que poseen fecha de salida registrada.

CREATE view ranking_obra_social as
WITH ranking_internacion as (
    SELECT p.id_paciente, p.apellido, p.nombre, i.fecha_ingreso, i.fecha_salida, i.fecha_salida - i.fecha_ingreso AS duracion_internacion,
           dense_rank() over (
               PARTITION BY p.obra_social
               ORDER BY (i.fecha_salida - i.fecha_ingreso) desc
               ) as ranking_obrasocial
    FROM paciente p join internacion i USING (id_paciente)
    WHERE i.fecha_salida IS NOT NULL
)
SELECT * from ranking_internacion
where ranking_obrasocial <= 3;

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
