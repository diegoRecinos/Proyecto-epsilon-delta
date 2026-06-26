USE AdventureWorks2022; 
GO

--------------------
--Modelo dimensional
--------------------
---------------
--DIEGO RECINOS
---------------

-- 1. dimension SalesTerritory
SELECT 
    TerritoryID,
    Name AS Region,
    CountryRegionCode AS CountryRegion,
    [Group]
FROM Sales.SalesTerritory;

-- 2. dimension Customer 
SELECT 
    'AW' + RIGHT('00000000' + CAST(c.CustomerID AS VARCHAR(10)), 8) AS CustomerID,
    CONCAT(p.FirstName, ' ', p.MiddleName + ' ', p.LastName) AS Customer,
    a.City,
    sp.Name AS StateProvince,
    cr.Name AS CountryRegion,
    a.PostalCode
FROM Sales.Customer c
INNER JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
INNER JOIN Person.BusinessEntityAddress bea ON p.BusinessEntityID = bea.BusinessEntityID
INNER JOIN Person.Address a ON bea.AddressID = a.AddressID
INNER JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
INNER JOIN Person.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode;

-----------------
--ANDRE CALIDONIO 
-----------------

--3.dimension product
SELECT 
    ROW_NUMBER() OVER (ORDER BY p.ProductID, COALESCE(ch.StartDate, '1900-01-01')) + 209 AS ProductKey,
    p.ProductNumber AS SKU,
    p.Name AS Product,
    COALESCE(ch.StandardCost, p.StandardCost) AS StandardCost,
    p.Color,
    COALESCE(ph.ListPrice, p.ListPrice) AS ListPrice,
    pm.Name AS Model,
    ps.Name AS Subcategory,
    pc.Name AS Category
FROM Production.Product p
LEFT JOIN Production.ProductCostHistory ch ON p.ProductID = ch.ProductID
LEFT JOIN Production.ProductListPriceHistory ph ON p.ProductID = ph.ProductID AND (ch.StartDate = ph.StartDate OR (ch.StartDate IS NULL AND ph.StartDate IS NULL))
LEFT JOIN Production.ProductModel pm ON p.ProductModelID = pm.ProductModelID
LEFT JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
WHERE ps.Name IS NOT NULL;

---------------
--MARCELO REYES
---------------

--4. Tabla de hechos Fact Sales
SELECT
    sod.SalesOrderDetailID AS SalesOrderLineKey,
    c.CustomerID AS ResellerKey,
    c.CustomerID AS CustomerKey,
    p.ProductID AS ProductKey,

    CONVERT(INT, CONVERT(VARCHAR(8), soh.OrderDate, 112)) AS OrderDateKey,
    CONVERT(INT, CONVERT(VARCHAR(8), soh.DueDate, 112)) AS DueDateKey,
    CONVERT(INT, CONVERT(VARCHAR(8), soh.ShipDate, 112)) AS ShipDateKey,

    st.TerritoryID AS SalesTerritoryKey,

    sod.OrderQty AS OrderQuantity,
    sod.UnitPrice,
    sod.LineTotal AS ExtendedAmount,
    sod.UnitPriceDiscount AS UnitPriceDiscountPct,
    p.StandardCost AS ProductStandardCost,
    p.StandardCost * sod.OrderQty AS TotalProductCost,
    sod.LineTotal AS SalesAmount

FROM Sales.SalesOrderHeader soh
INNER JOIN Sales.SalesOrderDetail sod
    ON soh.SalesOrderID = sod.SalesOrderID
INNER JOIN Production.Product p
    ON sod.ProductID = p.ProductID
INNER JOIN Sales.Customer c
    ON soh.CustomerID = c.CustomerID
INNER JOIN Sales.SalesTerritory st
    ON soh.TerritoryID = st.TerritoryID;

-- 5. Dimensión Reseller
SELECT
    s.BusinessEntityID AS ResellerKey,
    s.BusinessEntityID AS ResellerID,
    'Reseller' AS BusinessType,
    s.Name AS Reseller,
    a.City,
    sp.Name AS StateProvince,
    cr.Name AS CountryRegion,
    a.PostalCode
FROM Sales.Store s
INNER JOIN Person.BusinessEntityAddress bea
    ON s.BusinessEntityID = bea.BusinessEntityID
INNER JOIN Person.Address a
    ON bea.AddressID = a.AddressID
INNER JOIN Person.StateProvince sp
    ON a.StateProvinceID = sp.StateProvinceID
INNER JOIN Person.CountryRegion cr
    ON sp.CountryRegionCode = cr.CountryRegionCode;



---------------------------------
-- Querys consultas y analisis
---------------------------------

---------------
--DIEGO RECINOS
---------------

--1a. ¿En qué mes se produjo más ventas (total de la venta) por año?
WITH VentasPorMesAno AS (
    SELECT 
        YEAR(soh.OrderDate) AS Anio,
        MONTH(soh.OrderDate) AS MesNumero,
        DATENAME(MONTH, soh.OrderDate) AS MesNombre,
        ROUND(SUM(sod.LineTotal), 2) AS VentasTotales,
        ROW_NUMBER() OVER (PARTITION BY YEAR(soh.OrderDate) ORDER BY SUM(sod.LineTotal) DESC) AS Ranking
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate), DATENAME(MONTH, soh.OrderDate)
)
SELECT 
    Anio,
    MesNombre AS MesMasVendido,
    VentasTotales
FROM VentasPorMesAno
WHERE Ranking = 1
ORDER BY Anio DESC;
GO

--2b. ¿Año con más ventas totales?

SELECT TOP 1
    YEAR(soh.OrderDate) AS Anio,
    ROUND(SUM(sod.LineTotal), 2) AS VentasTotales
FROM Sales.SalesOrderHeader soh
INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
GROUP BY YEAR(soh.OrderDate)
ORDER BY VentasTotales DESC;
GO

--10j.(extra) ¿Canal de Distribución con mas ventas?
SELECT 
    CASE 
        WHEN soh.OnlineOrderFlag = 0 THEN 'Reseller (B2B / Distribuidores)'
        ELSE 'Internet (B2C / Venta Directa)'
    END AS CanalDistribucion,
    ROUND(SUM(sod.LineTotal), 2) AS VentasTotales,
    SUM(sod.OrderQty) AS UnidadesVendidas
FROM Sales.SalesOrderHeader soh
INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
GROUP BY soh.OnlineOrderFlag
ORDER BY VentasTotales DESC;
GO

--11k.(extra) ¿La categoría de productos que retiene el mayor porcentaje de margen de ganancia?
SELECT 
    pc.Name AS CategoriaProducto,
    ROUND(SUM(sod.LineTotal), 2) AS VentasTotales,
    ROUND(SUM(sod.LineTotal) - SUM(COALESCE(ch.StandardCost, p.StandardCost) * sod.OrderQty), 2) AS GananciaNeta,
    ROUND(((SUM(sod.LineTotal) - SUM(COALESCE(ch.StandardCost, p.StandardCost) * sod.OrderQty)) / NULLIF(SUM(sod.LineTotal), 0)) * 100, 2) AS PorcentajeMargenGanancia
FROM Sales.SalesOrderDetail sod
INNER JOIN Sales.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
INNER JOIN Production.Product p ON sod.ProductID = p.ProductID
INNER JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
INNER JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
LEFT JOIN Production.ProductCostHistory ch ON p.ProductID = ch.ProductID 
    AND soh.OrderDate >= ch.StartDate 
    AND soh.OrderDate <= COALESCE(ch.EndDate, '9999-12-31')
GROUP BY pc.Name
ORDER BY PorcentajeMargenGanancia DESC;
GO

--12l.(extra) ¿Que categoria genera mas ventas ? 
SELECT TOP 1
    pc.Name AS CategoriaMasVendida,
    ROUND(SUM(sod.LineTotal), 2) AS VentasTotales,
    SUM(sod.OrderQty) AS UnidadesVendidas
FROM Sales.SalesOrderDetail sod
INNER JOIN Production.Product p ON sod.ProductID = p.ProductID
INNER JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
INNER JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
GROUP BY pc.Name
ORDER BY VentasTotales DESC;
GO

------------------
--ANDRE CALIDONIO
------------------

USE AdventureWorks2022;
GO
-- 3c. ¿Top 3 de países con más ventas?
SELECT TOP 3
    cr.Name AS Pais,
    ROUND(SUM(sod.LineTotal), 2) AS VentasTotales,
    SUM(sod.OrderQty) AS UnidadesVendidas
FROM Sales.SalesOrderHeader soh
INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
INNER JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
INNER JOIN Person.CountryRegion cr ON st.CountryRegionCode = cr.CountryRegionCode
GROUP BY 
    cr.Name
ORDER BY 
    VentasTotales DESC;
GO

-- 4d. ¿Top 5 de regiones con menos ventas?
SELECT TOP 5
    st.Name AS Region,
    cr.Name AS Pais,
    ROUND(SUM(sod.LineTotal), 2) AS VentasTotales,
    SUM(sod.OrderQty) AS UnidadesVendidas
FROM Sales.SalesOrderHeader soh
INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
INNER JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
INNER JOIN Person.CountryRegion cr ON st.CountryRegionCode = cr.CountryRegionCode
GROUP BY 
    st.Name,
    cr.Name
ORDER BY 
    VentasTotales ASC;
GO

-- 13m. (extra) Rentabilidad y Margen de Ganancia Promedio por Categoría y Subcategoría
SELECT 
    pc.Name AS Categoria,
    ps.Name AS Subcategoria,
    ROUND(AVG(p.ListPrice), 2) AS PrecioListaPromedio,
    ROUND(AVG(p.StandardCost), 2) AS CostoEstandarPromedio,
    ROUND(AVG(p.ListPrice - p.StandardCost), 2) AS GananciaUnitariaPromedio,
    ROUND(AVG(p.ListPrice - p.StandardCost) / NULLIF(AVG(p.ListPrice), 0) * 100, 2) AS PorcentajeMargenPromedio
FROM Production.Product p
INNER JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
INNER JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
GROUP BY 
    pc.Name,
    ps.Name
ORDER BY 
    PorcentajeMargenPromedio DESC;
GO

-- 14n (extra) Top 10 Productos con Mayor Ganancia Neta Generada
SELECT TOP 10
    p.Name AS Producto,
    p.ProductNumber AS SKU,
    SUM(sod.OrderQty) AS UnidadesVendidas,
    ROUND(SUM(sod.LineTotal), 2) AS VentasTotales,
    ROUND(SUM(COALESCE(ch.StandardCost, p.StandardCost) * sod.OrderQty), 2) AS CostoTotal,
    ROUND(SUM(sod.LineTotal) - SUM(COALESCE(ch.StandardCost, p.StandardCost) * sod.OrderQty), 2) AS GananciaNeta,
    ROUND(((SUM(sod.LineTotal) - SUM(COALESCE(ch.StandardCost, p.StandardCost) * sod.OrderQty)) / NULLIF(SUM(sod.LineTotal), 0)) * 100, 2) AS [% Margen]
FROM Sales.SalesOrderDetail sod
INNER JOIN Sales.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
INNER JOIN Production.Product p ON sod.ProductID = p.ProductID
LEFT JOIN Production.ProductCostHistory ch ON p.ProductID = ch.ProductID 
    AND soh.OrderDate >= ch.StartDate 
    AND soh.OrderDate <= COALESCE(ch.EndDate, '9999-12-31')
GROUP BY 
    p.Name,
    p.ProductNumber
ORDER BY 
    GananciaNeta DESC;
GO

-- 15o (extra) Ventas y Cantidad de Unidades Vendidas según el Color de Producto
SELECT 
    COALESCE(p.Color, 'Sin Color / N/A') AS ColorProducto,
    SUM(sod.OrderQty) AS UnidadesVendidas,
    ROUND(SUM(sod.LineTotal), 2) AS VentasTotales,
    ROUND((SUM(sod.LineTotal) / (SELECT SUM(LineTotal) FROM Sales.SalesOrderDetail)) * 100, 2) AS PorcentajeDelTotal
FROM Sales.SalesOrderDetail sod
INNER JOIN Production.Product p ON sod.ProductID = p.ProductID
GROUP BY 
    p.Color
ORDER BY 
    VentasTotales DESC;
GO

---------------
--MARCELO REYES
---------------

-- 5e. Subcategoría donde se debe incrementar el inventario y su categoría
SELECT TOP 1
    ps.Name AS Subcategoria,
    pc.Name AS Categoria,
    SUM(sod.OrderQty) AS UnidadesVendidas,
    ROUND(SUM(sod.LineTotal), 2) AS TotalVentas
FROM Sales.SalesOrderDetail sod
INNER JOIN Production.Product p
    ON sod.ProductID = p.ProductID
INNER JOIN Production.ProductSubcategory ps
    ON p.ProductSubcategoryID = ps.ProductSubcategoryID
INNER JOIN Production.ProductCategory pc
    ON ps.ProductCategoryID = pc.ProductCategoryID
GROUP BY 
    ps.Name,
    pc.Name
ORDER BY 
    UnidadesVendidas DESC;

-- 6f. Los 10 productos menos vendidos
SELECT TOP 10
    p.ProductID,
    p.Name AS Producto,
    SUM(sod.OrderQty) AS UnidadesVendidas,
    ROUND(SUM(sod.LineTotal), 2) AS TotalVentas
FROM Sales.SalesOrderDetail sod
INNER JOIN Production.Product p
    ON sod.ProductID = p.ProductID
GROUP BY
    p.ProductID,
    p.Name
ORDER BY
    UnidadesVendidas ASC,
    TotalVentas ASC;

-- 7g. Método de pago más usado
SELECT
    CASE
        WHEN cc.CardType IS NULL THEN 'Sin tarjeta / Otro método'
        ELSE cc.CardType
    END AS MetodoPago,
    COUNT(soh.SalesOrderID) AS CantidadTransacciones
FROM Sales.SalesOrderHeader soh
LEFT JOIN Sales.CreditCard cc
    ON soh.CreditCardID = cc.CreditCardID
GROUP BY
    cc.CardType
ORDER BY
    CantidadTransacciones DESC;

-- 8h (extra). Top 10 resellers con mayores ventas
SELECT TOP 10
    s.BusinessEntityID AS ResellerID,
    s.Name AS Reseller,
    ROUND(SUM(sod.LineTotal), 2) AS TotalVentas,
    SUM(sod.OrderQty) AS UnidadesVendidas
FROM Sales.SalesOrderHeader soh
INNER JOIN Sales.SalesOrderDetail sod
    ON soh.SalesOrderID = sod.SalesOrderID
INNER JOIN Sales.Customer c
    ON soh.CustomerID = c.CustomerID
INNER JOIN Sales.Store s
    ON c.StoreID = s.BusinessEntityID
GROUP BY 
    s.BusinessEntityID,
    s.Name
ORDER BY 
    TotalVentas DESC;

-- 9i (extra). Ventas por país de reseller
SELECT
    cr.Name AS Pais,
    ROUND(SUM(sod.LineTotal), 2) AS TotalVentas,
    SUM(sod.OrderQty) AS UnidadesVendidas
FROM Sales.SalesOrderHeader soh
INNER JOIN Sales.SalesOrderDetail sod
    ON soh.SalesOrderID = sod.SalesOrderID
INNER JOIN Sales.Customer c
    ON soh.CustomerID = c.CustomerID
INNER JOIN Sales.Store s
    ON c.StoreID = s.BusinessEntityID
INNER JOIN Person.BusinessEntityAddress bea
    ON s.BusinessEntityID = bea.BusinessEntityID
INNER JOIN Person.Address a
    ON bea.AddressID = a.AddressID
INNER JOIN Person.StateProvince sp
    ON a.StateProvinceID = sp.StateProvinceID
INNER JOIN Person.CountryRegion cr
    ON sp.CountryRegionCode = cr.CountryRegionCode
GROUP BY 
    cr.Name
ORDER BY 
    TotalVentas DESC;