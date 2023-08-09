USE [NORTHWND-BD];

-------------------------------------------------------------------------------------------------------------------------------------------------
--REPASO QUERIES 1
-------------------------------------------------------------------------------------------------------------------------------------------------

/*Listar los empleados y el producto que m�s vendi� en cantidad de �rdenes 
 realizado en un determinado a�o 2017. 
Tome como base la fecha de la orden (orderdate)*/
/*Empleado, el producto, la cantidad*/

CREATE VIEW vw_employee AS
	SELECT e.EmployeeID, od.ProductID, p.ProductName, COUNT(o.OrderId) AS 'Quantity'
	FROM Employees e INNER JOIN Orders o ON e.EmployeeID=o.EmployeeID
					 INNER JOIN [Order Details] od ON o.OrderID=od.OrderID
					 INNER JOIN Products p ON od.ProductID = p.ProductID
	WHERE YEAR(o.OrderDate)=2017
	GROUP BY e.EmployeeID, od.ProductID, p.ProductName

SELECT vw.*
FROM vw_employee vw
WHERE vw.Quantity >= ALL (SELECT vwMin.Quantity FROM vw_employee vwMin WHERE vw.EmployeeId = vwMin.EmployeeId)
Order by 1

DROP VIEW vw_employee

/*Mostrar los empleados que tuvieron la mayor cantidad de ordenes
 vendidas en el a�o 2017
Mostrar el empleado, producto vendido y la cantidad de ordenes vendidas*/

SELECT vw.*
FROM vw_employee vw
WHERE vw.Quantity >= ALL (SELECT vwMin.Quantity FROM vw_employee vwMin)
Order by 2

/*Northwind desea saber si sus ventas est�n incrementando de a�o a 
a�o por lo tanto debe crear un procedimiento almacenado 
que muestre las ventas en monto y en cantidad de un a�o elegido 
y las ventas en monto y en cantidad de a�o anterior al elegido.*/

CREATE PROCEDURE sp_sales @year INT 
AS
BEGIN
	SELECT YEAR(o.OrderDate) as 'Year', ROUND(SUM(od.UnitPrice*od.Quantity*(1-od.Discount)),2) as 'Amount', COUNT(od.OrderID) as 'Quantity'
	FROM Orders o INNER JOIN [Order Details] od ON o.OrderID=od.OrderID
	WHERE YEAR(o.OrderDate)=@year
	GROUP BY YEAR(o.OrderDate)

	UNION

	SELECT YEAR(o.OrderDate) as 'Year', ROUND(SUM(od.UnitPrice*od.Quantity*(1-od.Discount)),2) as 'Amount', COUNT(od.OrderID) as 'Quantity'
	FROM Orders o INNER JOIN [Order Details] od ON o.OrderID=od.OrderID
	WHERE YEAR(o.OrderDate)=@year-1
	GROUP BY YEAR(o.OrderDate)

END;

EXEC sp_sales 2018;

DROP PROCEDURE sp_sales

 /*Mostrar la lista de Categorias cuyos productos 
 son los m�s vendidos (Quantity) durante el a�o 2017 y de las categor�as cuyos productos han sido 
 los menos vendidos durante ese mismo a�o. 
 Se debe mostrar la categor�a y la cantidad de 
 productos vendidos y una marca que indique si es 
 m�nimo o m�ximo.*/

CREATE VIEW vw_quantity_by_category AS
	SELECT c.CategoryID, c.CategoryName, SUM(od.Quantity) AS 'Quantity'
	FROM Categories c INNER JOIN Products p ON C.CategoryID=p.CategoryID
					  INNER JOIN [Order Details] od ON p.ProductID = od.ProductID
					  INNER JOIN Orders o ON od.OrderID=o.OrderID
	WHERE YEAR(o.OrderDate)=2017
	GROUP BY c.CategoryID, c.CategoryName

SELECT vwq.*, 'Maximum' as 'Type'
FROM vw_quantity_by_category vwq
WHERE vwq.Quantity>= ALL (SELECT vwmax.Quantity
						  FROM vw_quantity_by_category vwmax)

UNION ALL

SELECT vwq.*, 'Minimum' as 'Type'
FROM vw_quantity_by_category vwq
WHERE vwq.Quantity<= ALL (SELECT vwmin.Quantity
						  FROM vw_quantity_by_category vwmin)

DROP VIEW vw_quantity_by_category

 /*Se quiere otorgar un incentivo a los empleados en su onom�stico, 
 para lo cual en el mes de su cumplea�os se le entregar� un bono 
 equivalente al 5% del monto de la venta efectuada por el durante 
 el mes. Obtener la relaci�n de empleados que se har�n acreedores 
 a dicho bono, mostrando: ID empleado, apellido, nombre, 
 fecha de nacimiento e importe a entregar.*/

CREATE VIEW vw_employee_birthdate AS
	SELECT e.EmployeeID, e.LastName, e.FirstName, e.BirthDate, SUM(0.05*((od.UnitPrice*od.Quantity)*(1-od.Discount))) as Bono, DATEPART(YEAR, o.OrderDate) as 'A�o'
	FROM Orders o join [Order Details] od ON o.OrderID=od.OrderID
				  join Employees e ON o.EmployeeID=e.EmployeeID
	WHERE DATEPART(MONTH, o.OrderDate)=DATEPART(MONTH, e.BirthDate) 
	GROUP BY e.EmployeeID, e.LastName, e.FirstName, e.BirthDate, DATEPART(YEAR, o.OrderDate)

SELECT vw.* FROM vw_employee_birthdate vw
ORDER BY vw.EmployeeID ASC

DROP VIEW vw_employee_birthdate

 /*Actualiza el precio de los productos con 
 el 10% de su valor, de aquellos productos de categor�a 3 y que 
 alguna vez fueron vendidos a Francia*/

CREATE PROCEDURE sp_update_products_france AS
BEGIN TRANSACTION 
	UPDATE Products
	SET UnitPrice = p.UnitPrice*(1.10)
	FROM Orders o INNER JOIN [Order Details] od ON o.OrderID=od.OrderID
				  INNER JOIN Products p ON od.ProductID=p.ProductID
	WHERE o.ShipCountry = 'France' AND p.CategoryID=3

EXEC sp_update_products_france;

DROP PROCEDURE sp_update_products_france;

/*
Northwind debe premiar a los clientes cuya cantidad 
 de �rdenes compradas y cantidad de monto acumulado haya superado 
 el promedio de �rdenes compradas y monto comprado de su mismo 
 pa�s en un determinado a�o. Debe mostrar el cliente, monto de venta 
 acumulado, cantidad de �rdenes compradas y pa�s
*/

CREATE VIEW vw_avg_country AS
	SELECT o.CustomerID, o.ShipCountry, YEAR(o.OrderDate) AS 'Year', COUNT(o.OrderID) AS 'Quantity', ROUND(SUM(od.Quantity*od.UnitPrice*(1-od.Discount)),2) AS 'Amount'
	FROM Orders o INNER JOIN [Order Details] od ON o.OrderID=od.OrderID
	GROUP BY o.CustomerID, o.ShipCountry, YEAR(o.OrderDate)

SELECT vwAvg.CustomerID, vwAvg.Amount, vwAvg.Quantity, vwAvg.ShipCountry, vwAvg.Year
FROM vw_avg_country vwAvg 
WHERE vwAvg.Amount>=(SELECT AVG(vwAmount.Amount) 
					 FROM vw_avg_country vwAmount
					 WHERE vwAvg.ShipCountry = vwAmount.ShipCountry)
AND vwAvg.Amount>=(SELECT AVG(vwQuantity.Quantity) 
					 FROM vw_avg_country vwQuantity
					 WHERE vwAvg.ShipCountry = vwQuantity.ShipCountry)

DROP VIEW vw_avg_country;

-------------------------------------------------------------------------------------------------------------------------------------------------
--REPASO QUERIES 2
-------------------------------------------------------------------------------------------------------------------------------------------------

/*
Seleccionar por pa�s el cliente a quien m�s se le ha vendido 
y el n�mero de �rdenes que se emitieron para ese cliente, solo de las 
ventas del 2017 y el pa�s de env�o sea el mismo del cliente, 
ordenado por pa�s y nombre cliente. Se debe mostrar pa�s, 
id cliente, nombre cliente, numero ordenes, importe vendido
*/

CREATE VIEW vw_customer_country AS
	SELECT c.CustomerID, o.ShipCountry, COUNT(o.OrderID) AS 'Orders', ROUND(SUM(od.UnitPrice*od.Quantity*(1-od.Discount)),2) AS 'Amount' 
	FROM Customers c INNER JOIN Orders o ON c.CustomerID = o.CustomerID
					INNER JOIN [Order Details] od ON o.OrderID=od.OrderID
	WHERE YEAR(o.OrderDate)=2017 AND o.ShipCountry = c.Country
	GROUP BY c.CustomerID, o.ShipCountry

SELECT vw.*
FROM vw_customer_country vw
WHERE vw.Orders >= ALL(SELECT vw1.Orders
					   FROM vw_customer_country vw1
					   WHERE vw.ShipCountry = vw1.ShipCountry)
ORDER BY 4 DESC

/* Liste los productos que se quedar�an desabastecidos 
 si la venta en unidades se multiplica por 2. 
 Muestre el c�digo del producto, 
 su stock actual, la venta en unidades actual y 
 la que ser�a si se multiplica por 2.*/

CREATE VIEW vw_products_out_of_stock AS
	SELECT p.ProductID, p.UnitsInStock, SUM(od.Quantity) AS 'Sales', SUM(od.Quantity)*2 AS 'Sales x2'
	FROM Products p INNER JOIN [Order Details] od ON od.ProductID=p.ProductID
	GROUP BY p.ProductID, p.UnitsInStock
	HAVING SUM(od.Quantity)*2 >= p.UnitsInStock

SELECT * FROM vw_products_out_of_stock

/*
Mostrar el proveedor que
 tuvo la menor venta (MONTO) de productos en un a�o 2017
*/

CREATE VIEW vw_supplier AS
	SELECT s.SupplierID, s.CompanyName, ROUND(SUM(od.Quantity*od.UnitPrice*(1-od.Discount)),2) AS 'Amount', DATEPART(YEAR, o.OrderDate) AS 'Year'
	FROM Suppliers s INNER JOIN Products p ON s.SupplierID=p.SupplierID
					 INNER JOIN [Order Details] od ON p.ProductID=od.ProductID
					 INNER JOIN Orders o ON od.OrderID=o.OrderID
	WHERE DATEPART(YEAR, o.OrderDate)=2017
	GROUP BY s.SupplierID, s.CompanyName, DATEPART(YEAR, o.OrderDate)

SELECT *
FROM vw_supplier vw
WHERE vw.Amount <= ALL(SELECT vwAmount.Amount
					   FROM vw_supplier vwAmount)

/*
Muestre el territorio y nombre de los jefes cuyos empleados han superado dos �rdenes vendidas y m�s de 
1000 en monto vendido. Estos jefes ser�n acreedores de un premio siempre y cuando
 la diferencia en d�as entre la fecha de la orden y la fecha de despacho no sea mayor a 7.
*/

CREATE VIEW vw_boss_territory AS
	SELECT t.TerritoryID, t.TerritoryDescription, b.EmployeeID, COUNT(o.OrderID) AS 'Orders', ROUND(SUM(od.Quantity*od.UnitPrice*(1-od.Discount)),2) AS 'Amount'
	FROM Employees e INNER JOIN Employees b ON e.ReportsTo=b.EmployeeID
					 INNER JOIN EmployeeTerritories et ON b.EmployeeID=et.EmployeeID
					 INNER JOIN Territories t ON et.TerritoryID=t.TerritoryID
					 INNER JOIN Orders o ON e.EmployeeID=o.EmployeeID
					 INNER JOIN [Order Details] od ON o.OrderID=od.OrderID
	WHERE DATEDIFF(DAY,o.OrderDate,o.ShippedDate)<=7
	GROUP BY t.TerritoryID, t.TerritoryDescription, b.EmployeeID
	HAVING COUNT(o.OrderID)>2 AND ROUND(SUM(od.Quantity*od.UnitPrice*(1-od.Discount)),2)>1000
	ORDER BY 2

SELECT *
FROM vw_boss_territory

-------------------------------------------------------------------------------------------------------------------------------------------------
--REPASO QUERIES 3
-------------------------------------------------------------------------------------------------------------------------------------------------

/*14.Crear un procedimiento para insertar una categor�a, 
cuando inserte debe cambiar a descontinuado el producto 8*/
