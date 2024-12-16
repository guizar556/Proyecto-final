--------------------------------------------------
--Autores: Jonathan Guizar Morales,Juan Diego Lomeli Collazo, Osvaldo Gutierrez Sanchez.
--Fecha: 12 de Diciembre del 2024.
--Tema: Funcriones y procesos combinados en transacciones.
--------------------------------------------------
--1.- Compras a Provedores. 
-------------------------------------------------------------------------------------
--Paso 1: Verificacion de la existencia del provedor 
--Paso 2: Creacion de la tabla temporal con los datos esenciales de los detalles de la compra
--Paso 3: Verificacion de la existencia del provedor en la tabla temporal, Verificcacion de que surta el producto y verificacion de la existencia del producto
--Paso 4: Insercion de la compra
--Paso 5: Insercion de los detalles de la compra
--Paso 6: Unir los procesos anteriores
---------------------------------------------------------------------------------------
--Paso 1: Verificar que el provedor exista 
CREATE OR REPLACE FUNCTION verificar_existencia_proveedor(codigo_proveedor INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    existe BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 
        FROM provedores 
        WHERE codigo = codigo_proveedor
    ) INTO existe;

    RETURN existe;
END;
$$ LANGUAGE plpgsql;
------------------------------------------------------
select verificar_existencia_proveedor(7);--Inexistente 
select verificar_existencia_proveedor(2);--Existente 
------------------------------------------------------

--Paso 2:Crear tabla temporal para detalles de compra
CREATE TABLE  detalles_temporales (
	codigo serial,
	id_proveedor INTEGER,
	precio NUMERIC,
	id_producto INTEGER,
	cantidad INTEGER
);

--Insercion de reguistros 
Insert into detalles_temporales (id_proveedor,precio,id_producto,cantidad)
values 
	(1,15.250,1,76),
	(2,20.500,2,7),
	(3,12.750,3,3),
	(4,8.900,4,4),
	(5,7.500,5,5),
	(1,16.300,2,8)
--select * from detproductos_y_provedores;
--select * from detalles_temporales;
--drop table detalles_temporales;

--Paso 3: Verificacion de la existencia del provedor en la tabla temporal, Verificcacion de que surta el producto y verificacion de la existencia del producto
CREATE OR REPLACE FUNCTION verificar_detalles_compra_proveedor(
    _codigo_proveedor INTEGER
)
RETURNS void AS $$
DECLARE
    registro RECORD;
    producto_existe BOOLEAN;
    producto_surten BOOLEAN;
BEGIN
    -- Paso 1: Verificar si el proveedor tiene registros en la tabla temporal
    IF NOT EXISTS (SELECT 1 FROM detalles_temporales WHERE id_proveedor = _codigo_proveedor) THEN
        RAISE EXCEPTION 'El proveedor con código % no tiene registros de compra pendientes en la tabla temporal.', _codigo_proveedor;
    END IF;

    -- Paso 2: Iterar sobre los registros de la tabla temporal y verificar los productos
    FOR registro IN
        SELECT * 
        FROM detalles_temporales
        WHERE id_proveedor = _codigo_proveedor
    LOOP
        -- Verificar si el producto existe en la tabla de productos
        SELECT EXISTS(
            SELECT 1
            FROM productos
            WHERE codigo = registro.id_producto
        ) INTO producto_existe;

        IF NOT producto_existe THEN
            RAISE EXCEPTION 'El producto con código % no existe en la base de datos.', registro.id_producto;
        END IF;

        -- Verificar si el proveedor surte el producto en la tabla de proveedores y productos
        SELECT EXISTS(
            SELECT 1
            FROM detproductos_y_provedores
            WHERE codigo_proveedor = _codigo_proveedor AND codigo_producto = registro.id_producto
        ) INTO producto_surten;

        IF NOT producto_surten THEN
            RAISE EXCEPTION 'El proveedor con código % no surte el producto con código %. en el reguistro:%,', _codigo_proveedor, registro.id_producto,registro.codigo;
        END IF;
    END LOOP;

    -- Si todo está bien, la función termina sin errores
    RAISE NOTICE 'Todos los registros han sido verificados exitosamente.';
END;
$$ LANGUAGE plpgsql;
-----------------------------------------------------
select verificar_detalles_compra_proveedor(4);--Correcto
select verificar_detalles_compra_proveedor(5);--Incorrecto
select verificar_detalles_compra_proveedor(2);--Incorrecto
Insert into detalles_temporales (id_proveedor,precio,id_producto,cantidad)
values
(5,12.45,1,7),--Provedor no surte ese producto
(2,20.500,9,7)--No existe el id del product
delete from detalles_temporales
where codigo = 7;
----------------------------------
delete from detalles_temporales
where codigo = 6;
----------------------------------
select * from detalles_temporales;
-----------------------------------------------------

--Paso 4: Realizar la compra
CREATE OR REPLACE FUNCTION realizar_compraa(codigo_proveedor INTEGER, tipodecompra VARCHAR, estado_compra VARCHAR)
RETURNS INTEGER AS $$
DECLARE
    codigo_compra INTEGER;
BEGIN
    INSERT INTO compras (tipodecompra, estado_compra, codigo_proveedor, fecha_compra)
    VALUES (tipodecompra, estado_compra, codigo_proveedor, current_date)
    RETURNING codigo INTO codigo_compra;

    RETURN codigo_compra;
END;
$$ LANGUAGE plpgsql;
------------------------------------------------------
--codigo provedor, tipo compra, estado compra
select realizar_compraa(1,'Minorista','Realizada'); 
select * from compras order by codigo desc;
------------------------------------------------------


--Paso 5: Insertar los detalles de la compra 
CREATE OR REPLACE FUNCTION procesar_detalles_compra(_codigo_proveedor INTEGER,_codigo_compra integer)
RETURNS TEXT AS $$
DECLARE
    registro RECORD;
BEGIN
    -- Iterar sobre los registros de la tabla temporal
    FOR registro IN 
        SELECT * 
        FROM detalles_temporales 
        WHERE id_proveedor = _codigo_proveedor
    LOOP
        -- Insertar detalles de compra
        INSERT INTO compras_y_productos (
            codigo_compra, 
            codigo_producto, 
            cantidad_de_productos_comprados, 
            preciounitario, 
            descripccion
        )
        VALUES (
            _codigo_compra, 
            registro.id_producto, 
            registro.cantidad, 
            registro.precio, 
            'Compra procesada automáticamente'
        );

        -- Modificar la cantidad de productos en el inventario
        UPDATE productos
        SET stack_disponible = stack_disponible + registro.cantidad
        WHERE codigo = registro.id_producto;

        -- Eliminar el registro de la tabla temporal
        DELETE FROM detalles_temporales 
        WHERE id_proveedor = _codigo_proveedor 
          AND id_producto = registro.id_producto 
          AND cantidad = registro.cantidad 
          AND precio = registro.precio;
    END LOOP;

    RETURN 'Los detalles de la compra han sido procesados exitosamente.';
END;
$$ LANGUAGE plpgsql;


------------------------------------------------------------
select procesar_detalles_compra(1,9);--Id provedor 
select * from detalles_temporales;-- 3,3    id producto,cantidad
select * from compras_y_productos order by codigo desc;--57  id 2 -- 90 3-210+3 = 213
select * from productosdevueltos order by codigo desc;
select * from productos;--239
--------------------------------------------------------------


--Paso 6: Juntar los procedimiento 
CREATE OR REPLACE FUNCTION gestionar_compra_completa(
    _codigo_proveedor INTEGER, 
    _tipodecompra VARCHAR, 
    _estado_compra VARCHAR
)
RETURNS TEXT AS $$
DECLARE
    codigo_compra INTEGER;
    mensaje TEXT;
BEGIN
    -- Paso 1: Verificar que el proveedor exista
    IF NOT verificar_existencia_proveedor(_codigo_proveedor) THEN
        RAISE EXCEPTION 'El proveedor con código % no existe.', _codigo_proveedor;
    END IF;

    -- Paso 2: Verificar detalles de la compra en la tabla temporal
    PERFORM verificar_detalles_compra_proveedor(_codigo_proveedor);

    -- Paso 3: Registrar la compra y obtener el código generado
    codigo_compra := realizar_compraa(_codigo_proveedor, _tipodecompra, _estado_compra);

    -- Paso 4: Procesar los detalles de la compra
    mensaje := procesar_detalles_compra(_codigo_proveedor,codigo_compra);

    -- Resultado final
    RETURN ('Compra completada exitosamente. Código de compra: % Detalles: %', codigo_compra, mensaje);
END;
$$ LANGUAGE plpgsql;


---------------------------------------------------------------------
SELECT gestionar_compra_completa(5, '12', 'Realizada');
---------------------------------------------------------------------
select * from Compras order by codigo desc; --16--33
select * from compras_y_productos order by codigo desc;--45--54
select * from productos;
select * from detalles_temporales;
----------------------------------------------------------------------
--Insercion de reguistros 
Insert into detalles_temporales (id_proveedor,precio,id_producto,cantidad)
values 
(3,12.750,3,3),
(5,12.45,1,7),--Provedor no surte ese producto
(2,20.500,9,7)--No existe el id del product

/*
--Paso 2:Crear tabla temporal para detalles de compra
CREATE  TABLE  detalles_temporales (
	codigo serial,
	id_proveedor INTEGER,
	precio NUMERIC,
	id_producto INTEGER,
	cantidad INTEGER
);
*/

--Insertar datos en la tabla temporal 
--drop table detalles_temporales;
-------------------------------------------------------------
--_id_proveedor, _precio, _id_producto, _cantidad
select insertar_o_actualizar_detalles_temporales(4,8.900,8,4);
select insertar_o_actualizar_detalles_temporales(5,40.3,8,8);
select insertar_o_actualizar_detalles_temporales(5,15.250,1,5);



















CREATE OR REPLACE FUNCTION insertar_o_actualizar_detalles_temporales(
    _id_proveedor INTEGER,
    _precio NUMERIC,
    _id_producto INTEGER,
    _cantidad INTEGER
)
RETURNS VOID AS $$
DECLARE
    registro_existente INTEGER;
BEGIN
    -- Verificar si existe un registro con el mismo proveedor y producto
    SELECT codigo INTO registro_existente
    FROM detalles_temporales
    WHERE id_proveedor = _id_proveedor AND id_producto = _id_producto;

    IF registro_existente IS NOT NULL THEN
        -- Si el registro existe, actualizar la cantidad
        UPDATE detalles_temporales
        SET cantidad = cantidad + _cantidad
        WHERE codigo = registro_existente;
    ELSE
        -- Si no existe, insertar un nuevo registro
        INSERT INTO detalles_temporales (id_proveedor, precio, id_producto, cantidad)
        VALUES (_id_proveedor, _precio, _id_producto, _cantidad);
    END IF;
END;
$$ LANGUAGE plpgsql;
