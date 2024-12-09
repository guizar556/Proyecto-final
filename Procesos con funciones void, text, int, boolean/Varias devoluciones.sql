---------------------------------------------------------------
--Autores: Jonathan Guizar Morales, Juan Diego Lomeli Collazo, Osvaldo Guitierres Sanches
--Fecha: 12/12/2024
--Tema: Procedimientos y funciones combinados en transacciones 
---------------------------------------------------------------
--Proceso de Devoluciones
--Pasos 
--Paso 1: Creacion de una tabla temporal con los datos esenciales y nesesarios para llevar a cavo una devolucion 
--Paso 2: Verificacion de la existencia del cliente 
--Paso 3: Verificar que la venta exista, la cantidad devuelta no sea mayor que la comprada,verificar que el producto pertenesca ala venta y que xista el producto
--Paso 4: Insercion de la devolucion
--Paso 5: Inserción de detalles de devolución, actualización de inventario y ventas, y eliminación de registros procesados
--Paso 6: Juntar los porcesos anteriores
------------------------------------------------------------------------------------------------
--Paso 1: Creacion de una tabla temporal con los datos esenciales y nesesarios para llevar a cavo una devolucion 
CREATE TEMP TABLE devoluciones_lote (
    codigo_cliente INT,
    codigo_venta INT,
    codigo_producto INT,
    cantidad_a_devolver INT,
    estado_producto VARCHAR,
	codigo_vp INT
);
--Insertar detalles 
INSERT INTO devoluciones_lote (
    codigo_cliente, codigo_venta, codigo_producto, cantidad_a_devolver, estado_producto,codigo_vp
)
VALUES
    (1, 1, 1, 2, 'bueno',1),
    (1, 1, 2, 1, 'dañado',2),
    (2, 2, 3, 3, 'bueno',3),
	(4,28,2,3,'dañado',31)
	
--select * from devoluciones_lote;
--select * from ventas_y_productos order by codigo desc;
--drop table devoluciones_lote;

--Paso 2: Verificacion de la existencia del cliente 
CREATE OR REPLACE FUNCTION verificar_cliente(
    _codigo_cliente INT
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM clientes WHERE codigo = _codigo_cliente
    );
END;
$$ LANGUAGE plpgsql;
-------------------------------
select verificar_cliente(7);--Inexistente
select verificar_cliente(5);--Existente
select * from devoluciones_lote;
select * from ventas_y_productos;
------------------------------

--Paso 3: Verificar que la venta exista, la cantidad devuelta no sea mayor que la comprada,verificar que el producto pertenesca ala venta y que xista el producto
CREATE OR REPLACE FUNCTION procesar_devoluciones(
    _codigo_cliente INT
) RETURNS VOID AS $$
DECLARE
    rec RECORD;
    _cantidad_vendida INT;
BEGIN
    -- Verificar si existen registros de devoluciones para el cliente
    IF NOT EXISTS (
        SELECT 1 FROM devoluciones_lote WHERE codigo_cliente = _codigo_cliente
    ) THEN
        RAISE EXCEPTION 'El cliente % no tiene registros de devolución.', _codigo_cliente;
    END IF;

    -- Iterar sobre cada registro en la tabla temporal de devoluciones para el cliente
    FOR rec IN
        SELECT codigo_venta, codigo_producto, cantidad_a_devolver, codigo_vp
        FROM devoluciones_lote
        WHERE codigo_cliente = _codigo_cliente
    LOOP
        -- Verificar si la venta existe en la tabla ventas
        IF NOT EXISTS (
            SELECT 1 FROM ventas WHERE codigo = rec.codigo_venta
        ) THEN
            RAISE EXCEPTION 'La venta % no existe para el cliente %.', rec.codigo_venta, _codigo_cliente;
        END IF;

        -- Verificar si el producto existe en la tabla productos
        IF NOT EXISTS (
            SELECT 1 FROM productos WHERE codigo = rec.codigo_producto
        ) THEN
            RAISE EXCEPTION 'El producto % no existe.', rec.codigo_producto;
        END IF;

        -- Verificar si la cantidad a devolver no es mayor a la cantidad comprada
        SELECT cantidad INTO _cantidad_vendida
        FROM ventas_y_productos
        WHERE codigo_venta = rec.codigo_venta AND codigo_producto = rec.codigo_producto;

        IF rec.cantidad_a_devolver > _cantidad_vendida THEN
            RAISE EXCEPTION 'La cantidad a devolver (%), para el producto % es mayor que la cantidad comprada (%).', 
                             rec.cantidad_a_devolver, rec.codigo_producto, _cantidad_vendida;
        END IF;

        -- Verificar que el producto en la venta corresponda con el producto de la devolución
        IF NOT EXISTS (
            SELECT 1 FROM ventas_y_productos
            WHERE codigo_venta = rec.codigo_venta AND codigo_producto = rec.codigo_producto AND codigo = rec.codigo_vp
        ) THEN
            RAISE EXCEPTION 'El producto % no coincide con la venta % para el cliente % (código detalle: %).', 
                             rec.codigo_producto, rec.codigo_venta, _codigo_cliente, rec.codigo_vp;
        END IF;
    END LOOP;

    -- Si todo está correcto, finalizar sin errores
    RAISE NOTICE 'Todas las devoluciones para el cliente % se han validado correctamente.', _codigo_cliente;
END;
$$ LANGUAGE plpgsql;

-------------------------
select procesar_devoluciones(3);--Existente retorna void: nada
select procesar_devoluciones(7);--Retorna que el cliente no tiene nada en la tabla temporal de la devolcion
select * from ventas_y_productos;
select * from devoluciones_lote;
update ventas_y_productos
set cantidad = cantidad + 20
where codigo = 31;
-------------------------


--Paso 4: Insercion de la devolucion
CREATE OR REPLACE FUNCTION crear_devolucion(
    _codigo_cliente INT
) RETURNS INT AS $$
DECLARE
    _codigo_devolucion INT;
BEGIN
    INSERT INTO devoluciones (descripcciondedevolucion, hora, codigo_cliente, fecha_devolucion)
    VALUES ('Devolución registrada', CURRENT_TIME, _codigo_cliente, CURRENT_DATE)
    RETURNING codigo INTO _codigo_devolucion;

    RETURN _codigo_devolucion;
END;
$$ LANGUAGE plpgsql;
--------------------------------------------------
select crear_devolucion(4);
select * from devoluciones order by codigo desc;--Verificar el ultimo reguistro
---------------------------------------------------


--Paso 5: Insercion de los detalles de devolucion y modificacion en el inventario y la venta 
------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION insertar_detalle_devolucion(
    _codigo_venta INT,
    _codigo_devolucion INT,
    _codigo_cliente INT
) RETURNS VOID AS $$
DECLARE
    rec RECORD;
    _precio_unitario NUMERIC;
    _cantidad_disponible INT;
BEGIN
    -- Verificar si el cliente tiene productos para devolver
    IF NOT EXISTS (SELECT 1 FROM devoluciones_lote WHERE codigo_cliente = _codigo_cliente) THEN
        RAISE EXCEPTION 'El cliente con código % no tiene productos para devolver.', _codigo_cliente;
    END IF;

    FOR rec IN
        SELECT codigo_producto, estado_producto, cantidad_a_devolver AS total_a_devolver, codigo_vp
        FROM devoluciones_lote
        WHERE codigo_cliente = _codigo_cliente
    LOOP
        -- Verificar cantidad válida
        IF rec.total_a_devolver <= 0 THEN
            RAISE EXCEPTION 'Cantidad inválida para devolver: %', rec.codigo_producto;
        END IF;

        -- Bloquear y verificar cantidad en ventas_y_productos
        SELECT cantidad INTO _cantidad_disponible
        FROM ventas_y_productos
        WHERE codigo_producto = rec.codigo_producto AND codigo = rec.codigo_vp
        FOR UPDATE;

        IF rec.total_a_devolver > _cantidad_disponible THEN
            RAISE EXCEPTION 'Cantidad a devolver excede cantidad disponible: %', rec.codigo_producto;
        END IF;

        -- Obtener precio unitario
        SELECT preciounitario INTO _precio_unitario
        FROM ventas_y_productos
        WHERE codigo_producto = rec.codigo_producto AND codigo = rec.codigo_vp;

        -- Procesar según el estado del producto
        IF rec.estado_producto = 'bueno' THEN
            -- Insertar y sumar al inventario
            INSERT INTO productosdevueltos (
                codigo_devolucion, codigo_vp, observaciones, cantidad, subtotal, unit_price
            )
            VALUES (
                _codigo_devolucion,
                rec.codigo_vp,
                rec.estado_producto,
                rec.total_a_devolver,
                rec.total_a_devolver * _precio_unitario,
                _precio_unitario
            );
            UPDATE productos
            SET stack_disponible = stack_disponible + rec.total_a_devolver
            WHERE codigo = rec.codigo_producto;
        ELSIF rec.estado_producto = 'dañado' THEN
            -- Insertar sin sumar al inventario
            INSERT INTO productosdevueltos (
                codigo_devolucion, codigo_vp, observaciones, cantidad, subtotal, unit_price
            )
            VALUES (
                _codigo_devolucion,
                rec.codigo_vp,
                rec.estado_producto,
                rec.total_a_devolver,
                rec.total_a_devolver * _precio_unitario,
                _precio_unitario
            );
        END IF;

        -- Actualizar ventas_y_productos
        UPDATE ventas_y_productos
        SET 
            cantidad = cantidad - rec.total_a_devolver,
            subtotal = (cantidad - rec.total_a_devolver) * preciounitario
        WHERE codigo_producto = rec.codigo_producto AND codigo = rec.codigo_vp;

        -- Eliminar registro procesado
        DELETE FROM devoluciones_lote
        WHERE codigo_cliente = _codigo_cliente
          AND codigo_producto = rec.codigo_producto
          AND codigo_vp = rec.codigo_vp;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
---------------------------------------------------
--codigo venta,codigo devolucion, codigo cliente
select insertar_detalle_devolucion(1,11,1);
select * from ventas order by codigo desc;--40
select * from devoluciones order by codigo desc; --39
select * from productosdevueltos order by codigo desc;--104--110--112
select * from ventas_y_productos order by codigo desc;--41--46
select * from devoluciones_lote;--codigo vp 1,2
select * from productos order by codigo;--
----------------------------------------------------------

CREATE OR REPLACE FUNCTION procesar_devolucion_completa(
    _codigo_cliente INT
) RETURNS VOID AS $$
DECLARE
    _codigo_devolucion INT;
BEGIN
    -- Paso 1: Verificar la existencia del cliente
    IF NOT verificar_cliente(_codigo_cliente) THEN
        RAISE EXCEPTION 'El cliente % no existe.', _codigo_cliente;
    END IF;

    -- Paso 2: Procesar las devoluciones para el cliente
    PERFORM procesar_devoluciones(_codigo_cliente);

    -- Paso 3: Crear la devolución
    _codigo_devolucion := crear_devolucion(_codigo_cliente);

    -- Paso 4: Insertar los detalles de la devolución
    PERFORM insertar_detalle_devolucion(_codigo_cliente, _codigo_devolucion, _codigo_cliente);

    -- Finalizar con éxito
    RAISE NOTICE 'Devolución completada correctamente para el cliente %.', _codigo_cliente;
END;
$$ LANGUAGE plpgsql;
-----------------------------------------------------------------------
SELECT procesar_devolucion_completa(2);
select * from ventas;
select * from devoluciones;
select * from productosdevueltos;--112
select * from ventas_y_productos;--49
select * from devoluciones_lote;--28--2--3 =  8
select * from productos;--106   --218

update ventas_y_productos
set cantidad = cantidad + 20
where codigo = 31;
-----------------------------------------------------------------------
-- Llamar a la función para insertar o actualizar registros
--  codigo_cliente, codigo_venta, codigo_producto, cantidad_a_devolver, estado_producto,codigo_vp
SELECT insertar_o_actualizar_devolucion(5, 100, 3, 3, 'bueno', 1);--Venta no existente
SELECT insertar_o_actualizar_devolucion(2, 5, 2, 1, 'dañado', 2);--Diferente el codigo
SELECT insertar_o_actualizar_devolucion(3, 5, 9, 1, 'dañado', 2);--Producto No existente
select * from ventas_y_productos;
-----------------------------------------

/*
CREATE TEMP TABLE devoluciones_lote (
    codigo_cliente INT,
    codigo_venta INT,
    codigo_producto INT,
    cantidad_a_devolver INT,
    estado_producto VARCHAR,
	codigo_vp INT
);
--Insertar detalles 
INSERT INTO devoluciones_lote (
    codigo_cliente, codigo_venta, codigo_producto, cantidad_a_devolver, estado_producto,codigo_vp
)
VALUES
    (1, 1, 1, 2, 'bueno',1),
    (1, 1, 2, 1, 'dañado',2),
    (2, 2, 3, 3, 'bueno',3),
	(4,28,2,3,'dañado',31)
*/



































--Insercion en la tabla temporal y una verificacion 

CREATE OR REPLACE FUNCTION insertar_o_actualizar_devolucion(
    _codigo_cliente INT,
    _codigo_venta INT,
    _codigo_producto INT,
    _cantidad_a_devolver INT,
    _estado_producto VARCHAR,
    _codigo_vp INT
) RETURNS VOID AS $$
DECLARE
    _registro_existente RECORD;
BEGIN
    -- Verificar si ya existe un registro con el mismo cliente, venta y producto
    SELECT * INTO _registro_existente
    FROM devoluciones_lote
    WHERE codigo_cliente = _codigo_cliente
      AND codigo_venta = _codigo_venta
      AND codigo_producto = _codigo_producto;

    IF FOUND THEN
        -- Si existe, actualizar el registro
        UPDATE devoluciones_lote
        SET cantidad_a_devolver = cantidad_a_devolver + _cantidad_a_devolver,
            estado_producto = _estado_producto,
            codigo_vp = _codigo_vp
        WHERE codigo_cliente = _codigo_cliente
          AND codigo_venta = _codigo_venta
          AND codigo_producto = _codigo_producto;

        RAISE NOTICE 'Registro actualizado para cliente %, venta %, producto %.', _codigo_cliente, _codigo_venta, _codigo_producto;
    ELSE
        -- Si no existe, insertar un nuevo registro
        INSERT INTO devoluciones_lote (
            codigo_cliente, codigo_venta, codigo_producto, cantidad_a_devolver, estado_producto, codigo_vp
        )
        VALUES (
            _codigo_cliente, _codigo_venta, _codigo_producto, _cantidad_a_devolver, _estado_producto, _codigo_vp
        );

        RAISE NOTICE 'Registro insertado para cliente %, venta %, producto %.', _codigo_cliente, _codigo_venta, _codigo_producto;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Llamar a la función para insertar o actualizar registros
SELECT insertar_o_actualizar_devolucion(5, 1, 10, 3, 'bueno', 1);
SELECT insertar_o_actualizar_devolucion(1, 1, 2, 1, 'dañado', 2);
SELECT insertar_o_actualizar_devolucion(2, 3, 2, 3, 'bueno', 3);
SELECT insertar_o_actualizar_devolucion(4, 28, 2, 1, 'dañado', 31);
select * from ventas_y_productos;
-----------------------------------------