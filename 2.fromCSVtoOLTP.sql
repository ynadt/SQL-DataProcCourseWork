-- AvailabilityStatuses
DO $$
    BEGIN
        DROP TABLE IF EXISTS temp_availabilitystatuses;

        CREATE TEMP TABLE temp_availabilitystatuses (
                                                        AvailabilityStatusName VARCHAR(50)
        );

        COPY temp_availabilitystatuses(AvailabilityStatusName)
            FROM 'D:/csv/AvailabilityStatuses.csv'
            DELIMITER ','
            CSV HEADER;

        INSERT INTO AvailabilityStatuses (AvailabilityStatusID, AvailabilityStatusName)
        SELECT nextval('AvailabilityStatuses_AvailabilityStatusID_seq'), t.AvailabilityStatusName
        FROM temp_availabilitystatuses t
        ON CONFLICT (AvailabilityStatusName) DO NOTHING;

        DROP TABLE temp_availabilitystatuses;
    END $$;

-- PaymentMethods
DO $$
    BEGIN
        DROP TABLE IF EXISTS temp_paymentmethods;

        CREATE TEMP TABLE temp_paymentmethods (
                                                  PaymentMethodName VARCHAR(50)
        );

        COPY temp_paymentmethods(PaymentMethodName)
            FROM 'D:/csv/PaymentMethods.csv'
            DELIMITER ','
            CSV HEADER;

        INSERT INTO PaymentMethods (PaymentMethodID, PaymentMethodName)
        SELECT nextval('PaymentMethods_PaymentMethodID_seq'), t.PaymentMethodName
        FROM temp_paymentmethods t
        ON CONFLICT (PaymentMethodName) DO NOTHING;

        DROP TABLE temp_paymentmethods;
    END $$;

-- OrderStatuses
DO $$
    BEGIN
        DROP TABLE IF EXISTS temp_orderstatuses;

        CREATE TEMP TABLE temp_orderstatuses (
                                                 OrderStatusName VARCHAR(50)
        );

        COPY temp_orderstatuses(OrderStatusName)
            FROM 'D:/csv/OrderStatuses.csv'
            DELIMITER ','
            CSV HEADER;

        INSERT INTO OrderStatuses (OrderStatusID, OrderStatusName)
        SELECT nextval('OrderStatuses_OrderStatusID_seq'), t.OrderStatusName
        FROM temp_orderstatuses t
        ON CONFLICT (OrderStatusName) DO NOTHING;

        DROP TABLE temp_orderstatuses;
    END $$;

-- Users Table and Addresses table
DO $$
    BEGIN
        -- Step 1: Drop temporary table if it exists
        DROP TABLE IF EXISTS temp_users;

        -- Step 2: Create a temporary table
        CREATE TEMP TABLE temp_users (
                                         Email VARCHAR(100),
                                         FirstName VARCHAR(50),
                                         LastName VARCHAR(50),
                                         PhoneNumber VARCHAR(15),
                                         AddressLine VARCHAR(255),
                                         City VARCHAR(50),
                                         State VARCHAR(50),
                                         Country VARCHAR(50),
                                         PostalCode VARCHAR(20)
        );

        -- Step 3: Load data into the temporary table
        COPY temp_users(Email, FirstName, LastName, PhoneNumber, AddressLine, City, State, Country, PostalCode)
            FROM 'D:/csv/Users.csv'
            DELIMITER ',' CSV HEADER;

        -- Step 4: Ensure all addresses exist in the Addresses table
        INSERT INTO Addresses (AddressLine, City, State, Country, PostalCode)
        SELECT DISTINCT
            t.AddressLine,
            t.City,
            t.State,
            t.Country,
            t.PostalCode
        FROM temp_users t
        ON CONFLICT (AddressLine, City, State, Country, PostalCode) DO NOTHING;

        -- Step 5: Insert or update users in the Users table
        INSERT INTO Users (Email, FirstName, LastName, PhoneNumber, AddressID)
        SELECT
            t.Email,
            t.FirstName,
            t.LastName,
            t.PhoneNumber,
            (SELECT AddressID
             FROM Addresses a
             WHERE a.AddressLine = t.AddressLine
               AND a.City = t.City
               AND a.State = t.State
               AND a.Country = t.Country
               AND a.PostalCode = t.PostalCode)
        FROM temp_users t
        ON CONFLICT (Email) DO UPDATE
            SET FirstName = EXCLUDED.FirstName,
                LastName = EXCLUDED.LastName,
                PhoneNumber = EXCLUDED.PhoneNumber,
                AddressID = EXCLUDED.AddressID;

        -- Step 6: Drop the temporary table
        DROP TABLE temp_users;
    END $$;


-- Categories Table
DO $$
    BEGIN
        -- Step 1: Drop the temporary table if it exists
        DROP TABLE IF EXISTS temp_categories;

        -- Step 2: Create a temporary table
        CREATE TEMP TABLE temp_categories (
                                              Name VARCHAR(100),
                                              ParentCategory VARCHAR(100)
        );

        -- Step 3: Load data into the temporary table
        COPY temp_categories(Name, ParentCategory)
            FROM 'D:/csv/Categories.csv'
            DELIMITER ',' CSV HEADER;

        -- Step 4: Insert parent categories (those without a ParentCategory)
        INSERT INTO Categories (Name)
        SELECT DISTINCT t.Name
        FROM temp_categories t
        WHERE t.ParentCategory IS NULL
        ON CONFLICT (Name) DO NOTHING;

        -- Step 5: Insert child categories (those with a ParentCategory)
        INSERT INTO Categories (Name, ParentCategoryID)
        SELECT
            t.Name,
            c.CategoryID
        FROM temp_categories t
                 JOIN Categories c ON t.ParentCategory = c.Name
        WHERE t.ParentCategory IS NOT NULL
        ON CONFLICT (Name) DO UPDATE
            SET ParentCategoryID = EXCLUDED.ParentCategoryID;

        -- Step 6: Drop the temporary table
        DROP TABLE temp_categories;
    END $$;

-- Brands Table
DO $$
    BEGIN
        -- Step 1: Drop the temporary table if it exists
        DROP TABLE IF EXISTS temp_brands;

        -- Step 2: Create a temporary table
        CREATE TEMP TABLE temp_brands (
                                          Name VARCHAR(100),
                                          Description TEXT
        );

        -- Step 3: Load data into the temporary table
        COPY temp_brands(Name, Description)
            FROM 'D:/csv/Brands.csv'
            DELIMITER ','
            CSV HEADER;

        -- Step 4: Insert or update rows
        INSERT INTO Brands (Name, Description)
        SELECT t.Name, t.Description
        FROM temp_brands t
        ON CONFLICT (Name) DO UPDATE
            SET Description = EXCLUDED.Description;

        -- Step 5: Drop the temporary table
        DROP TABLE temp_brands;
    END $$;

-- Products Table
DO $$
    BEGIN
        -- Step 1: Drop temporary table if it exists
        DROP TABLE IF EXISTS temp_products;

        -- Step 2: Create a temporary table
        CREATE TEMP TABLE temp_products (
                                            SKU VARCHAR(50),
                                            Name VARCHAR(100),
                                            CategoryName VARCHAR(100),
                                            BrandName VARCHAR(100),
                                            Description TEXT,
                                            Price NUMERIC(10, 2),
                                            AvailabilityStatusName VARCHAR(50)
        );

        -- Step 3: Load data into the temporary table
        COPY temp_products(SKU, Name, CategoryName, BrandName, Description, Price, AvailabilityStatusName)
            FROM 'D:/csv/Products.csv'
            DELIMITER ',' CSV HEADER;

        -- Step 4: Deduplicate the temporary table
        DROP TABLE IF EXISTS temp_deduplicated_products;
        CREATE TEMP TABLE temp_deduplicated_products AS
        SELECT DISTINCT ON (SKU)
            SKU,
            Name,
            CategoryName,
            BrandName,
            Description,
            Price,
            AvailabilityStatusName
        FROM temp_products
        ORDER BY SKU,
                 CASE WHEN AvailabilityStatusName = 'In Stock' THEN 1 ELSE 2 END,
                 Price DESC;

        -- Step 5: Insert missing categories
        INSERT INTO Categories (Name)
        SELECT DISTINCT CategoryName
        FROM temp_deduplicated_products t
        WHERE NOT EXISTS (
            SELECT 1 FROM Categories c WHERE c.Name = t.CategoryName
        );

        -- Step 6: Insert missing brands
        INSERT INTO Brands (Name)
        SELECT DISTINCT BrandName
        FROM temp_deduplicated_products t
        WHERE NOT EXISTS (
            SELECT 1 FROM Brands b WHERE b.Name = t.BrandName
        );

        -- Step 7: Insert missing availability statuses
        INSERT INTO AvailabilityStatuses (AvailabilityStatusName)
        SELECT DISTINCT AvailabilityStatusName
        FROM temp_deduplicated_products t
        WHERE NOT EXISTS (
            SELECT 1 FROM AvailabilityStatuses a WHERE a.AvailabilityStatusName = t.AvailabilityStatusName
        );

        -- Step 8: Insert new rows into Products
        INSERT INTO Products (SKU, Name, CategoryID, BrandID, Description, Price, AvailabilityStatusID)
        SELECT
            t.SKU,
            t.Name,
            (SELECT CategoryID FROM Categories WHERE Name = t.CategoryName),
            (SELECT BrandID FROM Brands WHERE Name = t.BrandName),
            t.Description,
            t.Price,
            (SELECT AvailabilityStatusID FROM AvailabilityStatuses WHERE AvailabilityStatusName = t.AvailabilityStatusName)
        FROM temp_deduplicated_products t
        WHERE NOT EXISTS (
            SELECT 1 FROM Products p WHERE p.SKU = t.SKU
        );

        -- Step 9: Update existing rows in Products
        UPDATE Products
        SET
            Name = t.Name,
            Description = t.Description,
            Price = t.Price,
            AvailabilityStatusID = (SELECT AvailabilityStatusID FROM AvailabilityStatuses WHERE AvailabilityStatusName = t.AvailabilityStatusName),
            CategoryID = (SELECT CategoryID FROM Categories WHERE Name = t.CategoryName),
            BrandID = (SELECT BrandID FROM Brands WHERE Name = t.BrandName)
        FROM temp_deduplicated_products t
        WHERE Products.SKU = t.SKU;

        -- Step 10: Delete rows in Products not present in the CSV
        DELETE FROM Products
        WHERE SKU NOT IN (SELECT SKU FROM temp_deduplicated_products);

        -- Step 11: Drop the temporary tables
        DROP TABLE temp_products;
        DROP TABLE temp_deduplicated_products;
    END $$;

-- ProductProperties Table
DO $$
    BEGIN
        DROP TABLE IF EXISTS temp_productproperties;

        CREATE TEMP TABLE temp_productproperties (
                                                     SKU VARCHAR(50),
                                                     PropertyName VARCHAR(100),
                                                     PropertyValue VARCHAR(100)
        );

        COPY temp_productproperties(SKU, PropertyName, PropertyValue)
            FROM 'D:/csv/ProductProperties.csv'
            DELIMITER ',' CSV HEADER;

        INSERT INTO ProductProperties (ProductID, PropertyName, PropertyValue)
        SELECT
            p.ProductID,
            t.PropertyName,
            t.PropertyValue
        FROM temp_productproperties t
                 JOIN Products p ON t.SKU = p.SKU
        ON CONFLICT (ProductID, PropertyName) DO UPDATE
            SET PropertyValue = EXCLUDED.PropertyValue;

        DROP TABLE temp_productproperties;
    END $$;

--Promotions Table
DO $$
    BEGIN
        DROP TABLE IF EXISTS temp_promotions;

        CREATE TEMP TABLE temp_promotions (
                                              Code VARCHAR(50),
                                              DiscountPercent NUMERIC(5, 2),
                                              StartDate DATE,
                                              EndDate DATE,
                                              IsActive BOOLEAN
        );

        COPY temp_promotions(Code, DiscountPercent, StartDate, EndDate, IsActive)
            FROM 'D:/csv/Promotions.csv'
            DELIMITER ','
            CSV HEADER;

        INSERT INTO Promotions (Code, DiscountPercent, StartDate, EndDate, IsActive)
        SELECT t.Code, t.DiscountPercent, t.StartDate, t.EndDate, t.IsActive
        FROM temp_promotions t
        ON CONFLICT (Code) DO UPDATE
            SET DiscountPercent = EXCLUDED.DiscountPercent,
                StartDate = EXCLUDED.StartDate,
                EndDate = EXCLUDED.EndDate,
                IsActive = EXCLUDED.IsActive;

        DROP TABLE temp_promotions;
    END $$;

-- Orders Table
DO $$
    BEGIN
        DROP TABLE IF EXISTS temp_orders;

        CREATE TEMP TABLE temp_orders (
                                          Email VARCHAR(100),
                                          CreatedAt TIMESTAMP,
                                          PaymentMethodName VARCHAR(50),
                                          OrderStatusName VARCHAR(50),
                                          PromotionCode VARCHAR(50)
        );

        COPY temp_orders(Email, CreatedAt, PaymentMethodName, OrderStatusName, PromotionCode)
            FROM 'D:/csv/Orders.csv'
            DELIMITER ',' CSV HEADER;

        INSERT INTO Orders (UserID, CreatedAt, PaymentMethodID, OrderStatusID, PromotionID)
        SELECT
            u.UserID,
            t.CreatedAt,
            COALESCE((SELECT PaymentMethodID FROM PaymentMethods WHERE PaymentMethodName = t.PaymentMethodName), 1),
            COALESCE((SELECT OrderStatusID FROM OrderStatuses WHERE OrderStatusName = t.OrderStatusName), 1),
            (SELECT PromotionID FROM Promotions WHERE Code = t.PromotionCode)
        FROM temp_orders t
                 JOIN Users u ON t.Email = u.Email
        WHERE NOT EXISTS (
            SELECT 1 FROM Orders o WHERE o.UserID = u.UserID AND o.CreatedAt = t.CreatedAt
        );

        DROP TABLE temp_orders;
    END $$;

-- OrderDetails Table
DO $$
    BEGIN
        -- Step 1: Drop the temporary table if it exists
        DROP TABLE IF EXISTS temp_order_details;

        -- Step 2: Create a temporary table
        CREATE TEMP TABLE temp_order_details (
                                                 Email VARCHAR(100),
                                                 CreatedAt TIMESTAMP,
                                                 SKU VARCHAR(50),
                                                 Quantity INT
        );

        -- Step 3: Load data into the temporary table
        COPY temp_order_details(Email, CreatedAt, SKU, Quantity)
            FROM 'D:/csv/OrderDetails.csv'
            DELIMITER ',' CSV HEADER;

        -- Step 4: Insert rows into OrderDetails
        INSERT INTO OrderDetails (OrderID, ProductID, Quantity)
        SELECT
            o.OrderID,
            p.ProductID,
            t.Quantity
        FROM temp_order_details t
                 JOIN Orders o ON o.CreatedAt = t.CreatedAt
            AND o.UserID = (SELECT UserID FROM Users WHERE Email = t.Email)
                 JOIN Products p ON p.SKU = t.SKU
        WHERE NOT EXISTS (
            SELECT 1 FROM OrderDetails od
            WHERE od.OrderID = o.OrderID AND od.ProductID = p.ProductID
        );

        -- Step 5: Drop the temporary table
        DROP TABLE temp_order_details;
    END $$;

-- ETL for TotalAmount in Orders
DO $$
    BEGIN
        UPDATE Orders
        SET TotalAmount = subquery.TotalAmount
        FROM (
                 SELECT
                     od.OrderID,
                     COALESCE(SUM(od.Quantity * p.Price), 0) AS TotalAmount
                 FROM OrderDetails od
                          JOIN Products p ON od.ProductID = p.ProductID
                 GROUP BY od.OrderID
             ) subquery
        WHERE Orders.OrderID = subquery.OrderID;
    END $$;


-- Reviews Table
DO $$
    BEGIN
        -- Step 1: Drop the temporary table if it exists
        DROP TABLE IF EXISTS temp_reviews;

        -- Step 2: Create a temporary table
        CREATE TEMP TABLE temp_reviews (
                                           Email VARCHAR(100),
                                           SKU VARCHAR(50),
                                           Rating INT,
                                           Comment TEXT
        );

        -- Step 3: Load data into the temporary table
        COPY temp_reviews(Email, SKU, Rating, Comment)
            FROM 'D:/csv/Reviews.csv'
            DELIMITER ',' CSV HEADER;

        -- Step 4: Insert or update rows in the Reviews table
        INSERT INTO Reviews (UserID, ProductID, Rating, Comment)
        SELECT
            u.UserID,
            p.ProductID,
            t.Rating,
            t.Comment
        FROM temp_reviews t
                 JOIN Users u ON t.Email = u.Email
                 JOIN Products p ON t.SKU = p.SKU
        WHERE NOT EXISTS (
            SELECT 1
            FROM Reviews r
            WHERE r.UserID = u.UserID
              AND r.ProductID = p.ProductID
              AND r.Rating = t.Rating
              AND r.Comment = t.Comment
        );

        -- Step 5: Drop the temporary table
        DROP TABLE temp_reviews;
    END $$;
