
-- ==============================================================
-- Workshop Dataset: AdventureWorks2022 OLTP - Modelo Estrella Optimizado (Final)
-- Autor: Mariano Kovo Microsoft MVP 
-- Taller de Modelado y Optimización
-- ==============================================================
-- EJERCICIO NUMERO 1 - CREACION DE MODELO 
-- Pre-requisito: Restore de Base de Datos AdventureWorks2022
-- Se creará un modelo Estrella que incluye :
--      - Esquemas DIM y FAC
--      - Tablas de Dimensiones (Date,Customer,Product,SalesTerritory)
--      - Tabla de Hechos (Sales)
-- =============================================================

USE AdventureWorks2022;
GO

-- ==============================================================
-- CREAR ESQUEMAS DE TRABAJO
-- ==============================================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dim')
    EXEC('CREATE SCHEMA dim');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'fact')
    EXEC('CREATE SCHEMA fact');
GO




-- =============================================================
-- TABLA: dim.Date (rango dinámico y generación robusta)
-- =============================================================
IF OBJECT_ID('dim.Date') IS NOT NULL DROP TABLE dim.Date;
GO

CREATE TABLE dim.Date (
    DateKey INT NOT NULL PRIMARY KEY,
    FullDate DATE NOT NULL,
    Year INT NOT NULL,
    Month INT NOT NULL,
    MonthName NVARCHAR(20) NOT NULL,
    Quarter INT NOT NULL
);
GO

DECLARE @MinDate DATE, @MaxDate DATE, @Start DATE, @End DATE;

SELECT 
    @MinDate = MIN(OrderDate),
    @MaxDate = MAX(OrderDate)
FROM Sales.SalesOrderHeaderEnlarged;

-- Margen de +- 1 año
SET @Start = DATEADD(YEAR, -1, @MinDate);
SET @End   = DATEADD(YEAR,  1, @MaxDate);

;WITH d AS (
    SELECT @Start AS FullDate
    UNION ALL
    SELECT DATEADD(DAY, 1, FullDate)
    FROM d
    WHERE FullDate < @End
)
INSERT INTO dim.Date (DateKey, FullDate, Year, Month, MonthName, Quarter)
SELECT 
    CONVERT(INT, FORMAT(FullDate, 'yyyyMMdd')) AS DateKey,
    FullDate,
    YEAR(FullDate),
    MONTH(FullDate),
    DATENAME(MONTH, FullDate),
    DATEPART(QUARTER, FullDate)
FROM d
OPTION (MAXRECURSION 0);  --El hint MAXRECURSION limita el numero de iteraciones recursivas de una consulta para una CTE
GO


-- ==============================================================
-- TABLA: dim.Customer
-- ==============================================================

IF OBJECT_ID('dim.Customer') IS NOT NULL DROP TABLE dim.Customer;
GO

WITH EmailCTE AS (
    SELECT 
        ea.BusinessEntityID,
        ea.EmailAddress,
        ROW_NUMBER() OVER (PARTITION BY ea.BusinessEntityID ORDER BY ea.EmailAddress) AS rn  
    FROM Person.EmailAddress AS ea
),
PhoneCTE AS (
    SELECT 
        ph.BusinessEntityID,
        ph.PhoneNumber,
        ROW_NUMBER() OVER (PARTITION BY ph.BusinessEntityID ORDER BY ph.PhoneNumber) AS rn
    FROM Person.PersonPhone AS ph
),
AddressCTE AS (
    SELECT 
        bea.BusinessEntityID,
        a.City,
        sp.Name AS StateProvince,
        cr.Name AS CountryRegion,
        ROW_NUMBER() OVER (PARTITION BY bea.BusinessEntityID ORDER BY a.AddressID) AS rn
    FROM Person.BusinessEntityAddress AS bea
    JOIN Person.Address AS a ON bea.AddressID = a.AddressID
    JOIN Person.StateProvince AS sp ON a.StateProvinceID = sp.StateProvinceID
    JOIN Person.CountryRegion AS cr ON sp.CountryRegionCode = cr.CountryRegionCode
)
SELECT 
    c.CustomerID,
    p.FirstName,
    p.LastName,
    ISNULL(e.EmailAddress, 'N/A') AS EmailAddress,
    ISNULL(ph.PhoneNumber, 'N/A') AS PhoneNumber,
    ISNULL(a.City, '') AS City,
    ISNULL(a.StateProvince, 'N/A') AS StateProvince,
    ISNULL(a.CountryRegion, 'N/A') AS CountryRegion
INTO dim.Customer
FROM Sales.Customer AS c
JOIN Person.Person AS p 
    ON c.PersonID = p.BusinessEntityID
LEFT JOIN EmailCTE AS e 
    ON p.BusinessEntityID = e.BusinessEntityID AND e.rn = 1
LEFT JOIN PhoneCTE AS ph 
    ON p.BusinessEntityID = ph.BusinessEntityID AND ph.rn = 1
LEFT JOIN AddressCTE AS a 
    ON p.BusinessEntityID = a.BusinessEntityID AND a.rn = 1;
GO

ALTER TABLE dim.Customer
ADD CONSTRAINT PK_Customer PRIMARY KEY (CustomerID);
GO
-- ==============================================================
-- TABLA: dim.Product
-- ==============================================================
IF OBJECT_ID('dim.Product') IS NOT NULL DROP TABLE dim.Product;
GO

SELECT DISTINCT
    p.ProductID,
    p.Name AS ProductName,
    p.ProductNumber,
    ISNULL(p.Color, 'N/A') AS Color,
    ISNULL(p.Size, 'N/A') AS Size,
    ISNULL(p.StandardCost, 0) AS StandardCost,
    ISNULL(p.ListPrice, 0) AS ListPrice,
    ISNULL(ps.Name, 'Sin Subcategoría') AS Subcategory,
    ISNULL(pc.Name, 'Sin Categoría') AS Category
INTO dim.Product
FROM Production.Product AS p
LEFT JOIN Production.ProductSubcategory AS ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN Production.ProductCategory AS pc ON ps.ProductCategoryID = pc.ProductCategoryID;
GO




ALTER TABLE dim.Product
ADD CONSTRAINT PK_Product PRIMARY KEY (ProductID);
GO

-- ==============================================================
-- TABLA: dim.SalesTerritory
-- ==============================================================
IF OBJECT_ID('dim.SalesTerritory') IS NOT NULL DROP TABLE dim.SalesTerritory;
GO

SELECT DISTINCT
    st.TerritoryID,
    st.Name AS TerritoryName,
    st.[Group] AS TerritoryGroup,
    st.CountryRegionCode
INTO dim.SalesTerritory
FROM Sales.SalesTerritory AS st;
GO

ALTER TABLE dim.SalesTerritory
ADD CONSTRAINT PK_SalesTerritory PRIMARY KEY (TerritoryID);
GO

-- ==============================================================
-- TABLA: fact.Sales
-- ==============================================================
IF OBJECT_ID('fact.Sales') IS NOT NULL DROP TABLE fact.Sales;
GO

SELECT 
    soh.SalesOrderID,
    sod.SalesOrderDetailID,
    CONVERT(INT, FORMAT(soh.OrderDate, 'yyyyMMdd')) AS OrderDateKey,
    soh.CustomerID,
    soh.TerritoryID,
    sod.ProductID,
    sod.OrderQty,
    sod.UnitPrice,
    sod.UnitPriceDiscount,
    CAST((sod.OrderQty * sod.UnitPrice) AS DECIMAL(18,2)) AS ExtendedAmount,
    CAST((sod.OrderQty * sod.UnitPrice * (1 - sod.UnitPriceDiscount)) AS DECIMAL(18,2)) AS SalesAmount
INTO fact.Sales
FROM Sales.SalesOrderHeaderEnlarged AS soh
JOIN Sales.SalesOrderDetailEnlarged AS sod ON soh.SalesOrderID = sod.SalesOrderID;
GO

/* Alternativa para crear Primary Key
ALTER TABLE fact.Sales
ADD CONSTRAINT PK_Sales PRIMARY KEY (SalesOrderDetailID);
GO
*/

-- ==============================================================
-- CREAR FOREIGN KEYS
-- ==============================================================
ALTER TABLE fact.Sales ADD CONSTRAINT FK_Sales_Date
    FOREIGN KEY (OrderDateKey) REFERENCES dim.Date(DateKey);

ALTER TABLE fact.Sales ADD CONSTRAINT FK_Sales_Customer
    FOREIGN KEY (CustomerID) REFERENCES dim.Customer(CustomerID);

ALTER TABLE fact.Sales ADD CONSTRAINT FK_Sales_Product
    FOREIGN KEY (ProductID) REFERENCES dim.Product(ProductID);

ALTER TABLE fact.Sales ADD CONSTRAINT FK_Sales_Territory
    FOREIGN KEY (TerritoryID) REFERENCES dim.SalesTerritory(TerritoryID);
GO

PRINT('✅ Modelo estrella AdventureWorks2022 creado correctamente.');
PRINT('   Dimensiones y hechos con PK/FK válidas.');
GO


-- ==============================================================
-- LIMPIEZA (opcional al final del taller)
-- ==============================================================
-- Ejecútalo solo si querés restaurar AdventureWorks2022 a su estado original.
-- Elimina todas las tablas y esquemas creados por el workshop.

-- 1️ Eliminar FKs
IF OBJECT_ID('fact.Sales') IS NOT NULL
BEGIN
    ALTER TABLE fact.Sales DROP CONSTRAINT IF EXISTS FK_Sales_Date;
    ALTER TABLE fact.Sales DROP CONSTRAINT IF EXISTS FK_Sales_Customer;
    ALTER TABLE fact.Sales DROP CONSTRAINT IF EXISTS FK_Sales_Product;
    ALTER TABLE fact.Sales DROP CONSTRAINT IF EXISTS FK_Sales_Territory;
END
GO

--2  Eliminar tablas de hechos y dimensiones
DROP TABLE IF EXISTS fact.Sales;
DROP TABLE IF EXISTS dim.Date;
DROP TABLE IF EXISTS dim.Customer;
DROP TABLE IF EXISTS dim.Product;
DROP TABLE IF EXISTS dim.SalesTerritory;
GO

--3 Eliminar esquemas (solo si no tienen objetos)
DROP SCHEMA IF EXISTS fact;
DROP SCHEMA IF EXISTS dim;
GO

PRINT('Limpieza completada. Base AdventureWorks2022 restaurada.');




