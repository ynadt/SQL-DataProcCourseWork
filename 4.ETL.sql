-- Enable dblink Extension
CREATE EXTENSION IF NOT EXISTS dblink;

-- Connect to the OLTP Database
DO $$
    BEGIN
        PERFORM dblink_connect(
                'oltp_conn',
                'dbname=oltp host=localhost port=5432 user=postgres password=010920'
                );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Connection to OLTP database failed. Check credentials and network connectivity.';
    END $$;

-- DimTime
DO $$
    BEGIN
        INSERT INTO DimTime (TimeKey, Year, Quarter, Month, Day, Week)
        SELECT
            d::DATE AS TimeKey,
            EXTRACT(YEAR FROM d::DATE) AS Year,
            CEIL(EXTRACT(MONTH FROM d::DATE) / 3.0) AS Quarter,
            EXTRACT(MONTH FROM d::DATE) AS Month,
            EXTRACT(DAY FROM d::DATE) AS Day,
            EXTRACT(WEEK FROM d::DATE) AS Week
        FROM generate_series('2024-01-01'::DATE, '2025-12-31'::DATE, '1 day'::INTERVAL) d
        ON CONFLICT (TimeKey) DO NOTHING;
    END $$;

--DimAddress
DO $$
    BEGIN
        INSERT INTO DimAddress (AddressID, AddressLine, City, State, Country, PostalCode)
        SELECT
            addressid AS AddressID,
            addressline AS AddressLine,
            city AS City,
            state AS State,
            country AS Country,
            postalcode AS PostalCode
        FROM dblink('oltp_conn',
                    'SELECT addressid, addressline, city, state, country, postalcode FROM public.addresses')
                 AS t(AddressID INT, AddressLine VARCHAR, City VARCHAR, State VARCHAR, Country VARCHAR, PostalCode VARCHAR)
        ON CONFLICT (AddressID) DO UPDATE
            SET
                AddressLine = EXCLUDED.AddressLine,
                City = EXCLUDED.City,
                State = EXCLUDED.State,
                Country = EXCLUDED.Country,
                PostalCode = EXCLUDED.PostalCode;
    END $$;

-- DimCustomer
DO $$
    BEGIN
        -- Step 1: Mark inactive customers (SCD Type 2 logic)
        UPDATE DimCustomer
        SET
            RecordEndDate = CURRENT_TIMESTAMP,
            IsActive = FALSE
        WHERE IsActive = TRUE
          AND EXISTS (
            SELECT 1
            FROM dblink('oltp_conn',
                        'SELECT u.email, u.firstname, u.lastname, u.phonenumber, u.addressid
                         FROM public.users u')
                     AS t(Email VARCHAR, FirstName VARCHAR, LastName VARCHAR, PhoneNumber VARCHAR, AddressID INT)
            WHERE DimCustomer.Email = t.Email
              AND (
                DimCustomer.CustomerFullName <> t.FirstName || ' ' || t.LastName OR
                DimCustomer.PhoneNumber <> t.PhoneNumber OR
                DimCustomer.AddressKey <> (SELECT AddressKey FROM DimAddress WHERE AddressID = t.AddressID)
                )
        );

        -- Step 2: Insert new rows for updated or new customers
        INSERT INTO DimCustomer (
            Email, CustomerFullName, PhoneNumber, AddressKey, RecordStartDate, IsActive
        )
        SELECT
            t.Email,
            t.FirstName || ' ' || t.LastName AS CustomerFullName,
            t.PhoneNumber,
            (SELECT AddressKey FROM DimAddress WHERE AddressID = t.AddressID) AS AddressKey,
            CURRENT_TIMESTAMP AS RecordStartDate,
            TRUE AS IsActive
        FROM dblink('oltp_conn',
                    'SELECT u.email, u.firstname, u.lastname, u.phonenumber, u.addressid
                     FROM public.users u')
                 AS t(Email VARCHAR, FirstName VARCHAR, LastName VARCHAR, PhoneNumber VARCHAR, AddressID INT)
        WHERE NOT EXISTS (
            SELECT 1
            FROM DimCustomer
            WHERE DimCustomer.Email = t.Email
              AND DimCustomer.IsActive = TRUE
        )
        ON CONFLICT (Email, RecordStartDate) DO NOTHING;
    END $$;

-- DimCategory
DO $$
BEGIN
INSERT INTO DimCategory (CategoryID, CategoryName, ParentCategoryKey)
SELECT
    c.categoryid AS CategoryID,
    c.name AS CategoryName,
    (SELECT CategoryKey FROM DimCategory WHERE CategoryID = c.parentcategoryid) AS ParentCategoryKey
FROM dblink('oltp_conn',
            'SELECT categoryid, name, parentcategoryid FROM public.categories')
         AS c(CategoryID INT, Name VARCHAR, ParentCategoryID INT)
ON CONFLICT (CategoryID) DO UPDATE
    SET
        CategoryName = EXCLUDED.CategoryName,
        ParentCategoryKey = EXCLUDED.ParentCategoryKey;
END $$;

-- DimBrand
DO $$
    BEGIN
        INSERT INTO DimBrand (BrandID, BrandName, BrandDescription)
        SELECT
            t.BrandID,
            t.Name AS BrandName,
            t.Description AS BrandDescription
        FROM dblink('oltp_conn',
                    'SELECT brandid, name, description FROM public.brands')
                 AS t(BrandID INT, Name VARCHAR, Description TEXT)
        ON CONFLICT (BrandID) DO UPDATE
            SET
                BrandName = EXCLUDED.BrandName,
                BrandDescription = EXCLUDED.BrandDescription;
    END $$;

-- DimAvailabilityStatus
DO $$
    BEGIN
        INSERT INTO DimAvailabilityStatus (AvailabilityStatusName)
        SELECT DISTINCT availabilitystatusname
        FROM dblink('oltp_conn',
                    'SELECT availabilitystatusname FROM public.availabilitystatuses')
                 AS t(AvailabilityStatusName VARCHAR)
        ON CONFLICT (AvailabilityStatusName) DO NOTHING;
    END $$;

-- DimProduct
DO $$
    BEGIN
        -- Step 1: Mark inactive products (SCD Type 2 logic)
        UPDATE DimProduct
        SET
            RecordEndDate = CURRENT_TIMESTAMP,
            IsActive = FALSE
        WHERE IsActive = TRUE
          AND EXISTS (
            SELECT 1
            FROM dblink('oltp_conn',
                        'SELECT p.productid, p.name, p.categoryid, p.brandid, p.price, a.availabilitystatusname
                         FROM public.products p
                                  JOIN public.availabilitystatuses a ON p.availabilitystatusid = a.availabilitystatusid')
                     AS t(ProductID INT, Name VARCHAR, CategoryID INT, BrandID INT, Price NUMERIC, AvailabilityStatusName VARCHAR)
            WHERE DimProduct.ProductID = t.ProductID
              AND (
                DimProduct.ProductName <> t.Name OR
                DimProduct.CategoryKey <> (SELECT CategoryKey FROM DimCategory WHERE CategoryID = t.CategoryID) OR
                DimProduct.BrandKey <> (SELECT BrandKey FROM DimBrand WHERE BrandID = t.BrandID) OR
                DimProduct.CurrentPrice <> t.Price OR
                DimProduct.AvailabilityStatusKey <> (SELECT AvailabilityStatusKey FROM DimAvailabilityStatus WHERE AvailabilityStatusName = t.AvailabilityStatusName)
                )
        );

        -- Step 2: Insert new rows for updated or new products
        INSERT INTO DimProduct (
            ProductID, ProductName, CategoryKey, BrandKey, CurrentPrice, AvailabilityStatusKey, RecordStartDate, IsActive
        )
        SELECT
            t.ProductID,
            t.Name,
            c.CategoryKey,
            b.BrandKey,
            t.Price,
            a.AvailabilityStatusKey,
            CURRENT_TIMESTAMP AS RecordStartDate,
            TRUE AS IsActive
        FROM (
                 SELECT
                     productid AS ProductID,
                     name AS Name,
                     categoryid AS CategoryID,
                     brandid AS BrandID,
                     price AS Price,
                     availabilitystatusname AS AvailabilityStatusName
                 FROM dblink('oltp_conn',
                             'SELECT p.productid, p.name, p.categoryid, p.brandid, p.price, a.availabilitystatusname
                              FROM public.products p
                                       JOIN public.availabilitystatuses a ON p.availabilitystatusid = a.availabilitystatusid')
                          AS t(ProductID INT, Name VARCHAR, CategoryID INT, BrandID INT, Price NUMERIC, AvailabilityStatusName VARCHAR)
             ) AS t
                 LEFT JOIN DimCategory c ON c.CategoryID = t.CategoryID
                 LEFT JOIN DimBrand b ON b.BrandID = t.BrandID
                 LEFT JOIN DimAvailabilityStatus a ON a.AvailabilityStatusName = t.AvailabilityStatusName
        WHERE NOT EXISTS (
            SELECT 1
            FROM DimProduct
            WHERE DimProduct.ProductID = t.ProductID
              AND DimProduct.IsActive = TRUE
        )
        ON CONFLICT (ProductID, RecordStartDate) DO NOTHING;
    END $$;

-- DimPromotion
DO $$
    BEGIN
        INSERT INTO DimPromotion (PromotionKey, PromotionID, PromotionName, DiscountPercent, StartDate, EndDate, IsActive)
        SELECT *
        FROM dblink(
                     'oltp_conn',
                     'SELECT
                          pr.promotionid AS PromotionKey,
                          pr.promotionid AS PromotionID,
                          pr.code AS PromotionName,
                          pr.discountpercent AS DiscountPercent,
                          pr.startdate AS StartDate,
                          pr.enddate AS EndDate,
                          pr.isactive AS IsActive
                      FROM public.promotions pr'
             ) AS t(PromotionKey INT, PromotionID INT, PromotionName VARCHAR, DiscountPercent NUMERIC, StartDate DATE, EndDate DATE, IsActive BOOLEAN)
        ON CONFLICT (PromotionID) DO NOTHING;
    END $$;

-- DimPaymentMethod
DO $$
    BEGIN
        INSERT INTO DimPaymentMethod (PaymentMethodKey, PaymentMethodName)
        SELECT *
        FROM dblink(
                     'oltp_conn',
                     'SELECT paymentmethodid AS PaymentMethodKey,
                             paymentmethodname AS PaymentMethodName
                      FROM public.paymentmethods'
             ) AS t(PaymentMethodKey INT, PaymentMethodName VARCHAR)
        ON CONFLICT (PaymentMethodKey) DO NOTHING;
    END $$;

-- DimOrderStatus
DO $$
    BEGIN
        INSERT INTO DimOrderStatus (OrderStatusKey, OrderStatusName)
        SELECT DISTINCT
            OrderStatusID AS OrderStatusKey,
            OrderStatusName
        FROM dblink('oltp_conn',
                    'SELECT orderstatusid, orderstatusname
                     FROM public.orderstatuses')
                 AS t(OrderStatusID INT, OrderStatusName VARCHAR)
        ON CONFLICT (OrderStatusKey) DO NOTHING;
    END $$;


-- FactSales
DO $$
    BEGIN
        INSERT INTO FactSales (
            OrderID, OrderDateKey, CustomerKey, PaymentMethodKey, OrderStatusKey, TotalQuantity, TotalRevenue, TotalDiscount
        )
        SELECT
            t.OrderID,
            t.CreatedAt::DATE,
            (SELECT CustomerKey FROM DimCustomer WHERE Email = t.Email ORDER BY RecordStartDate DESC LIMIT 1),
            t.PaymentMethodID,
            t.OrderStatusID,
            SUM(t.Quantity),
            t.TotalAmount,
            COALESCE(SUM((t.DiscountPercent / 100.0) * t.TotalAmount), 0)
        FROM (
                 SELECT
                     dblink_data.OrderID,
                     dblink_data.CreatedAt,
                     dblink_data.Email,
                     dblink_data.PaymentMethodID,
                     dblink_data.OrderStatusID,
                     dblink_data.TotalAmount,
                     COALESCE(dblink_data.DiscountPercent, 0) AS DiscountPercent,
                     dblink_data.Quantity
                 FROM dblink('oltp_conn',
                             $dblink$
                             SELECT
                                 o.orderid,
                                 o.createdat,
                                 u.email,
                                 o.paymentmethodid,
                                 o.orderstatusid,
                                 o.totalamount,
                                 p.discountpercent,
                                 od.quantity
                             FROM public.orders o
                                      JOIN public.users u ON o.userid = u.userid
                                      LEFT JOIN public.promotions p ON o.promotionid = p.promotionid
                                      JOIN public.orderdetails od ON o.orderid = od.orderid
                             $dblink$
                      ) AS dblink_data(
                                       OrderID INT,
                                       CreatedAt TIMESTAMP,
                                       Email VARCHAR,
                                       PaymentMethodID INT,
                                       OrderStatusID INT,
                                       TotalAmount NUMERIC,
                                       DiscountPercent NUMERIC,
                                       Quantity INT
                     )
             ) AS t
        GROUP BY t.OrderID, t.CreatedAt, t.Email, t.PaymentMethodID, t.OrderStatusID, t.TotalAmount
        ON CONFLICT (OrderID) DO NOTHING; -- Avoid updating CustomerKey
    END $$;

-- FactOrderDetails
DO $$
    BEGIN
        INSERT INTO FactOrderDetails (
            SalesKey, ProductKey, Quantity, UnitPrice, LineTotal
        )
        SELECT
            fs.SalesKey,
            t.ProductID AS ProductKey,
            t.Quantity AS Quantity,
            t.Price AS UnitPrice,
            t.Quantity * t.Price AS LineTotal
        FROM dblink('oltp_conn',
                    $dblink$
                    SELECT od.orderid, od.productid, od.quantity, p.price
                    FROM public.orderdetails od
                             JOIN public.products p ON od.productid = p.productid
                    $dblink$
             ) AS t(OrderID INT, ProductID INT, Quantity INT, Price NUMERIC)
                 JOIN FactSales fs ON fs.OrderID = t.OrderID
        WHERE NOT EXISTS (
            SELECT 1
            FROM FactOrderDetails fod
            WHERE fod.SalesKey = fs.SalesKey
              AND fod.ProductKey = t.ProductID
        );
    END $$;


-- FactPromotionEffectiveness
DO $$
    BEGIN
        INSERT INTO FactPromotionEffectiveness (
            PromotionKey,
            StartDateKey,
            EndDateKey,
            TotalCustomers,
            TotalOrders,
            TotalRevenue,
            TotalDiscount,
            TotalQuantity
        )
        SELECT
            dp.PromotionKey,
            MIN(t.CreatedAt::DATE) AS StartDateKey,
            MAX(t.CreatedAt::DATE) AS EndDateKey,
            COUNT(DISTINCT t.UserID) AS TotalCustomers,
            COUNT(DISTINCT t.OrderID) AS TotalOrders,
            SUM(t.TotalAmount) AS TotalRevenue,
            COALESCE(SUM((t.DiscountPercent / 100) * t.TotalAmount), 0) AS TotalDiscount,
            SUM(t.TotalQuantity) AS TotalQuantity
        FROM (
                 SELECT
                     o.promotionid AS PromotionID,
                     o.createdat AS CreatedAt,
                     o.userid AS UserID,
                     o.orderid AS OrderID,
                     o.totalamount AS TotalAmount,
                     COALESCE(o.discountpercent, 0) AS DiscountPercent,
                     SUM(o.quantity) AS TotalQuantity
                 FROM dblink(
                              'oltp_conn',
                              $dblink$
                              SELECT o.promotionid,
                                     o.createdat,
                                     o.userid,
                                     o.orderid,
                                     o.totalamount,
                                     COALESCE(pr.discountpercent, 0) AS discountpercent,
                                     od.quantity
                              FROM public.orders o
                                       JOIN public.orderdetails od ON o.orderid = od.orderid
                                       LEFT JOIN public.promotions pr ON o.promotionid = pr.promotionid
                              WHERE o.promotionid IS NOT NULL
                              $dblink$
                      ) AS o(promotionid INT, createdat TIMESTAMP, userid INT, orderid INT, totalamount NUMERIC, discountpercent NUMERIC, quantity INT)
                 GROUP BY o.promotionid, o.createdat, o.userid, o.orderid, o.totalamount, o.discountpercent
             ) AS t
                 JOIN DimPromotion dp ON t.PromotionID = dp.PromotionID
        GROUP BY dp.PromotionKey
        ON CONFLICT (PromotionKey) DO UPDATE
            SET StartDateKey = EXCLUDED.StartDateKey,
                EndDateKey = EXCLUDED.EndDateKey,
                TotalCustomers = EXCLUDED.TotalCustomers,
                TotalOrders = EXCLUDED.TotalOrders,
                TotalRevenue = EXCLUDED.TotalRevenue,
                TotalDiscount = EXCLUDED.TotalDiscount,
                TotalQuantity = EXCLUDED.TotalQuantity
        WHERE FactPromotionEffectiveness.TotalCustomers <> EXCLUDED.TotalCustomers
           OR FactPromotionEffectiveness.TotalOrders <> EXCLUDED.TotalOrders
           OR FactPromotionEffectiveness.TotalRevenue <> EXCLUDED.TotalRevenue
           OR FactPromotionEffectiveness.TotalDiscount <> EXCLUDED.TotalDiscount
           OR FactPromotionEffectiveness.TotalQuantity <> EXCLUDED.TotalQuantity;
    END $$;

-- Disconnect from OLTP Database
DO $$
    BEGIN
        PERFORM dblink_disconnect('oltp_conn');
    END $$;