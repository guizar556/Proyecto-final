----------------------------------------------
ALTER TABLE pedidios
DROP COLUMN año_de_pedido;

ALTER TABLE pedidios
ADD COLUMN fecha_de_pedido DATE;

ALTER TABLE pedidos_y_productos
ADD COLUMN discount numeric(10, 2) DEFAULT 0.0;

ALTER TABLE pedidos_y_productos
ADD COLUMN subtotal numeric(10, 2) DEFAULT 0.0;

ALTER TABLE pedidos_y_productos
DROP COLUMN estado_del_pedido;

ALTER TABLE productos
DROP COLUMN precio_unitario numeric(10, 2) DEFAULT 50.0;

SELECT column_name
FROM information_schema.columns
WHERE table_name = 'pedidos_y_productos';

drop table carrito;


SELECT column_name
FROM information_schema.columns
WHERE table_name = 'clientes';

SELECT column_name
FROM information_schema.columns
WHERE table_name = 'devoluciones';

SELECT column_name
FROM information_schema.columns
WHERE table_name = 'productosdevueltos';

SELECT column_name
FROM information_schema.columns
WHERE table_name = 'productos';

SELECT column_name
FROM information_schema.columns
WHERE table_name = 'ventas_y_productos';

SELECT column_name
FROM information_schema.columns
WHERE table_name = 'categorias';

SELECT column_name
FROM information_schema.columns
WHERE table_name = 'ventas';


SELECT column_name
FROM information_schema.columns
WHERE table_name = 'productosdevueltos';

ALTER TABLE ventas
DROP COLUMN dia;

ALTER TABLE ventas
DROP COLUMN mes;

ALTER TABLE ventas
DROP COLUMN año;

ALTER TABLE ventas
ADD COLUMN Description varchar(50) DEFAULT 'Venta Exitosa';

ALTER TABLE devoluciones
DROP COLUMN diadevolucion;

ALTER TABLE productosdevueltos
ADD COLUMN unit_price decimal(10,2) default 0.0;

ALTER TABLE devoluciones
DROP COLUMN foto_devolucion;

ALTER TABLE productosdevueltos
ADD COLUMN  unit_price  numeric(10, 2) DEFAULT 0.0 ;

ALTER TABLE ventas_y_productos
ADD CONSTRAINT chk_edad CHECK (cantidad >= 0);

ALTER TABLE productos
ADD CONSTRAINT chk_edad CHECK (stack_disponible >= 0);



UPDATE productos
SET stack_disponible = stack_disponible +200
WHERE codigo = 3;





