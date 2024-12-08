--------------------------------------------------
--Autores: Jonathan Guizar Morales,Juan Diego Lomeli Collazo, Osvaldo Gutierrez Sanchez.
--Fecha: 12 de Diciembre del 2024.
--Tema: Funcriones y procesos combinados en transacciones.
--------------------------------------------------
--1.- Generacion de una orden. 
----------------------------------
--Pasos a seguir para este proceso.
--Paso 1:Verificación de la existencia del cliente y el empleado.
--Paso 2:Inserción del pedido en la tabla de órdenes.
--Paso 3:Creación y manejo de una tabla temporal para detalles del pedido con los datos nesesarios.
--Paso 4:Insercion de los detalles del pedido sin eliminar los detalles de la tabla temporal 
--Paso 5:Generar la venta 
--Paso 6:Insertar los detalles de ventas, verificacion del estock dispinible,modificar el inventario y eliminar de la tabla temporal 
--Paso 7:Juntar los procedimientos anteriores
---------------------------------------------------------------------------------------
--Verificacion de la existencia del cliente y el empleado
--Funcion regresa valor de true
CREATE OR REPLACE FUNCTION verificar_cliente_empleado(codigo_c numeric, codigo_e numeric)
RETURNS BOOLEAN AS $$
BEGIN
    -- Verificar si el cliente existe
    IF NOT EXISTS (SELECT 1 FROM clientes WHERE codigo = codigo_c) THEN
        RAISE EXCEPTION 'El cliente % no existe', codigo_c;
    END IF;

    -- Verificar si el empleado existe
    IF NOT EXISTS (SELECT 1 FROM empleados WHERE codigo = codigo_e) THEN
        RAISE EXCEPTION 'El empleado % no existe', codigo_e;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

--Datos de tipo entero 
select verificar_cliente_empleado(3,2);


--Generacion del pedido
--Funcion regresa el id de la orden o pedido
CREATE OR REPLACE FUNCTION generacion_del_pedido(
    codigo_c NUMERIC, 
    codigo_e NUMERIC, 
    descripcion_pedido TEXT
)
RETURNS INT AS $$
DECLARE
    _order_id INT;
BEGIN
	-- Validar que la descripción no sea nula o vacía
    IF descripcion_pedido IS NULL OR descripcion_pedido = '' THEN
        RAISE EXCEPTION 'La descripción del pedido no puede ser nula o vacía.';
    END IF;

    -- Generar un nuevo ID de pedido
    SELECT COALESCE(MAX(codigo), 0) + 1 INTO _order_id FROM pedidios;

    -- Insertar el pedido con los datos proporcionados
    INSERT INTO pedidios 
    VALUES (_order_id, descripcion_pedido, codigo_c, codigo_e, CURRENT_DATE);

    RETURN _order_id;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------
select generacion_del_pedido(2,5,'112 kg de crema');
select * from pedidios;
-----------------------------------------------------

--Paso 3:Creación y manejo de una tabla temporal para detalles del pedido con los datos nesesarios.
CREATE TABLE carrito(
	codigo serial,
	codigo_c int,
	cantidad int,
	codigo_pr int
)

INSERT INTO carrito (codigo_c, cantidad, codigo_pr) VALUES
(1, 2, 1),  -- Cliente 1, 2 unidades del producto 1
(2, 3, 2),  -- Cliente 2, 3 unidades del producto 2
(3, 1, 3),  -- Cliente 3, 1 unidad del producto 3
(4, 4, 4),  -- Cliente 4, 4 unidades del producto 4
(5, 5, 5),  -- Cliente 5, 5 unidades del producto 5
(1, 2, 2),  -- Cliente 1, 2 unidades del producto 2
(2, 1, 4);  -- Cliente 2, 1 unidad del producto 4

select * from carrito;
--drop table carrito;
--Paso 4:Insercion de los detalles del pedido
--recibe los parametros de la orden y el cliente 
CREATE OR REPLACE FUNCTION insercion_dt(codigo_pedido NUMERIC, codigo_cliente NUMERIC)
RETURNS VOID AS $$
DECLARE
    _codigo_c INT;
    _cantidad INT;
    _codigo_pr INT;
    _precio_unitario NUMERIC;
    _subtotal NUMERIC;
    _discount NUMERIC := 0.0;
    _stock_disponible INT;
BEGIN
    -- Iterar sobre los productos en el carrito para un cliente específico
    FOR _codigo_c, _cantidad, _codigo_pr IN
        SELECT codigo_c, cantidad, codigo_pr
        FROM carrito
        WHERE codigo_c = codigo_cliente  -- Filtrar solo los productos para el cliente específico
    LOOP
        -- Verificar si el producto existe en la tabla productos
        IF NOT EXISTS (SELECT 1 FROM productos WHERE codigo = _codigo_pr) THEN
            RAISE EXCEPTION 'El producto con código % no existe.', _codigo_pr;
        END IF;

        -- Recuperar el precio unitario del producto
        SELECT precio_unitario INTO _precio_unitario
        FROM productos
        WHERE codigo = _codigo_pr;
        
        -- Calcular el subtotal (cantidad * precio unitario)
        _subtotal := _cantidad * _precio_unitario;

        -- Insertar el detalle del pedido en la tabla pedidos_y_productos
        INSERT INTO pedidos_y_productos 
        (cantidad, preciounitario, codigoproductos, codigopedidios, discount, subtotal)
        VALUES (
            _cantidad, 
            _precio_unitario, 
            _codigo_pr, 
            codigo_pedido, 
            _discount, 
            _subtotal
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;
------------------------------------------------------------------------
select insercion_dt(10,1)
select * from pedidos_y_productos order by codigo desc;
------------------------------------------------------------------------
-- Generar la venta
CREATE OR REPLACE FUNCTION generar_venta(
    tipo_pago TEXT,
    codigo_pedido NUMERIC,
    descripcion TEXT
)
RETURNS INT AS $$
DECLARE
    _codigo_venta INT;
BEGIN
    -- Validar que el tipo de pago no sea nulo o vacío
    IF tipo_pago IS NULL OR tipo_pago = '' THEN
        RAISE EXCEPTION 'El tipo de pago no puede ser nulo o vacío.';
    END IF;

    -- Validar que la descripción no sea nula o vacía
    IF descripcion IS NULL OR descripcion = '' THEN
        RAISE EXCEPTION 'La descripción de la venta no puede ser nula o vacía.';
    END IF;

    -- Generar un nuevo ID para la venta
    SELECT COALESCE(MAX(codigo), 0) + 1 INTO _codigo_venta FROM ventas;

    -- Insertar la venta
    INSERT INTO ventas (
        codigo, tipo_pago, codigo_pedido, fecha_de_venta, description
    ) VALUES (
        _codigo_venta, tipo_pago, codigo_pedido, CURRENT_DATE, descripcion
    );

    RETURN _codigo_venta;
END;
$$ LANGUAGE plpgsql;
-----------------------------------------------------------------------------
-- Prueba de la función
SELECT generar_venta( 'Efectivo', 20, 'Venta de productos lácteos');
SELECT * FROM ventas;

-- Insertar detalles de venta y modificar inventario
CREATE OR REPLACE FUNCTION insertar_detalles_venta(
    codigo_venta NUMERIC,
    codigo_cliente NUMERIC
)
RETURNS VOID AS $$
DECLARE
    _codigo_c INT;
    _cantidad INT;
    _codigo_pr INT;
    _precio_unitario NUMERIC;
    _subtotal NUMERIC;
    _discount NUMERIC := 0.0; 
    _stock_disponible INT;
BEGIN
    -- Iterar sobre los productos en el carrito del cliente
    FOR _codigo_c, _cantidad, _codigo_pr IN
        SELECT codigo_c, cantidad, codigo_pr
        FROM carrito
        WHERE codigo_c = codigo_cliente
    LOOP
        -- Verificar si el producto existe
        IF NOT EXISTS (SELECT 1 FROM productos WHERE codigo = _codigo_pr) THEN
            RAISE EXCEPTION 'El producto con código % no existe.', _codigo_pr;
        END IF;

        -- Verificar el stock disponible
        SELECT stack_disponible INTO _stock_disponible
        FROM productos
        WHERE codigo = _codigo_pr;

        IF _stock_disponible < _cantidad THEN
            RAISE EXCEPTION 'No hay suficiente stock para el producto %.', _codigo_pr;
        END IF;

        -- Recuperar el precio unitario del producto
        SELECT precio_unitario INTO _precio_unitario
        FROM productos
        WHERE codigo = _codigo_pr;

        -- Calcular el subtotal (cantidad * precio unitario)
        _subtotal := _cantidad * _precio_unitario;

        -- Insertar los detalles en ventas_y_productos
        INSERT INTO ventas_y_productos (
            preciounitario, cantidad, codigo_venta, codigo_producto, subtotal, discount
        ) VALUES (
            _precio_unitario, _cantidad, codigo_venta, _codigo_pr, _subtotal, _discount
        );

        -- Actualizar el inventario
        UPDATE productos
        SET stack_disponible = stack_disponible - _cantidad
        WHERE codigo = _codigo_pr;
    END LOOP;
	-- Eliminar los registros del carrito para el cliente
	DELETE FROM carrito
    WHERE codigo_c = codigo_cliente;
END;
$$ LANGUAGE plpgsql;
------------------------------------
-- Prueba de la función
SELECT insertar_detalles_venta(9, 1);
SELECT * FROM ventas_y_productos;
SELECT * FROM productos;
select * from carrito;
-------------------------------------
-- Función combinada para procesar un pedido, desde la verificación hasta la venta.
CREATE OR REPLACE FUNCTION procesar_pedido_completo(
    codigo_c NUMERIC,
    codigo_e NUMERIC,
    descripcion_pedido TEXT,
    tipo_pago TEXT,
    descripcion_venta TEXT
)
RETURNS VOID AS $$
DECLARE
    _order_id INT;
    _codigo_venta INT;
BEGIN
    -- Paso 1: Verificación del cliente y el empleado
    PERFORM verificar_cliente_empleado(codigo_c, codigo_e);

    -- Paso 2: Generación del pedido
    _order_id := generacion_del_pedido(codigo_c, codigo_e, descripcion_pedido);

    -- Paso 3: Inserción de los detalles del pedido y modificación del inventario
    PERFORM insercion_dt(_order_id, codigo_c);

    -- Paso 4: Generar la venta
    _codigo_venta := generar_venta(tipo_pago, _order_id, descripcion_venta);

    -- Paso 5: Insertar detalles de la venta y modificar inventario
    PERFORM insertar_detalles_venta(_codigo_venta, codigo_c);

    -- Confirmación del proceso (no es necesario hacer un COMMIT aquí)
    RAISE NOTICE 'Pedido % procesado correctamente.', _order_id;
END;
$$ LANGUAGE plpgsql;

--cliente,empleado,descripccion pedido,tipo pago,descripccion de la venta
select procesar_pedido_completo(5,2,'Buenoooooo','Tarjeton','VEnta rapida');
select * from pedidios;--33
select * from pedidos_y_productos;--34
select * from ventas;--27
select * from ventas_y_productos;--29
select * from carrito;

--modificar reguistro
UPDATE carrito
SET cantidad = cantidad +200
WHERE codigo_c = 5;

/*
UPDATE carrito
SET stack_disponible = stack_disponible +200
WHERE codigo = 3;
*/

--cliente,producto,cantidad
select insertar_o_actualizar_carrito(5,5,300);
select * from carrito;
drop table carrito;






































---------------------------------------
-- insercion
CREATE OR REPLACE FUNCTION insertar_carrito(
    p_codigo_c int,
    p_codigo_pr int,
    p_cantidad int
) RETURNS void AS $$
BEGIN
    -- Verificar si ya existe un registro con el mismo codigo_c y codigo_pr
    IF EXISTS (
        SELECT 1
        FROM carrito
        WHERE codigo_c = p_codigo_c AND codigo_pr = p_codigo_pr
    ) THEN
        -- Si existe, actualizar la cantidad del producto para el cliente
        UPDATE carrito
        SET cantidad = cantidad+p_cantidad 
        WHERE codigo_c = p_codigo_c AND codigo_pr = p_codigo_pr;
        RAISE NOTICE 'El registro fue actualizado para codigo_c: %, codigo_pr: %', p_codigo_c, p_codigo_pr;
    ELSE
        -- Si no existe, insertar el nuevo registro
        INSERT INTO carrito (codigo_c, codigo_pr, cantidad)
        VALUES (p_codigo_c, p_codigo_pr, p_cantidad);
        RAISE NOTICE 'El registro fue insertado para codigo_c: %, codigo_pr: %', p_codigo_c, p_codigo_pr;
    END IF;
END;
$$ LANGUAGE plpgsql;

select * from pedidos_y_productos;
select* from productos;
select * from carrito;
select * from pedidios;





