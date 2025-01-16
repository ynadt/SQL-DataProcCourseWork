CREATE OR REPLACE VIEW vw_CombinedPerformance AS
WITH AggregatedOrderDetails AS (
    SELECT
        fod.SalesKey,
        SUM(fod.Quantity) AS TotalItemsSoldPerOrder,
        SUM(fod.LineTotal) AS RevenuePerOrder
    FROM FactOrderDetails fod
    GROUP BY fod.SalesKey
)
SELECT
    -- FactSales details
    fs.SalesKey,
    fs.OrderID,
    dt.TimeKey AS OrderDate,
    dt.Year AS OrderYear,
    dt.Quarter AS OrderQuarter,
    dt.Month AS OrderMonth,
    dt.Week AS OrderWeek,
    fs.TotalQuantity AS TotalQuantitySold,
    fs.TotalRevenue AS TotalRevenue,
    fs.TotalDiscount AS TotalDiscount,

    -- Payment method and order status
    dpm.PaymentMethodName,
    dos.OrderStatusName,

    -- Aggregated product performance
    fod.TotalItemsSoldPerOrder,
    fod.RevenuePerOrder,

    -- Promotion metrics
    dpromo.PromotionName,
    dpromo.DiscountPercent,
    dpromo.StartDate AS PromotionStartDate,
    dpromo.EndDate AS PromotionEndDate,
    CASE WHEN dpromo.IsActive THEN 'Active' ELSE 'Inactive' END AS PromotionStatus,
    fpe.TotalCustomers AS PromotionTotalCustomers,
    fpe.TotalOrders AS PromotionTotalOrders,
    fpe.TotalRevenue AS PromotionTotalRevenue,
    fpe.TotalDiscount AS PromotionTotalDiscount,
    fpe.TotalQuantity AS PromotionTotalQuantity

FROM FactSales fs
         -- Time dimension
         JOIN DimTime dt ON fs.OrderDateKey = dt.TimeKey

    -- Payment method dimension
         JOIN DimPaymentMethod dpm ON fs.PaymentMethodKey = dpm.PaymentMethodKey

    -- Order status dimension
         JOIN DimOrderStatus dos ON fs.OrderStatusKey = dos.OrderStatusKey

    -- Aggregated FactOrderDetails
         LEFT JOIN AggregatedOrderDetails fod ON fs.SalesKey = fod.SalesKey

    -- Promotion and promotion effectiveness
         LEFT JOIN DimPromotion dpromo ON fs.OrderID = dpromo.PromotionID
         LEFT JOIN FactPromotionEffectiveness fpe ON dpromo.PromotionKey = fpe.PromotionKey;
