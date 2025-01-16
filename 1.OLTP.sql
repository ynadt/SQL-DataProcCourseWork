-- Addresses Table
CREATE TABLE Addresses (
                           AddressID SERIAL PRIMARY KEY,
                           AddressLine VARCHAR(255) NOT NULL,
                           City VARCHAR(50) NOT NULL,
                           State VARCHAR(50),
                           Country VARCHAR(50) NOT NULL,
                           PostalCode VARCHAR(20) NOT NULL,
                           CONSTRAINT uq_address UNIQUE (AddressLine, City, State, Country, PostalCode)
);

-- Users Table
CREATE TABLE Users (
                       UserID SERIAL PRIMARY KEY, -- Surrogate key
                       Email VARCHAR(100) NOT NULL UNIQUE, -- Business key
                       FirstName VARCHAR(50) NOT NULL,
                       LastName VARCHAR(50) NOT NULL,
                       PhoneNumber VARCHAR(15),
                       AddressID INT NOT NULL,
                       FOREIGN KEY (AddressID) REFERENCES Addresses(AddressID)
);

-- Categories Table
CREATE TABLE Categories (
                            CategoryID SERIAL PRIMARY KEY,
                            Name VARCHAR(100) NOT NULL UNIQUE,
                            ParentCategoryID INT,
                            FOREIGN KEY (ParentCategoryID) REFERENCES Categories(CategoryID),
                            CONSTRAINT chk_no_self_reference CHECK (CategoryID <> ParentCategoryID)
);

-- Brands Table
CREATE TABLE Brands (
                        BrandID SERIAL PRIMARY KEY,
                        Name VARCHAR(100) NOT NULL UNIQUE,
                        Description TEXT
);

-- PaymentMethods Table
CREATE TABLE PaymentMethods (
                                PaymentMethodID SERIAL PRIMARY KEY,
                                PaymentMethodName VARCHAR(50) NOT NULL UNIQUE
);

-- OrderStatuses Table
CREATE TABLE OrderStatuses (
                               OrderStatusID SERIAL PRIMARY KEY,
                               OrderStatusName VARCHAR(50) NOT NULL UNIQUE
);

-- AvailabilityStatuses Table
CREATE TABLE AvailabilityStatuses (
                                      AvailabilityStatusID SERIAL PRIMARY KEY,
                                      AvailabilityStatusName VARCHAR(50) NOT NULL UNIQUE
);

-- Products Table
CREATE TABLE Products (
                          ProductID SERIAL PRIMARY KEY,
                          SKU VARCHAR(50) NOT NULL UNIQUE,
                          Name VARCHAR(100) NOT NULL,
                          CategoryID INT NOT NULL,
                          BrandID INT NOT NULL,
                          Description TEXT,
                          Price NUMERIC(10, 2) NOT NULL CHECK (Price > 0),
                          AvailabilityStatusID INT NOT NULL,
                          FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID),
                          FOREIGN KEY (BrandID) REFERENCES Brands(BrandID),
                          FOREIGN KEY (AvailabilityStatusID) REFERENCES AvailabilityStatuses(AvailabilityStatusID)
);

-- ProductProperties Table
CREATE TABLE ProductProperties (
                                   PropertyID SERIAL PRIMARY KEY,
                                   ProductID INT NOT NULL,
                                   PropertyName VARCHAR(100) NOT NULL,
                                   PropertyValue VARCHAR(100) NOT NULL,
                                   FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
                                   CONSTRAINT uq_product_properties UNIQUE (ProductID, PropertyName)
);

-- Promotions Table
CREATE TABLE Promotions (
                            PromotionID SERIAL PRIMARY KEY,
                            Code VARCHAR(50) UNIQUE NOT NULL,
                            DiscountPercent NUMERIC(5, 2) NOT NULL CHECK (DiscountPercent BETWEEN 0 AND 100),
                            StartDate DATE NOT NULL,
                            EndDate DATE NOT NULL,
                            IsActive BOOLEAN DEFAULT TRUE
);

-- Orders Table
CREATE TABLE Orders (
                        OrderID SERIAL PRIMARY KEY,
                        UserID INT NOT NULL,
                        CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        PaymentMethodID INT NOT NULL DEFAULT 1,
                        OrderStatusID INT NOT NULL DEFAULT 1,
                        PromotionID INT,
                        TotalAmount NUMERIC(10, 2) NOT NULL DEFAULT 0,
                        FOREIGN KEY (UserID) REFERENCES Users(UserID),
                        FOREIGN KEY (PaymentMethodID) REFERENCES PaymentMethods(PaymentMethodID),
                        FOREIGN KEY (OrderStatusID) REFERENCES OrderStatuses(OrderStatusID),
                        FOREIGN KEY (PromotionID) REFERENCES Promotions(PromotionID),
                        CONSTRAINT uq_orders_user_created_at UNIQUE (UserID, CreatedAt)
);



-- OrderDetails Table
CREATE TABLE OrderDetails (
                              OrderDetailID SERIAL PRIMARY KEY,
                              OrderID INT NOT NULL,
                              ProductID INT NOT NULL,
                              Quantity INT NOT NULL CHECK (Quantity > 0),
                              FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
                              FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);

-- Reviews Table
CREATE TABLE Reviews (
                         ReviewID SERIAL PRIMARY KEY,
                         UserID INT NOT NULL,
                         ProductID INT NOT NULL,
                         Rating INT NOT NULL CHECK (Rating BETWEEN 1 AND 5),
                         Comment TEXT,
                         FOREIGN KEY (UserID) REFERENCES Users(UserID),
                         FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);

