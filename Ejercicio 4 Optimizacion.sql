-- 4.a) la obtención de la internación activa (o sea, sin fecha de salida registrada) de una habitación dada;
create or replace procedure fn_internacion_activa(id_area_param int, nro_habitacion_param int)
    language plpgsql
    as $$
    begin
        select * from internacion
        where internacion.id_area = id_area_param and internacion.nro_habitacion = nro_habitacion_param
        and internacion.fecha_salida is null;
    end;
    $$;

-- 4.b) el cálculo del porcentaje de ocupación de habitaciones para una fecha dada (punto 2.a).
call fn_porcentaje_ocupacion(current_date);