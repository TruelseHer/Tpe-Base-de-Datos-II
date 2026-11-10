set search_path to unc_45998975;
-- 4.a) la obtención de la internación activa (o sea, sin fecha de salida registrada) de una habitación dada;

-- IMPLEMENTACION CONSULTA
EXPLAIN (ANALYZE , BUFFERS , format JSON)
select * from internacion
        where internacion.id_area = 1 and internacion.nro_habitacion = 101
        and internacion.fecha_salida is null;

-- IMPLEMENTACION INDEX
-- Generamos un indice donde cada nodo respecto a la tabla internacion contendra (id_area, nro_habitacion)
-- Sobre aquellas filas donde su fecha_salida sea null
CREATE INDEX index_area_habitacion
    ON internacion (id_area, nro_habitacion)
    WHERE fecha_salida IS NULL;

set enable_seqscan = off;

-- 4.b) el cálculo del porcentaje de ocupación de habitaciones para una fecha dada (punto 2.a).

VACUUM ANALYZE habitacion;
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT (
    SELECT COUNT(DISTINCT (i.id_area, i.nro_habitacion)) FROM internacion i
                    WHERE i.fecha_ingreso <= '2026-04-20'::DATE AND (i.fecha_salida IS NULL OR i.fecha_salida >= '2026-04-10'::DATE) ) * 100.0
           / (SELECT COUNT(*) FROM habitacion h) AS porcentaje_ocupacion;

-- Realizamos la optimizacion de la consulta donde eliminamos el filtrado para realizarlo con un ensamble (JOIN)

TRUNCATE TABLE internacion CASCADE;


-- 1. Insertar Médico y Área de prueba
INSERT INTO medico (
    nro_matricula,
    tipo_matricula,
    apellido,
    nombre,
    especialidad,
    e_mail,
    telefono
)
VALUES (
    101,
    'M',
    'Perez',
    'Juan',
    'Cardiologia',
    'perez@hospital.com',
    '123456'
);

INSERT INTO area (
    id_area,
    denominacion,
    cant_habit_disponibles,
    matr_medico_resp,
    tipo_matr_medico_resp
)
VALUES (
    1,
    'Cardiologia',
    5,
    101,
    'M'
);


-- 2. Insertar Habitaciones
INSERT INTO habitacion (
    id_area,
    nro_habitacion,
    descripcion_accesorios,
    acompaniante,
    situacion
)
VALUES
    (1, 101, 'Oxigeno', true, 'O'),
    (1, 102, 'Monitor', false, 'L');


-- 3. Insertar Pacientes
INSERT INTO paciente (
    id_paciente,
    apellido,
    nombre,
    obra_social,
    matr_med_cabecera,
    tipo_mat_med_cabecera
)
VALUES
    (1, 'Gomez', 'Carlos', 'OSDE', 101, 'M'),
    (2, 'Lopez', 'Ana', 'SWISS', 101, 'M');


-- 4. Insertar Internaciones (algunas activas y otras finalizadas)
INSERT INTO internacion (
    id_paciente,
    id_area,
    nro_habitacion,
    fecha_ingreso,
    fecha_salida,
    diagnostico_ppal,
    matr_med_asignado,
    tipo_matr_med_asig
)
VALUES
    (1, 1, 101, '2026-05-01', NULL, 'Observación', 101, 'M'),            -- Activa en Hab 101
    (2, 1, 102, '2026-04-10', '2026-04-20', 'Evaluación', 101, 'M');   -- Finalizada
