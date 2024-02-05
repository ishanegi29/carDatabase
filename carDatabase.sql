-- MintClassics Inventory Stats
-- Checking the warehouse inventory status
-- Objective: To  provide summary about the current total stock (inventory volume) in each warehouse.
SELECT ware.warehouseName, 
	   SUM(quantityInStock) as stock_availablility
FROM mintclassics.products AS prod
INNER JOIN mintclassics.warehouses AS ware
ON prod.warehouseCode = ware.warehouseCode
GROUP BY ware.warehouseName
ORDER BY SUM(quantityInStock) DESC;

-- Checking the inventory status of each product for each warehouse 
-- Objective: To facilitate a comprehensive understanding of inventory allocation of products/product lines. This helps
-- in understanding the product/product line based assembly in each warehouse.
SELECT prod.productLine,
	   prod.productName,
       ware.warehouseCode,
       ware.warehouseName,
       SUM(quantityInStock) as stock_availablility
FROM mintclassics.products AS prod
INNER JOIN mintclassics.warehouses AS ware
ON prod.warehouseCode = ware.warehouseCode
GROUP BY ware.warehouseName,ware.warehouseCode, prod.productName, prod.productLine
ORDER BY SUM(quantityInStock) DESC;

-- Most Stocked Product based on warehouse 
-- Objective: To provide insights about the concentration of products in each inventory 
-- which will further aid in effecient inventory management and streamline order fulfillment process.
WITH most_stocked AS(
	SELECT productName,productLine,warehouseCode,quantityInStock,
           ROW_NUMBER() OVER (PARTITION BY warehouseCode ORDER BY quantityInStock DESC) as highest_stock
FROM mintclassics.products)

SELECT productName,
	   productLine,
       warehouseCode,
       quantityInStock
FROM most_stocked
WHERE highest_stock <= 5;

-- Checking the products which are unsold(slow- moving inventory)
-- Objective: To identify products of idle goods within each warehouse which signifies low market demand.
-- It will allow for reorganization of  warehouses or discontinuation of unsold producst and prioritizing space for 
-- products with high turnovers.
SELECT p.productCode, 
	   p.productName, 
       p.productLine, 
       p.warehouseCode,
       COALESCE(od.quantityOrdered,0)
FROM mintclassics.products p
LEFT JOIN mintclassics.orderdetails od 
ON p.productCode = od.productCode
WHERE od.quantityOrdered IS NULL;

-- Products based on Orders vs Inventory Comparison 
-- Objective: To assess the inventory volume of products within each warehouse and compare these based on products to identify 
-- overstocked or high demand items.
SELECT productCode, 
	   productName, 
       warehouseCode,
       quantityInStock,
       total_orders,
       (total_orders - quantityInStock) AS inventory_shortage
FROM 
	(SELECT 
		p.productCode,
        p.productName,
        p.quantityInStock,
        p.warehouseCode,
        COALESCE(SUM(od.quantityOrdered),0) as total_orders
	 FROM mintclassics.products p
     LEFT JOIN mintclassics.orderdetails od 
     ON p.productCode = od.productCode
     GROUP BY p.productCode, p.productName,p.quantityInStock 
     HAVING total_orders > quantityInStock
     ) AS product_inventory
ORDER BY inventory_shortage DESC, total_orders DESC;

-- MintClassics Product Stats
-- Product based Sales and Price Comparison
-- Objective: To analyze the sales performance of each product which will help in recognizing popular and 
-- in demand products in the market.
SELECT p.productCode,
       p.productName, 
       p.buyPrice, 
       SUM(od.quantityOrdered) AS total_orders
FROM mintclassics.products p
LEFT JOIN mintclassics.orderdetails od 
ON p.productCode = od.productCode
GROUP BY p.productCode, p.productName, p.buyPrice
ORDER BY buyPrice ASC;


-- Product Line Based Comparison
-- Objective: To pin point high performing product categories using revenue and stock capacity 
-- to gain insights for making informed decisions about inventory management.
SELECT p.productName,
	   pl.productLine,
       SUM(od.quantityOrdered) AS net_sales,
       SUM(p.quantityInStock) AS stock_capacity,
       AVG(p.quantityInStock) AS avg_capacity,
       SUM(od.quantityOrdered * od.priceEach) AS total_revenue,
       (SUM(od.quantityOrdered)/avg(p.quantityInStock) * 100) AS salesToInventory_percentage
FROM mintclassics.products p
LEFT JOIN mintclassics.productlines pl
ON p.productLine = pl.productLine
LEFT JOIN mintclassics.orderdetails od
ON p.productCode = od.productCode
GROUP BY pl.productLine, p.productCode
HAVING net_sales IS NOT null
ORDER BY salesToInventory_percentage DESC;


-- MintClassics Order Shipping Stats
-- Logistics Effectiveness based on Product
-- Objective: To determine the duration of days by using Order date and Shipping date. This is necessary to focus on products 
-- and their respective warehouses requiring optimization of storage facilities and operational processes.
WITH prod_list AS (SELECT od.orderNumber,
	   od.productCode,
       p.productName,
       p.warehouseCode,
       od.quantityOrdered
FROM mintclassics.orderdetails od
LEFT JOIN mintclassics.products p
ON p.productCode = od.productCode)

SELECT o.orderNumber,
       o.orderDate,
       o. shippedDate,
       pd.productName,
       pd.warehouseCode,
	DATEDIFF(o.shippedDate, o.orderDate) as days_to_ship
FROM mintclassics.orders o 
INNER JOIN prod_list pd
ON o.orderNumber = pd.orderNumber
WHERE o.shippedDate IS NOT NULL
ORDER BY days_to_ship DESC;

-- Percentage Distribution of Order Shipping
-- Objective : To categorize the orders based on count as well as percenatge based on the number of days required for shipping.
-- This would provide insights in the potential bottlenecks and operational inefficiency within the shipping process.
WITH counts AS (
    SELECT DATEDIFF(shippedDate, orderDate) as days_to_ship, COUNT(*) as count
    FROM mintclassics.orders
    WHERE shippedDate IS NOT NULL AND orderDate IS NOT NULL
    GROUP BY DATEDIFF(shippedDate, orderDate)
)
SELECT days_to_ship,
       count as No_of_Orders,
       ROUND((CAST(count AS FLOAT) / (SELECT COUNT(*) FROM mintclassics.orders WHERE shippedDate IS NOT NULL AND orderDate IS NOT NULL)) * 100, 2) as percentage
FROM counts
ORDER BY days_to_ship;

-- Monthly Order Count with 24-hour Shipping
-- Objective: To understand the shipping efficiency (within 1 day) of products based on monthly and yearly order count.
SELECT
    YEAR(orderDate) AS Year,
    MONTH(orderDate) AS Month,
    COUNT(*) AS TotalOrders,
    SUM(CASE WHEN DATEDIFF(shippedDate, orderDate) = 1 THEN 1 ELSE 0 END) AS shipped_in_1day
FROM mintclassics.orders
GROUP BY YEAR(orderDate), MONTH(orderDate)
ORDER BY Year, Month;

-- Top 10 Days with Most Orders and 24-hour Shipping Percentage
-- Objective: To identify peak order dates for strategic product allocation in the warehouses for order fulfillment.
-- The calculation of percentage of shipping within 1 day provides understanding of operational effeciciency on high demand days.
SELECT
    orderDate,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN DATEDIFF(shippedDate, orderDate) = 1 THEN 1 ELSE 0 END) AS shipped_in_1day,
    ROUND((SUM(CASE WHEN DATEDIFF(shippedDate, orderDate) = 1 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS percentage_shipped_1day
FROM mintclassics.orders
GROUP BY orderDate
HAVING shipped_in_1day > 0
ORDER BY total_orders,shipped_in_1day DESC
LIMIT 10;

-- Products experiencing shipping delays by more than 5 days
-- Objective:  To identify specific products that face delays with more than 5 days and gain valuable insights into potential 
-- issues within the logistics and fulfillment processes. This allows the retailer company to understand and address root causes 
-- such as inventory mismanagement.
SELECT
    product.productName AS product,
    product.warehouseCode as warehouse,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN DATEDIFF(ord.shippedDate, ord.orderDate) > 5 THEN 1 ELSE 0 END) AS shipping_delay
FROM mintclassics.orders AS ord
LEFT JOIN 
(SELECT od.orderNumber,
	    p.productName,
        p.warehouseCode
FROM mintclassics.orderdetails od
LEFT JOIN mintclassics.products p
ON p.productCode = od.productCode
) AS product
ON ord.orderNumber = product.orderNumber
GROUP BY product.productName, product.warehouseCode
HAVING shipping_delay > 0
ORDER BY shipping_delay DESC
LIMIT 10;

-- MintClassics Customer Stats
-- Rank Customers based on number of Sales
-- Objective: To rank customers based on sales in order to provides actionable insights to the car retailer for refining sales strategies 
-- and optimizing resource allocation.
SELECT cust.customerNumber,
       cust.customerName,
       cust.country,
       COUNT(ord.orderNumber) AS total_orders,
DENSE_RANK() OVER(ORDER BY COUNT(ord.orderNumber)DESC) order_rank
FROM mintclassics.customers cust
LEFT JOIN mintclassics.orders ord
ON cust.customerNumber = ord.customerNumber
GROUP BY cust.customerNumber,cust.customerName
ORDER BY order_rank;

-- MintClassics Employee Stats
-- Employee Count in Each Office
-- Objective: To understand the staffing distribution based on state and country 
SELECT 
	emp.employeeNumber,
    ofc.officeCode,
    CONCAT(emp.firstName,' ', emp.lastName) AS name, 
    emp.jobTitle, 
    ofc.state,
    ofc.country
FROM mintclassics.offices ofc 
LEFT JOIN mintclassics.employees emp
ON ofc.officeCode = emp.officeCode
ORDER BY country, name;

-- Employee Standings based on Performance
-- Objective: To understand employee performance metrics to foster high-productivity workplace by either offering incentives or targetted training.
WITH CTE AS(SELECT 
	emp.employeeNumber,
    concat(emp.firstName, emp.lastName) AS Name, 
    emp.jobTitle,
    COUNT(ord.orderNumber) AS sales_count,
    SUM(od.quantityOrdered * od.priceEach) AS total_sales
FROM mintclassics.employees emp
LEFT JOIN mintclassics.customers cust
ON emp.employeeNumber = cust.salesRepEmployeeNumber
LEFT JOIN mintclassics.orders ord
ON cust.customerNumber = ord.customerNumber 
LEFT JOIN mintclassics.orderdetails od
ON ord.orderNumber = od.orderNumber
GROUP BY emp.employeeNumber
HAVING emp.jobTitle = 'Sales Rep'
ORDER BY sales_count DESC, total_sales DESC)

SELECT *, 
	CASE WHEN sales_count > 300 THEN 'Outstanding'
		 WHEN sales_count BETWEEN 176 AND 300 THEN 'Exceeds Expectations'
         WHEN sales_count BETWEEN 51 AND 175 THEN 'Meets Expectations'
		 WHEN sales_count BETWEEN 26 AND 50 THEN 'Needs Improvement'
		 ELSE 'Unsatisfactory'
	END  AS performance_rating
FROM CTE;
