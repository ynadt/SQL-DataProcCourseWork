-- DimAddress Table
CREATE TABLE IF NOT EXISTS DimAddress (
                                          AddressKey SERIAL PRIMARY KEY,
                                          AddressID INT NOT NULL UNIQUE,
                                          AddressLine VARCHAR(255),
                                          City VARCHAR(50),
                                          State VARCHAR(50),
                                          Country VARCHAR(50),
                                          PostalCode VARCHAR(20)
);

-- DimCustomer Table
CREATE TABLE IF NOT EXISTS DimCustomer (
                                           CustomerKey SERIAL PRIMARY KEY,
                                           Email VARCHAR(100) NOT NULL,
                                           CustomerFullName VARCHAR(101),
                                           PhoneNumber VARCHAR(15),
                                           AddressKey INT,
                                           RecordStartDate TIMESTAMP NOT NULL,
                                           RecordEndDate TIMESTAMP,
                                           IsActive BOOLEAN NOT NULL DEFAULT TRUE,
                                           FOREIGN KEY (AddressKey) REFERENCES DimAddress(AddressKey),
                                           CONSTRAINT uq_customer UNIQUE (Email, RecordStartDate)
);

-- DimTime Table
CREATE TABLE IF NOT EXISTS DimTime (
                                       TimeKey DATE PRIMARY KEY,
                                       Year INT NOT NULL,
                                       Quarter INT NOT NULL,
                                       Month INT NOT NULL,
                                       Day INT NOT NULL,
                                       Week INT NOT NULL
);

-- DimCategory Table
CREATE TABLE IF NOT EXISTS DimCategory (
                                           CategoryKey SERIAL PRIMARY KEY,
                                           CategoryID INT NOT NULL,
                                           CategoryName VARCHAR(100),
                                           ParentCategoryKey INT,
                                           FOREIGN KEY (ParentCategoryKey) REFERENCES DimCategory(CategoryKey),
                                           CONSTRAINT uq_categoryid UNIQUE (CategoryID)
);

-- DimBrand Table
CREATE TABLE IF NOT EXISTS DimBrand (
                                        BrandKey SERIAL PRIMARY KEY,
                                        BrandID INT NOT NULL,
                                        BrandName VARCHAR(100),
                                        BrandDescription TEXT,
                                        CONSTRAINT uq_brandid UNIQUE (BrandID)
);

-- DimAvailabilityStatus Table
CREATE TABLE IF NOT EXISTS DimAvailabilityStatus (
                                                     AvailabilityStatusKey SERIAL PRIMARY KEY,
                                                     AvailabilityStatusName VARCHAR(50) NOT NULL UNIQUE

);

-- DimProduct Table
CREATE TABLE IF NOT EXISTS DimProduct (
                                          ProductKey SERIAL PRIMARY KEY,
                                          ProductID INT NOT NULL,
                                          ProductName VARCHAR(100),
                                          CategoryKey INT NOT NULL,
                                          BrandKey INT NOT NULL,
                                          CurrentPrice NUMERIC(10, 2) NOT NULL,
                                          AvailabilityStatusKey INT NOT NULL,
                                          RecordStartDate TIMESTAMP NOT NULL,
                                          RecordEndDate TIMESTAMP,
                                          IsActive BOOLEAN NOT NULL DEFAULT TRUE,
                                          FOREIGN KEY (CategoryKey) REFERENCES DimCategory(CategoryKey),
                                          FOREIGN KEY (BrandKey) REFERENCES DimBrand(BrandKey),
                                          FOREIGN KEY (AvailabilityStatusKey) REFERENCES DimAvailabilityStatus(AvailabilityStatusKey),
                                          CONSTRAINT uq_productid UNIQUE (ProductID, RecordStartDate)
);

-- DimPromotion Table
CREATE TABLE IF NOT EXISTS DimPromotion (
                                            PromotionKey SERIAL PRIMARY KEY,
                                            PromotionID INT NOT NULL,
                                            PromotionName VARCHAR(100),
                                            DiscountPercent NUMERIC(5, 2) NOT NULL,
                                            StartDate DATE NOT NULL,
                                            EndDate DATE NOT NULL,
                                            IsActive BOOLEAN DEFAULT TRUE,
                                            CONSTRAINT uq_promotionid UNIQUE (PromotionID)
);

-- DimPaymentMethod Table
CREATE TABLE IF NOT EXISTS DimPaymentMethod (
                                                PaymentMethodKey SERIAL PRIMARY KEY,
                                                PaymentMethodName VARCHAR(50) NOT NULL UNIQUE
);


-- DimOrderStatus Table
CREATE TABLE IF NOT EXISTS DimOrderStatus (
                                              OrderStatusKey SERIAL PRIMARY KEY,
                                              OrderStatusName VARCHAR(50) NOT NULL UNIQUE
);

-- FactSales Table
CREATE TABLE IF NOT EXISTS FactSales (
                                         SalesKey SERIAL PRIMARY KEY,
                                         OrderID INT NOT NULL UNIQUE,
                                         OrderDateKey DATE NOT NULL,
                                         CustomerKey INT NOT NULL,
                                         PaymentMethodKey INT NOT NULL,
                                         OrderStatusKey INT NOT NULL,
                                         TotalQuantity INT NOT NULL, -- Total quantity of items in the order
                                         TotalRevenue NUMERIC(12, 2) NOT NULL, -- Total revenue (after discounts)
                                         TotalDiscount NUMERIC(12, 2) NOT NULL, -- Total discount applied to the order
                                         FOREIGN KEY (OrderDateKey) REFERENCES DimTime(TimeKey),
                                         FOREIGN KEY (CustomerKey) REFERENCES DimCustomer(CustomerKey),
                                         FOREIGN KEY (PaymentMethodKey) REFERENCES DimPaymentMethod(PaymentMethodKey),
                                         FOREIGN KEY (OrderStatusKey) REFERENCES DimOrderStatus(OrderStatusKey)
);

-- FactOrderDetails Table
CREATE TABLE IF NOT EXISTS FactOrderDetails (
                                                OrderDetailKey SERIAL PRIMARY KEY,
                                                SalesKey INT NOT NULL,
                                                ProductKey INT NOT NULL,
                                                Quantity INT NOT NULL, -- Quantity of this product in the order
                                                UnitPrice NUMERIC(12, 2) NOT NULL, -- Price per unit at the time of the order
                                                LineTotal NUMERIC(12, 2) NOT NULL, -- Total for this line (Quantity * UnitPrice)
                                                FOREIGN KEY (SalesKey) REFERENCES FactSales(SalesKey),
                                                FOREIGN KEY (ProductKey) REFERENCES DimProduct(ProductKey),
                                                CONSTRAINT uq_sales_product UNIQUE (SalesKey, ProductKey)
);

-- FactPromotionEffectiveness Table
CREATE TABLE IF NOT EXISTS FactPromotionEffectiveness (
                                                          PromotionKey INT PRIMARY KEY,
                                                          StartDateKey DATE NOT NULL,
                                                          EndDateKey DATE NOT NULL,
                                                          TotalCustomers INT NOT NULL, -- Number of unique customers
                                                          TotalOrders INT NOT NULL, -- Number of orders
                                                          TotalRevenue NUMERIC(12, 2) NOT NULL, -- Revenue generated
                                                          TotalDiscount NUMERIC(12, 2) NOT NULL, -- Total discount offered
                                                          TotalQuantity INT NOT NULL, -- Quantity of items sold
                                                          FOREIGN KEY (PromotionKey) REFERENCES DimPromotion(PromotionKey),
                                                          FOREIGN KEY (StartDateKey) REFERENCES DimTime(TimeKey),
                                                          FOREIGN KEY (EndDateKey) REFERENCES DimTime(TimeKey)
);