-- =============================================================================
-- PRÁCTICA: BASE DE DATOS "VIVEROS" (TAJINASTE S.A.)
-- SGBD: PostgreSQL
-- =============================================================================

-- 1. CREACIÓN DE LA BASE DE DATOS
-- Descomentar la siguiente línea si lo ejecutas desde la consola de PostgreSQL (psql):
-- CREATE DATABASE viveros;
-- \c viveros;

-- 2. LIMPIEZA PREVIA DE TABLAS (SI EXISTEN)
DROP VIEW IF EXISTS vista_bonificaciones_completas CASCADE;
DROP VIEW IF EXISTS vista_pedidos_con_total CASCADE;

DROP TABLE IF EXISTS detalle_pedido CASCADE;
DROP TABLE IF EXISTS pedido CASCADE;
DROP TABLE IF EXISTS bonificacion_mensual CASCADE;
DROP TABLE IF EXISTS cliente_plus CASCADE;
DROP TABLE IF EXISTS cliente CASCADE;
DROP TABLE IF EXISTS objetivo_venta CASCADE;
DROP TABLE IF EXISTS puesto_tarea CASCADE;
DROP TABLE IF EXISTS tarea CASCADE;
DROP TABLE IF EXISTS puesto CASCADE;
DROP TABLE IF EXISTS empleado CASCADE;
DROP TABLE IF EXISTS almacena CASCADE;
DROP TABLE IF EXISTS producto CASCADE;
DROP TABLE IF EXISTS zona CASCADE;
DROP TABLE IF EXISTS vivero CASCADE;

-- =============================================================================
-- 3. CREACIÓN DE TABLAS CON RESTRICCIONES (DDL)
-- =============================================================================

-- TABLA: VIVERO
CREATE TABLE vivero (
    id_vivero SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    localidad VARCHAR(100) NOT NULL
);

-- TABLA: ZONA
CREATE TABLE zona (
    id_zona SERIAL PRIMARY KEY,
    id_vivero INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    tipo VARCHAR(50) NOT NULL,
    latitud NUMERIC(9,6) CHECK (latitud BETWEEN -90 AND 90),
    longitud NUMERIC(9,6) CHECK (longitud BETWEEN -180 AND 180),
    FOREIGN KEY (id_vivero) REFERENCES vivero(id_vivero) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- TABLA: PRODUCTO
CREATE TABLE producto (
    id_producto SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario > 0),
    categoria VARCHAR(50) NOT NULL
);

-- TABLA: ALMACENA (Relación M:N entre Zona y Producto)
CREATE TABLE almacena (
    id_zona INT NOT NULL,
    id_producto INT NOT NULL,
    stock_en_zona INT NOT NULL CHECK (stock_en_zona >= 0),
    PRIMARY KEY (id_zona, id_producto),
    FOREIGN KEY (id_zona) REFERENCES zona(id_zona) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (id_producto) REFERENCES producto(id_producto) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- TABLA: EMPLEADO
CREATE TABLE empleado (
    id_empleado SERIAL PRIMARY KEY,
    dni VARCHAR(9) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(15),
    sueldo NUMERIC(10,2) CHECK (sueldo >= 0)
);

-- TABLA: PUESTO
CREATE TABLE puesto (
    id_puesto SERIAL PRIMARY KEY,
    id_empleado INT NOT NULL,
    id_zona INT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,
    CONSTRAINT chk_fechas_puesto CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    FOREIGN KEY (id_empleado) REFERENCES empleado(id_empleado) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (id_zona) REFERENCES zona(id_zona) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- TABLA: TAREA
CREATE TABLE tarea (
    id_tarea SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT
);

-- TABLA INTERMEDIA: PUESTO_TAREA (Relación M:N entre Puesto y Tarea)
CREATE TABLE puesto_tarea (
    id_puesto INT NOT NULL,
    id_tarea INT NOT NULL,
    PRIMARY KEY (id_puesto, id_tarea),
    FOREIGN KEY (id_puesto) REFERENCES puesto(id_puesto) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (id_tarea) REFERENCES tarea(id_tarea) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- TABLA: OBJETIVO_VENTA
CREATE TABLE objetivo_venta (
    id_objetivo SERIAL PRIMARY KEY,
    id_empleado INT NOT NULL,
    descripcion VARCHAR(200),
    fecha DATE NOT NULL,
    importe_objetivo NUMERIC(10,2) NOT NULL CHECK (importe_objetivo >= 0),
    FOREIGN KEY (id_empleado) REFERENCES empleado(id_empleado) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- TABLA: CLIENTE
CREATE TABLE cliente (
    id_cliente SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    contacto VARCHAR(100)
);

-- TABLA: CLIENTE_PLUS (Especialización ISA de Cliente)
CREATE TABLE cliente_plus (
    id_cliente INT PRIMARY KEY,
    fecha_ingreso DATE NOT NULL DEFAULT CURRENT_DATE,
    FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- TABLA: BONIFICACION_MENSUAL
CREATE TABLE bonificacion_mensual (
    id_bonificacion SERIAL PRIMARY KEY,
    id_cliente_plus INT NOT NULL,
    periodo DATE NOT NULL,
    importe_bonificacion NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (importe_bonificacion >= 0),
    FOREIGN KEY (id_cliente_plus) REFERENCES cliente_plus(id_cliente) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- TABLA: PEDIDO
CREATE TABLE pedido (
    id_pedido SERIAL PRIMARY KEY,
    id_cliente INT,
    id_puesto INT,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) 
        ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (id_puesto) REFERENCES puesto(id_puesto) 
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- TABLA: DETALLE_PEDIDO (Relación INCLUYE entre Pedido y Producto)
CREATE TABLE detalle_pedido (
    id_pedido INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_momento NUMERIC(10,2) NOT NULL CHECK (precio_momento > 0),
    PRIMARY KEY (id_pedido, id_producto),
    FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (id_producto) REFERENCES producto(id_producto) 
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- =============================================================================
-- 4. MANEJO DE ATRIBUTOS DERIVADOS (VISTAS SQL)
-- =============================================================================

-- A) Atributo derivado 'total' en PEDIDO
CREATE OR REPLACE VIEW vista_pedidos_con_total AS
SELECT 
    p.id_pedido,
    p.id_cliente,
    p.id_puesto,
    p.fecha,
    COALESCE(SUM(dp.cantidad * dp.precio_momento), 0.00) AS total
FROM pedido p
LEFT JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
GROUP BY p.id_pedido, p.id_cliente, p.id_puesto, p.fecha;

-- B) Atributo derivado 'volumen_compras' en BONIFICACION_MENSUAL
CREATE OR REPLACE VIEW vista_bonificaciones_completas AS
SELECT 
    bm.id_bonificacion,
    bm.id_cliente_plus,
    bm.periodo,
    bm.importe_bonificacion,
    COALESCE(SUM(dp.cantidad * dp.precio_momento), 0.00) AS volumen_compras
FROM bonificacion_mensual bm
JOIN cliente_plus cp ON bm.id_cliente_plus = cp.id_cliente
LEFT JOIN pedido p ON p.id_cliente = cp.id_cliente 
    AND DATE_TRUNC('month', p.fecha) = DATE_TRUNC('month', bm.periodo)
    AND p.fecha >= cp.fecha_ingreso
LEFT JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
GROUP BY bm.id_bonificacion, bm.id_cliente_plus, bm.periodo, bm.importe_bonificacion;

-- =============================================================================
-- 5. POBLADO DE DATOS (AL MENOS 5 FILAS POR TABLA)
-- =============================================================================

-- VIVERO (5 filas)
INSERT INTO vivero (nombre, localidad) VALUES
('Tajinaste Norte', 'La Orotava'),
('Tajinaste Sur', 'Arona'),
('Tajinaste Anaga', 'Santa Cruz de Tenerife'),
('Tajinaste Laguna', 'San Cristóbal de La Laguna'),
('Tajinaste Palmeras', 'Los Llanos de Aridane');

-- ZONA (5 filas)
INSERT INTO zona (id_vivero, nombre, tipo, latitud, longitud) VALUES
(1, 'Invernadero A', 'Interior', 28.390123, -16.521098),
(1, 'Jardín Exterior', 'Exterior', 28.390500, -16.521500),
(2, 'Zona Cactus', 'Exterior', 28.099120, -16.678900),
(3, 'Sección Orquídeas', 'Invernadero', 28.468100, -16.254300),
(4, 'Herramientas y Abonos', 'Almacén', 28.487200, -16.315800);

-- PRODUCTO (5 filas)
INSERT INTO producto (nombre, precio_unitario, categoria) VALUES
('Orquídea Phalaenopsis', 14.50, 'Planta de Interior'),
('Cactus Asiento de Suegra', 8.20, 'Cactus y Suculentas'),
('Rosal Silvestre', 12.00, 'Planta de Exterior'),
('Sustrato Universal 20L', 6.50, 'Abonos y Tierras'),
('Regadera Plástica 5L', 4.99, 'Accesorios');

-- ALMACENA (5 filas)
INSERT INTO almacena (id_zona, id_producto, stock_en_zona) VALUES
(1, 1, 45),
(2, 3, 30),
(3, 2, 100),
(4, 1, 20),
(5, 4, 200);

-- EMPLEADO (5 filas)
INSERT INTO empleado (dni, nombre, telefono, sueldo) VALUES
('12345678A', 'Carlos Mendoza', '600111222', 1550.00),
('23456789B', 'María Hernández', '600222333', 1620.50),
('34567890C', 'Juan Pérez', '600333444', 1400.00),
('45678901D', 'Laura Gómez', '600444555', 1800.00),
('56789012E', 'Pedro Rodríguez', '600555666', 1500.00);

-- PUESTO (5 filas)
INSERT INTO puesto (id_empleado, id_zona, fecha_inicio, fecha_fin) VALUES
(1, 1, '2025-01-10', NULL),
(2, 2, '2025-02-01', NULL),
(3, 3, '2024-06-15', '2025-01-01'),
(4, 4, '2025-03-01', NULL),
(5, 5, '2025-01-15', NULL);

-- TAREA (5 filas)
INSERT INTO tarea (nombre, descripcion) VALUES
('Riego por goteo', 'Revisar y programar el sistema de riego automático'),
('Poda de formación', 'Controlar crecimiento de rosales y arbustos'),
('Cobro en caja', 'Atender ventas directa a clientes en el vivero'),
('Reposición de stock', 'Colocar sacos de tierra y abonos en estanterías'),
('Control de plagas', 'Aplicar tratamiento fitosanitario mensual');

-- PUESTO_TAREA (5 filas)
INSERT INTO puesto_tarea (id_puesto, id_tarea) VALUES
(1, 1),
(1, 5),
(2, 2),
(3, 3),
(4, 4);

-- OBJETIVO_VENTA (5 filas)
INSERT INTO objetivo_venta (id_empleado, descripcion, fecha, importe_objetivo) VALUES
(1, 'Superar ventas de orquídeas en San Valentín', '2026-02-14', 2500.00),
(2, 'Promoción de primavera en plantas exteriores', '2026-04-30', 4000.00),
(3, 'Campaña especial de suculentas', '2025-11-30', 1500.00),
(4, 'Venta de accesorios y herramientas de jardín', '2026-05-31', 3000.00),
(5, 'Liquidación de sustratos de temporada', '2026-06-30', 2000.00);

-- CLIENTE (5 filas)
INSERT INTO cliente (nombre, contacto) VALUES
('Elena Benítez', 'elena@email.com'),
('Javier Torres', '611999888'),
('Asociación de Jardinería Anaga', 'contacto@jardinanaga.org'),
('Isabel Morales', 'isabel.m@email.com'),
('Roberto Días', '622888777');

-- CLIENTE_PLUS (5 filas)
INSERT INTO cliente_plus (id_cliente, fecha_ingreso) VALUES
(1, '2025-01-15'),
(3, '2024-11-01'),
(4, '2025-03-10'),
(2, '2025-04-01'),
(5, '2025-05-20');

-- BONIFICACION_MENSUAL (5 filas)
INSERT INTO bonificacion_mensual (id_cliente_plus, periodo, importe_bonificacion) VALUES
(1, '2026-05-01', 15.00),
(3, '2026-05-01', 50.00),
(4, '2026-05-01', 10.00),
(2, '2026-06-01', 5.00),
(5, '2026-06-01', 20.00);

-- PEDIDO (5 filas)
INSERT INTO pedido (id_cliente, id_puesto, fecha) VALUES
(1, 1, '2026-05-10 10:30:00'),
(2, 2, '2026-05-12 11:15:00'),
(3, 4, '2026-05-15 16:45:00'),
(4, 1, '2026-05-18 09:20:00'),
(5, 5, '2026-06-02 12:00:00');

-- DETALLE_PEDIDO (5 filas)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_momento) VALUES
(1, 1, 2, 14.50), -- 2 Orquídeas
(1, 4, 1, 6.50),  -- 1 Sustrato
(2, 2, 5, 8.20),  -- 5 Cactus
(3, 4, 10, 6.50), -- 10 Sustratos
(4, 3, 3, 12.00); -- 3 Rosales

-- =============================================================================
-- 6. DEMOSTRACIÓN DE OPERACIONES DELETE (INTEGRIDAD REFERENCIAL)
-- =============================================================================

-- Ejemplo 1: Borrado de un Vivero (Eliminación en Cascada)
-- Al borrar el vivero 'Tajinaste Norte' (id_vivero = 1), se borrarán automáticamente 
-- sus Zonas asociadas en la tabla 'zona', y en cascada sus asignaciones en 'almacena' y 'puesto'.
DELETE FROM vivero WHERE id_vivero = 1;

-- Ejemplo 2: Borrado de un Cliente (Preservación del Historial de Pedidos)
-- Al borrar al cliente con id_cliente = 2, las tablas 'cliente_plus' y 'bonificacion_mensual' 
-- se borrarán en cascada. Sin embargo, en la tabla 'pedido', id_cliente pasará a NULL 
-- (gracias a ON DELETE SET NULL) para conservar las métricas de venta históricas.
DELETE FROM cliente WHERE id_cliente = 2;

-- Ejemplo 3: Borrado de un Producto
-- Al intentar borrar un producto con pedidos vinculados (id_producto = 4), 
-- la restricción ON DELETE RESTRICT en 'detalle_pedido' evitará inconsistencias financieras.
-- Primero borramos un producto no pedido (id_producto = 5) para demostrar borrado correcto:
DELETE FROM producto WHERE id_producto = 5;

-- =============================================================================
-- 7. CONSULTAS SELECT DE COMPROBACIÓN
-- =============================================================================
SELECT * FROM vivero;
SELECT * FROM zona;
SELECT * FROM producto;
SELECT * FROM almacena;
SELECT * FROM empleado;
SELECT * FROM puesto;
SELECT * FROM tarea;
SELECT * FROM puesto_tarea;
SELECT * FROM objetivo_venta;
SELECT * FROM cliente;
SELECT * FROM cliente_plus;
SELECT * FROM bonificacion_mensual;
SELECT * FROM pedido;
SELECT * FROM detalle_pedido;

-- Comprobar los atributos derivados calculados mediante las vistas:
SELECT * FROM vista_pedidos_con_total;
SELECT * FROM vista_bonificaciones_completas;