/***************************************************************************************************
Procedure:          InitialiseTrackGeometry
Create Date:        2019-09-13
Author:             Lewis Walsh
Description:        This script adds functions to a GeoMoS database and creates a new 'TrackGeometry' 
                    database with tables needed for track geometry calculations. The script is designed 
                    for automated calculations and storing results related to track geometry.
                    Run the script on the target database for computations.
Affected table(s):  [dbo.TrackListing], [dbo.GeometryHistory], [dbo.ReportingData], [dbo.PrismHistory]
Affected function:  [dbo.ParseString], [dbo.BearingandDistance]
Used By:            Master script for track geometry calculations.
Usage:              Execute once at the setup stage. Can be rerun for additional databases without 
                    affecting the existing TrackGeometry database.
****************************************************************************************************
SUMMARY OF CHANGES
Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------- ------------------------------------------------------------
2019-09-13          Lewis Walsh         Added commenting and headers for all creation/deletion 
                                        sections.
2019-09-13          Lewis Walsh         Updated 'ParseString' function to return NULL for non-matches.
2019-09-21          Lewis Walsh         Created [dbo.SelectToHTML] for formatted HTML table output.
2019-09-21          Lewis Walsh         Added [dbo.ReportingData] for combined prism and geometry 
                                        data for reporting.
2024-11-14          Lewis Walsh         Optimized functions for performance and added table indexes.
2024-11-14          Lewis Walsh         Added [Track_Section], [Start_Chainage], and [End_Chainage] 
                                        columns to TrackListing table and created corresponding indexes.
2024-11-14          Lewis Walsh         Added logic to delete existing functions and procedures 
                                        before recreating them to avoid errors.
2024-11-20          Lewis Walsh         Further optimized ParseString logic to handle FLOAT, INT, 
                                        and VARCHAR returns using SQL_VARIANT. Updated to ensure 
                                        compatibility with SQL_VARIANT limitations.
***************************************************************************************************/


SET DATEFORMAT dmy;  -- Set the date format to day/month/year
SET XACT_ABORT ON;   -- Abort the transaction if an error occurs
SET NOCOUNT ON;      -- Prevents extra result sets from being sent to the client
SET ANSI_WARNINGS ON; -- Enable ANSI warnings for proper error handling

-- Inform the user which database the script is being run against
PRINT CONVERT(varchar, GETDATE(),103) + ' ' + CONVERT(varchar, GETDATE(), 14)  + ' | Starting initialisation script.'
PRINT CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Running script on database: ' + DB_NAME();

---------------------------------------- BearingandDistance Function ------------------------------------------------
-- Function to calculate the bearing and distance between two coordinate points

-- Drop the BearingandDistance function if it exists
DROP FUNCTION IF EXISTS [dbo].BearingandDistance;
GO

-- Create a new version of the BearingandDistance function
CREATE FUNCTION [dbo].BearingandDistance (@EastAt FLOAT, @NorthAt FLOAT, @EastTo FLOAT, @NorthTo FLOAT) 
RETURNS @t TABLE (Bearing FLOAT, Distance FLOAT)
AS
BEGIN
    DECLARE @Bearing FLOAT, @Distance FLOAT, @dE FLOAT, @dN FLOAT;

    -- Calculate differences in Easting and Northing only once
    SET @dE = @EastTo - @EastAt;
    SET @dN = @NorthTo - @NorthAt;

    -- Compute the distance using Pythagoras' theorem
    SET @Distance = SQRT(@dE * @dE + @dN * @dN);

    -- Calculate the bearing using ATN2 for accurate quadrant handling
    SET @Bearing = CASE
        WHEN @dN = 0 THEN 0
        ELSE ATN2(@dE, @dN)
    END;

    -- Adjust the bearing to ensure it falls within the range [0, 2*PI)
    IF @Bearing < 0 SET @Bearing = @Bearing + 2 * PI();

    -- Insert the results into the table variable
    INSERT INTO @t VALUES (@Bearing, @Distance);
    RETURN;
END;
GO
PRINT CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | BearingandDistance function created.';

------------------------------------------------ Parse String Function------------------------------------------------
-- Function to parse a given string and extract a value based on a search term and desired data type

-- Drop the ParseString function if it exists
DROP FUNCTION IF EXISTS [dbo].ParseString;
GO

-- Create a new version of the ParseString function
CREATE FUNCTION [dbo].ParseString (
    @String VARCHAR(MAX), 
    @Search VARCHAR(100),
    @DataType VARCHAR(50)
) RETURNS VARCHAR(MAX)
AS
BEGIN
    DECLARE @ix1 INT, @ix2 INT;
    DECLARE @SubString VARCHAR(100);

    -- Locate the position of the search term within the string
    SET @ix1 = CHARINDEX(@Search, @String);
    IF @ix1 > 0
    BEGIN
        -- Find the position of the next space after the search term
        SET @ix2 = CHARINDEX(' ', @String + ' ', @ix1 + LEN(@Search));  -- Adding ' ' ensures CHARINDEX always finds a space
        IF @ix2 = 0 SET @ix2 = LEN(@String) + 1;  -- If no space is found, assume the end of the string

        -- Extract the substring without any spaces after the search term
        SET @SubString = LTRIM(RTRIM(SUBSTRING(@String, @ix1 + LEN(@Search), @ix2 - @ix1 - LEN(@Search))));
    END
    ELSE
        SET @SubString = NULL;

    -- Convert the extracted substring to the specified data type and return as VARCHAR
    RETURN CASE
        WHEN @DataType = 'int' AND TRY_CAST(@SubString AS INT) IS NOT NULL THEN @SubString
        WHEN @DataType = 'float' AND TRY_CAST(@SubString AS FLOAT) IS NOT NULL THEN @SubString
        WHEN @DataType = 'decimal' AND TRY_CAST(@SubString AS DECIMAL(38,10)) IS NOT NULL THEN @SubString
        WHEN @DataType = 'datetime' AND TRY_CAST(@SubString AS DATETIME) IS NOT NULL THEN @SubString
        ELSE @SubString
    END;
END;
GO

PRINT CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | ParseString function created.';



---------------------------------------------- Create TrackGeometry Database ----------------------------------------------
-- Check if the TrackGeometry database exists and create it if it does not

IF DB_ID('Automated Track Geometry') IS NULL
BEGIN
    CREATE DATABASE [Automated Track Geometry];  -- Create the TrackGeometry database
    PRINT CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Automated Track Geometry database created.';
END;
GO
PRINT CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Automated Track Geometry database initialization checked.';

USE [Automated Track Geometry];  -- Switch to the TrackGeometry database

---------------------------------------------- Create TrackListing Table ----------------------------------------------
-- Create the TrackListing table if it does not already exist

IF OBJECT_ID(N'dbo.TrackListing', N'U') IS NULL
BEGIN
    CREATE TABLE TrackListing (
        [ID] INT IDENTITY(1,1) PRIMARY KEY,  -- Primary key with auto-increment
        [Track_Name] VARCHAR(255),  -- Name of the track
        [Track_Code] VARCHAR(127),  -- Code for the track
        [Track_Section] VARCHAR(127),  -- Section identifier for the track
        [Track_Details] VARCHAR(MAX),  -- Detailed description of the track
        [Start_Chainage] DECIMAL(18, 6),  -- Start chainage as a decimal
        [End_Chainage] DECIMAL(18, 6),  -- End chainage as a decimal
        [Calculation_Status] BIT,  -- Status of geometry calculations (0 or 1)
        [Expected_Database] VARCHAR(255),  -- Expected database name
        [Calculation_Time] DATETIME  -- Time of the calculation        
    );

    -- Create a composite index for efficient range queries on Start_Chainage and End_Chainage
    CREATE INDEX IX_TrackListing_Chainage ON TrackListing(Start_Chainage, End_Chainage);

    CREATE INDEX IX_TrackListing_Code ON TrackListing(Track_Code);
    CREATE INDEX IX_TrackListing_Section ON TrackListing(Track_Section);  -- Index for quick access by section

    PRINT CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | TrackListing table created with additional columns and composite index.';
END;


---------------------------------------------- Create GeometryHistory Table ----------------------------------------------
-- Used for storing all historic calculations of track geometry parameters. Can be linked to the PrismHistory table via the [Calculation_ID] column.
IF OBJECT_ID(N'dbo.GeometryHistory', N'U') IS NULL
BEGIN
    CREATE TABLE GeometryHistory (
        [Calculation_ID] INT, 
        [Track_CL_Chainage] DECIMAL(20,6),  -- Reduced precision for efficiency if higher precision is not necessary
        [Track_Code] VARCHAR(100) NULL, 
        [DataWindow_Start] DATETIME, 
        [DataWindow_End] DATETIME,
        [Rail_Cant] DECIMAL(10,4), 
        [Rail_Gauge] DECIMAL(10,4), 
        [Twist_Short] DECIMAL(20,6), 
        [Twist_Long] DECIMAL(10,4),
        [LR_ID] VARCHAR(100), 
        [LR_Easting] DECIMAL(10,4), 
        [LR_Northing] DECIMAL(10,4), 
        [LR_Height] DECIMAL(10,4), 
        [LR_Radius] DECIMAL(10,4), 
        [LR_Top_Short] DECIMAL(10,4), 
        [LR_Top_Long] DECIMAL(10,4), 
        [LR_Line_Short] DECIMAL(10,4),
        [LR_Line_Long] DECIMAL(10,4), 
        [RR_ID] VARCHAR(100), 
        [RR_Easting] DECIMAL(10,4), 
        [RR_Northing] DECIMAL(10,4), 
        [RR_Height] DECIMAL(10,4), 
        [RR_Radius] DECIMAL(10,4), 
        [RR_Top_Short] DECIMAL(10,4), 
        [RR_Top_Long] DECIMAL(10,4),
        [RR_Line_Short] DECIMAL(10,4), 
        [RR_Line_Long] DECIMAL(10,4), 
        [CL_ID] VARCHAR(100), 
        [CL_Easting] DECIMAL(10,4),
        [CL_Northing] DECIMAL(10,4), 
        [CL_Height] DECIMAL(10,4), 
        [CL_Radius] DECIMAL(10,4), 
        [CL_Top_Short] DECIMAL(10,4),
        [CL_Top_Long] DECIMAL(10,4), 
        [CL_Line_Short] DECIMAL(10,4), 
        [CL_Line_Long] DECIMAL(10,4), 
        [Diff_Chainage_Left] DECIMAL(10,4), 
        [Diff_Chainage_Rght] DECIMAL(10,4), 
        [Calculation_Comment] VARCHAR(MAX)
    );
    PRINT CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | GeometryHistory table created.';
END;

---------------------------------------------- Create ReportingData Table ----------------------------------------------
-- A combination of the PrismHistory and GeometryHistory tables stored at runtime. Used to store original prism locations and track geometry results at the nearest chainage.
IF OBJECT_ID(N'dbo.ReportingData', N'U') IS NULL
BEGIN
    CREATE TABLE ReportingData (
        [Calculation_ID] INT, 
        [Parent_Instrument] VARCHAR(200), 
        [Geometry_Instrument] VARCHAR(200), 
        [Point_Chainage] DECIMAL(10,4), 
        [Calculation_Chainage] DECIMAL(10,4), 
        [Chainage_Diff] DECIMAL(10,4), 
        [Point_Epoch] DATETIME,
        [Calculation_Epoch] DATETIME, 
        [Epoch_Diff] DECIMAL(10,4), 
        [Rail_Cant] DECIMAL(10,4), 
        [Rail_Gauge] DECIMAL(10,4), 
        [Twist_Short] DECIMAL(20,6), 
        [Twist_Long] DECIMAL(10,4), 
        [LR_ID] VARCHAR(100), 
        [LR_Easting] DECIMAL(10,4), 
        [LR_Northing] DECIMAL(10,4), 
        [LR_Height] DECIMAL(10,4), 
        [LR_Radius] DECIMAL(10,4), 
        [LR_Top_Short] DECIMAL(10,4), 
        [LR_Top_Long] DECIMAL(10,4), 
        [LR_Line_Short] DECIMAL(10,4), 
        [LR_Line_Long] DECIMAL(10,4), 
        [RR_ID] VARCHAR(100), 
        [RR_Easting] DECIMAL(10,4), 
        [RR_Northing] DECIMAL(10,4), 
        [RR_Height] DECIMAL(10,4), 
        [RR_Radius] DECIMAL(10,4), 
        [RR_Top_Short] DECIMAL(10,4), 
        [RR_Top_Long] DECIMAL(10,4), 
        [RR_Line_Short] DECIMAL(10,4), 
        [RR_Line_Long] DECIMAL(10,4), 
        [CL_ID] VARCHAR(100), 
        [CL_Easting] DECIMAL(10,4), 
        [CL_Northing] DECIMAL(10,4), 
        [CL_Height] DECIMAL(10,4), 
        [CL_Radius] DECIMAL(10,4), 
        [CL_Top_Short] DECIMAL(10,4), 
        [CL_Top_Long] DECIMAL(10,4), 
        [CL_Line_Short] DECIMAL(10,4), 
        [CL_Line_Long] DECIMAL(10,4), 
        [Diff_Chainage_Left] DECIMAL(10,4), 
        [Diff_Chainage_Rght] DECIMAL(10,4), 
        [Calculation_Comment] VARCHAR(MAX)
    );
    PRINT CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | ReportingData table created.';
END;

---------------------------------------------- Create PrismHistory Table ----------------------------------------------
-- Used for storing all historic prism data used for interpolation and computation of track geometry parameters. Can be linked to GeometryHistory via the [Calculation_ID] column.
IF OBJECT_ID(N'dbo.PrismHistory', N'U') IS NULL
BEGIN
    CREATE TABLE PrismHistory (
        [Calculation_ID] INT, 
        [Point_Name] NVARCHAR(100) NULL, 
        [Point_Epoch] DATETIME NULL, 
        [Point_Group] NVARCHAR(100) NULL, 
        [Point_ExpTime_DD] DECIMAL(10,4) NULL, 
        [Point_ExpTime_DHM] VARCHAR(100) NULL, 
        [Point_Easting] DECIMAL(20,6) NULL,
        [Point_Northing] DECIMAL(20,6) NULL, 
        [Point_Height] DECIMAL(20,6) NULL, 
        [Point_EOffset] DECIMAL(20,6) NULL, 
        [Point_NOffset] DECIMAL(20,6) NULL,
        [Point_HOffset] DECIMAL(20,6) NULL, 
        [Track_Chainage] DECIMAL(20,6) NULL, 
        [Track_RailSide] NVARCHAR(50) NULL, 
        [Track_Code] NVARCHAR(100) NULL,
        [Track_Easting] DECIMAL(20,6) NULL, 
        [Track_Northing] DECIMAL(20,6) NULL, 
        [Track_Height] DECIMAL(20,6) NULL
    );
    PRINT CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | PrismHistory table created.';
END;



-- Final message indicating the script has completed
PRINT CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Initialisation script finished.';
