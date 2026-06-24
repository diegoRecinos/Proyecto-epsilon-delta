USE AdventureWorks2022; 
GO

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
