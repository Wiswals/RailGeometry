DECLARE @StartTimestamp DATETIME = CONVERT(DATETIME, '2023-08-01 00:00:00', 120); -- ISO format
DECLARE @EndTimestamp DATETIME = CONVERT(DATETIME, '2025-08-31 23:59:59', 120);   -- ISO format
DECLARE @TrackCode VARCHAR(100) = 'QRD';                                          -- Set your track code
DECLARE @TrackSection VARCHAR(100) = '65590-65835';                               -- Set your track section
DECLARE @ChainageStep INT = 3;                                                    -- Set your chainage step (e.g., 3 for every 3rd meter)

-- Select statement to retrieve filtered data
SELECT 
    Geometry_Instrument, Calculation_Epoch, Rail_Cant, Rail_Gauge, Twist_Short, Twist_Long, CL_Radius, CL_Top_Short,
    CL_Top_Long, CL_Line_Short, CL_Line_Long, Calculation_Comment, Prism_Inputs
FROM 
    GeometryData
WHERE 
    [Calculation_Epoch] BETWEEN @StartTimestamp AND @EndTimestamp
    AND [Track_Code] = @TrackCode
    AND [Track_Section] LIKE '%' + @TrackSection + '%'
    AND FLOOR([Calculation_Chainage] / @ChainageStep) = [Calculation_Chainage] / @ChainageStep -- Only return rows where the chainage is a multiple of the step
ORDER BY 
   [Calculation_Epoch], [Geometry_Instrument];
