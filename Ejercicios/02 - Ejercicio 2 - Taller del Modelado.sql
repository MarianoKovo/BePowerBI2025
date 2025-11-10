
-- ==============================================================
-- Workshop Dataset: AdventureWorks2022 OLTP - Modelo Estrella Optimizado (Final)
-- Autor: Mariano Kovo Microsoft MVP 
-- Taller de Modelado y Optimización
-- ==============================================================
-- =============================================================
-- EJERCICIO NUMERO 2 - ANALISIS DE PERFORMANCE CON INDICES 
-- Pre-requisito: Ejercicio 1 completo
-- Se crearán indices sobre tabla Sales
-- =============================================================


-- =============================================================
-- Seteo de Ambiente
-- =============================================================

USE AdventureWorks2022;
GO
CHECKPOINT;
DBCC DROPCLEANBUFFERS;
DBCC FREEPROCCACHE;
GO


-- =============================================================
-- Eliminar índices previos del taller (solo si existen)
-- =============================================================

-- Eliminar el índice clustered actual y otros
ALTER TABLE fact.Sales DROP CONSTRAINT PK_Sales;
DROP INDEX IF EXISTS CIX_Sales_OrderDate_Customer ON fact.Sales;
DROP INDEX IF EXISTS NIX_Sales_OrderDate_Product ON fact.Sales;


-- =============================================================
-- 🧱 1 Escenario Base 
-- Ejecutar una consulta analítica típica sin índices adicionales
-- Como resultado esperado vamos a obtener las ventas y cantidades 
-- totales por Región y Categoría ordenado por el Importe de Ventas
-- en forma descendente.
-- Activar opciones de Client Statistics y Plan de Ejecución Actual
-- =============================================================


SET STATISTICS IO, TIME ON;
GO

SELECT 
    p.Category,
    p.Subcategory,
    SUM(f.SalesAmount) AS TotalVentas,
    COUNT(*) AS CantidadVentas
FROM fact.Sales AS f
JOIN dim.Product AS p ON f.ProductID = p.ProductID
WHERE f.OrderDateKey BETWEEN 20100101 AND 20201231
GROUP BY p.Category, p.Subcategory
ORDER BY TotalVentas DESC;
GO

SET STATISTICS IO, TIME OFF;


/*
⏱ Medir tiempo y lecturas en la ventana de mensajes.
💬 Ver como SQL Server realiza un Table Scan sobre fact.Sales.
*/

-- =============================================================
-- ⚙️ 2️ Agregar un Índice Clustered
-- 
-- Por defecto fact.Sales tiene PK en SalesOrderDetailID (clustered).
-- Aquí simularemos un escenario donde se requiere acceso rápido por OrderDateKey y CustomerID.
-- DBCC FREEPROCCACHE()
-- =============================================================

CREATE CLUSTERED INDEX CIX_Sales_OrderDate_Customer
ON fact.Sales (OrderDateKey, CustomerID);
GO


/*
Volver a ejecutar la misma consulta anterior.

👉 Observar en el Execution Plan:

Cómo desaparecen los table scans.

Se reemplazan por clustered index seeks.

📈 Medir la reducción en lecturas lógicas y tiempo de CPU.
*/



-- =============================================================
-- 3 Crear un índice Non-Clustered para optimización dirigida
-- =============================================================

CREATE NONCLUSTERED INDEX NIX_Sales_OrderDate_Product
ON fact.Sales (OrderDateKey, ProductID)
INCLUDE (SalesAmount, OrderQty);
GO


/*
Volver a ejecutar la misma consulta anterior.

👉 Observar en el Execution Plan:

📈 Medir la reducción en lecturas lógicas y tiempo de CPU.
*/


/*-----------------------------------
-- 4 Limpieza
------------------------------------*/
DROP INDEX IF EXISTS CIX_Sales_OrderDate_Customer ON fact.Sales;
DROP INDEX IF EXISTS NIX_Sales_OrderDate_Product ON fact.Sales;

/* Reestablecer PK sobre fact.Sales */

ALTER TABLE fact.Sales ADD CONSTRAINT PK_Sales PRIMARY KEY (SalesOrderDetailID);
GO




-- =============================================================
-- 🧹 CLEAN UP SECTION
-- =============================================================
IF OBJECT_ID('fact.Sales') IS NOT NULL
BEGIN
    ALTER TABLE fact.Sales DROP CONSTRAINT IF EXISTS FK_Sales_Date;
    ALTER TABLE fact.Sales DROP CONSTRAINT IF EXISTS FK_Sales_Customer;
    ALTER TABLE fact.Sales DROP CONSTRAINT IF EXISTS FK_Sales_Product;
    ALTER TABLE fact.Sales DROP CONSTRAINT IF EXISTS FK_Sales_Territory;
END
GO

DROP TABLE IF EXISTS fact.Sales;
DROP TABLE IF EXISTS dim.Date;
DROP TABLE IF EXISTS dim.Customer;
DROP TABLE IF EXISTS dim.Product;
DROP TABLE IF EXISTS dim.SalesTerritory;
GO

DROP SCHEMA IF EXISTS fact;
DROP SCHEMA IF EXISTS dim;
GO

PRINT('🧼 Limpieza completada. Base AdventureWorks2022 restaurada.');

