-- 5.a) Implemente los roles (de grupo y de login, con al menos un usuario de prueba por perfil) y los privilegios necesarios para
-- los 3 perfiles. Indique en qué casos resulta necesario otorgar privilegios a nivel de columna y justifique.

-- 5.b) Implemente la restricción de visibilidad del perfil Médico (que garantice que cada médico pueda ver y modificar únicamente
-- las internaciones que tiene asignadas y consultar los datos de los pacientes correspondientes) mediante el mecanismo que considere más adecuado,
-- justificando la elección y sus limitaciones.

CREATE ROLE admision;
CREATE ROLE medico;
CREATE ROLE auditoria;

grant usage on schema unc_46911166 to admision, medico, auditoria;

GRANT insert on paciente to admision;
GRANT insert, update (fecha_salida) on internacion to admision;
GRANT select on area, habitacion, medico, internacion to admision;

GRANT select, update (diagnostico_ppal) on internacion to medico;
GRANT select on paciente to medico;

GRANT select on medico, internacion, area, paciente, habitacion, ocupacion, ranking_obra_social to auditoria;
GRANT execute on fn_porcentaje_ocupacion() to auditoria;

alter table internacion enable row level security;
alter table paciente enable row level security;

create policy medico_internacion on internacion
    for all
    to medico
    using ('med_' || internacion.tipo_matr_med_asig || '_' || internacion.matr_med_asignado::text = current_user)
    with check ('med_' || internacion.tipo_matr_med_asig || '_' || internacion.matr_med_asignado::text = current_user);

create policy medico_pacientes on paciente
    for select
    to medico
    using (paciente.id_paciente in (
      select internacion.id_paciente
      from internacion
      where ('med_' || internacion.tipo_matr_med_asig || '_' || internacion.matr_med_asignado::text = current_user)
    ));

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