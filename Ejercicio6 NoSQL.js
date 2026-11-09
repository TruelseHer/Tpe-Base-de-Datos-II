use hospital;

//Plantee las operaciones que permitan resolver las siguientes consultas en la BD NoSQL MongoDB (*):
//6.a) Listar los pacientes internados en este momento en Terapia Intensiva. Para cada uno, mostrar el nombre del paciente, el número de habitación, la fecha de ingreso, el diagnóstico principal y el apellido del médico asignado. Ordenar desde la internación más reciente a la más antigua.

db.internaciones.aggregate([
    // Join entre la coleccion internacion y area
    { $lookup : {
        from : "areas",
        localField : "habitacion.id_area",
        foreignField : "_id",
        as : "internacion_area"
    }
        },
    // Descomponemos el array generado
    {
        $unwind : "$internacion_area"
    },

    {

        // Filtramos (Where)
        $match : {
            "fecha_ingreso" : { $lte : new Date()},
            "internacion_area.denominacion" : "Terapia Intensiva",
            fecha_salida : null
        }
    },

    // Ordenamos desde la internación más reciente a la más antigua.
    {
        $sort : { "fecha_ingreso" : -1}
        },
        // Select con los datos que precisamos
    {
        $project: {
            _id : 0,
            "paciente.nombre" : 1,
            "habitacion.nro" : 1,
            fecha_ingreso : 1,
            diagnostico_ppal : 1,
            "medico_asignado.apellido" : 1
        }
    }
                                                                            ])
// fecha_ingreso >= 2025-01-01 AND fecha_ingreso <= 2025-12-31
// fecha_salida >= 2025-01-01 AND fecha_salida <= 2025-12-31
// fecha_ingreso < 2025-01-01 AND fecha_salida >=  2025-12-31


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


db.internaciones.aggregate([
    {
        $match : {
            fecha_salida : { $ne : null }
        }
    },

    {
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
