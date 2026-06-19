
USE AdventureWorks2022; 
GO


IF OBJECT_ID('dbo.Fact_Sales', 'U') IS NOT NULL DROP TABLE dbo.Fact_Sales;
IF OBJECT_ID('dbo.Dim_SalesOrder', 'U') IS NOT NULL DROP TABLE dbo.Dim_SalesOrder;
IF OBJECT_ID('dbo.Dim_Reseller', 'U') IS NOT NULL DROP TABLE dbo.Dim_Reseller;
IF OBJECT_ID('dbo.Dim_Product', 'U') IS NOT NULL DROP TABLE dbo.Dim_Product;
IF OBJECT_ID('dbo.Dim_Customer', 'U') IS NOT NULL DROP TABLE dbo.Dim_Customer;
IF OBJECT_ID('dbo.Dim_SalesTerritory', 'U') IS NOT NULL DROP TABLE dbo.Dim_SalesTerritory;
GO



-- CREACIÓN DE LAS TABLAS DEL MODELO 


-- 1. Dimensión Territorio de Ventas
CREATE TABLE Dim_SalesTerritory (
    SalesTerritoryKey INT IDENTITY(1,1),
    TerritoryID INT NOT NULL,
    Region VARCHAR(50) NOT NULL,
    CountryRegion VARCHAR(50) NOT NULL,
    [Group] VARCHAR(50) NOT NULL,
    CONSTRAINT PK_Dim_SalesTerritory PRIMARY KEY (SalesTerritoryKey)
);

-- 2. Dimensión Clientes
CREATE TABLE Dim_Customer (
    CustomerKey INT IDENTITY(1,1),
    CustomerID VARCHAR(15) NOT NULL,
    Customer VARCHAR(150) NOT NULL,
    City VARCHAR(60) NOT NULL,
    StateProvince VARCHAR(50) NOT NULL,
    CountryRegion VARCHAR(50) NOT NULL,
    PostalCode VARCHAR(15) NULL,
    CONSTRAINT PK_Dim_Customer PRIMARY KEY (CustomerKey)
);

-- 3. Dimensión Productos
CREATE TABLE Dim_Product (
    ProductKey INT IDENTITY(1,1),
    ProductID INT NOT NULL,
    ProductName VARCHAR(50) NOT NULL,
    ProductSubcategory VARCHAR(50) NOT NULL,
    ProductCategory VARCHAR(50) NOT NULL,
    Color VARCHAR(15) NULL,
    Size VARCHAR(5) NULL,
    CONSTRAINT PK_Dim_Product PRIMARY KEY (ProductKey)
);

-- 4. Dimensión Distribuidores (Reseller)
CREATE TABLE Dim_Reseller (
    ResellerKey INT IDENTITY(1,1),
    ResellerID VARCHAR(15) NOT NULL,
    ResellerName VARCHAR(100) NOT NULL,
    BusinessType VARCHAR(20) NOT NULL,
    City VARCHAR(60) NOT NULL,
    StateProvince VARCHAR(50) NOT NULL,
    CountryRegion VARCHAR(50) NOT NULL,
    CONSTRAINT PK_Dim_Reseller PRIMARY KEY (ResellerKey)
);

-- 5. Dimensión Órdenes de Venta (Sales Order)
CREATE TABLE Dim_SalesOrder (
    SalesOrderKey INT IDENTITY(1,1),
    SalesOrderNumber VARCHAR(20) NOT NULL,
    SalesOrderLineNumber INT NOT NULL,
    CONSTRAINT PK_Dim_SalesOrder PRIMARY KEY (SalesOrderKey)
);

-- 6. Tabla de Hechos: Ventas (SALES)
CREATE TABLE Fact_Sales (
    SalesKey INT IDENTITY(1,1),
    SalesOrderKey INT NOT NULL,
    CustomerKey INT NOT NULL,
    ProductKey INT NOT NULL,
    ResellerKey INT NOT NULL,
    SalesTerritoryKey INT NOT NULL,
    OrderDate DATE NOT NULL,
    OrderQty INT NOT NULL,
    UnitPrice MONEY NOT NULL,
    ExtendedAmount MONEY NOT NULL,
    ProductStandardCost MONEY NOT NULL,
    TotalProductCost MONEY NOT NULL,
    SalesAmount MONEY NOT NULL,
    CONSTRAINT PK_Fact_Sales PRIMARY KEY (SalesKey)
);
GO


--  POBLADO DE TABLAS

-- --- REGISTROS  EVITAR CONFLICTOS DE LLAVE FORÁNEA ---
-- Forzar inserción de llaves explícitas habilitando IDENTITY_INSERT

SET IDENTITY_INSERT Dim_Customer ON;
INSERT INTO Dim_Customer (CustomerKey, CustomerID, Customer, City, StateProvince, CountryRegion, PostalCode)
VALUES (-1, 'N/A', 'Venta Corporativa / Reseller', 'N/A', 'N/A', 'N/A', 'N/A');
SET IDENTITY_INSERT Dim_Customer OFF;

SET IDENTITY_INSERT Dim_Reseller ON;
INSERT INTO Dim_Reseller (ResellerKey, ResellerID, ResellerName, BusinessType, City, StateProvince, CountryRegion)
VALUES (-1, 'N/A', 'Venta Directa / Internet', 'N/A', 'N/A', 'N/A', 'N/A');
SET IDENTITY_INSERT Dim_Reseller OFF;


-- 1. Poblar Dim_SalesTerritory
INSERT INTO Dim_SalesTerritory (TerritoryID, Region, CountryRegion, [Group])
SELECT 
    TerritoryID,
    Name AS Region,
    CountryRegionCode AS CountryRegion,
    [Group]
FROM Sales.SalesTerritory;

-- 2. Poblar Dim_Customer (Clientes individuales)
INSERT INTO Dim_Customer (CustomerID, Customer, City, StateProvince, CountryRegion, PostalCode)
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


--CREACIÓN DE RELACIONES 

-- Hechos Ventas -> Dimensión Orden de Venta
ALTER TABLE Fact_Sales 
ADD CONSTRAINT FK_FactSales_DimSalesOrder 
FOREIGN KEY (SalesOrderKey) REFERENCES Dim_SalesOrder(SalesOrderKey);

-- Hechos Ventas -> Dimensión Clientes
ALTER TABLE Fact_Sales 
ADD CONSTRAINT FK_FactSales_DimCustomer 
FOREIGN KEY (CustomerKey) REFERENCES Dim_Customer(CustomerKey);

-- Hechos Ventas -> Dimensión Productos
ALTER TABLE Fact_Sales 
ADD CONSTRAINT FK_FactSales_DimProduct 
FOREIGN KEY (ProductKey) REFERENCES Dim_Product(ProductKey);

-- Hechos Ventas -> Dimensión Distribuidores (Reseller)
ALTER TABLE Fact_Sales 
ADD CONSTRAINT FK_FactSales_DimReseller 
FOREIGN KEY (ResellerKey) REFERENCES Dim_Reseller(ResellerKey);

-- Hechos Ventas -> Dimensión Territorio
ALTER TABLE Fact_Sales 
ADD CONSTRAINT FK_FactSales_DimSalesTerritory 
FOREIGN KEY (SalesTerritoryKey) REFERENCES Dim_SalesTerritory(SalesTerritoryKey);
GO