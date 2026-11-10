set search_path to unc_45998975;

-- 5.a) Implemente los roles (de grupo y de login, con al menos un usuario de prueba por perfil) y los privilegios necesarios para
-- los 3 perfiles. Indique en qué casos resulta necesario otorgar privilegios a nivel de columna y justifique.

-- 5.b) Implemente la restricción de visibilidad del perfil Médico (que garantice que cada médico pueda ver y modificar únicamente
-- las internaciones que tiene asignadas y consultar los datos de los pacientes correspondientes) mediante el mecanismo que considere más adecuado,
-- justificando la elección y sus limitaciones.


-- =========================================================================
--                      ROLES DE GRUPO / PRIVILEGIOS
-- =========================================================================

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

-- =========================================================================
--                     SEGURIDAD A NIVEL FILA (RLS)
-- =========================================================================

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