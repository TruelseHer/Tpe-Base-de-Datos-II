-- Para cada una de las siguientes restricciones de integridad sobre el esquema dado
-- - provea una implementación según el estándar SQL con el recurso declarativo más restrictivo posible, indicando su tipo y justificación correspondiente.
-- - si no es posible su implementación declarativa en PostgreSQL, indique y justifique cada uno de los eventos críticos requeridos para garantizar su cumplimiento e incluya la implementación completa de los triggers correspondientes en PostgreSQL. Explique en forma clara y concisa su funcionamiento.





-- 1.a) Al menos el 30% de las habitaciones de cada área deben disponer de lugar para acompañante.

--    Tabla/s        Atributo/s            Tipo
--   Habitacion      id_area/acompaniante  Tabla

    ALTER TABLE habitacion ADD CONSTRAINT check_lugar_acompaniante
        -- No existe X que no cumpla C
        CHECK(NOT EXISTS())































-- 1.b) El médico responsable de un área debe poseer la misma especialidad que la denominación del área.
