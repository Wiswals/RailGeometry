/***************************************************************************************************
Procedure:          InitialiseTrackGeometry
Create Date:        2019-09-13
Author:             Lewis Walsh
Description:        Run this script to add functions to a chosen GeoMoS database and to create a
					new 'TrackGeometry' database with the necessary tables for track geometry
					calculations. Please run this script on the database which you would like to 
					perform automated track geometry calculations on.
Affected table(s):  [dbo.TrackListing]
					[dbo.GeometryHistory]
					[dbo.PrismHistory]
Affected function:  [dbo.ParseString]
					[dbo.BearingandDistance]
					[dbo.MidOrdinate]
Used By:            Master script which runs all calculations of track geometry. Functions used for
					computations, database and tables used for storing the results.
Usage:              Run once at setup stage to create and add all required functions to a chosen 
					GeoMoS database. If functions are required on an additional database on 
					the same server, script can be run again without affecting the exsiting TrackGeometry
					database.
****************************************************************************************************
SUMMARY OF CHANGES
Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------- ------------------------------------------------------------
2019-09-13          Lewis Walsh			Added commenting and headers to all creation/deletion 
										sections.
2018-03-22          Maan Widaplan       General formatting and added header information.
2018-03-22          Maan Widaplan       Added logic to automatically Move G <-> H after 12 months.
***************************************************************************************************/

------------------------------------------------ Parse String Function------------------------------------------------
-- Interrogates and returns character values in a given String using the provided Search values

IF OBJECT_ID (N'dbo.ParseString', N'FN') IS NOT NULL
	DROP FUNCTION ParseString;
GO

CREATE FUNCTION [dbo].ParseString (@String varchar(max), @Search varchar(3)) RETURNS float
AS
	BEGIN
          DECLARE @ix1 int, @ix2 int,  @lx1 int
		  
          SET @lx1 = LEN(@Search)
		  SET @ix1 = CHARINDEX(@Search,@String,0)
		  SET @ix2 = CHARINDEX(' ',@String,@ix1+@lx1 )
		  IF @ix2=0 SET @ix2=99

          RETURN convert(float,SUBSTRING(@String, @ix1 + @lx1, @ix2-(@ix1 + @lx1)))
    END
GO

---------------------------------------- BearingandDistance Function ------------------------------------------------
--Calculations for Bearing and Distance between given points (EastAt, NorthAt, EastTo, NorthTo)

IF OBJECT_ID (N'dbo.BearingandDistance') IS NOT NULL
	DROP FUNCTION [dbo].BearingandDistance;
GO

CREATE FUNCTION [dbo].BearingandDistance (@EastAt float, @NorthAt float, @EastTo float, @NorthTo float) RETURNS @t TABLE (Bearing float, Distance float)
AS
	BEGIN
		DECLARE @Bearing float
		DECLARE @Distance float
		DECLARE @dE float,@dN float

		SET @dE = @EastTo - @EastAt
		SET @dN = @NorthTo - @NorthAt
		SET @Distance = SQRT(@dE * @dE + @dN * @dN)
		IF @dN =0
			SET @Bearing = 0;
		ELSE
			SET @Bearing = ATAN(@dE/@dN);

		IF @dE < 0 
			SET @Bearing = @Bearing + 2 * PI()
		IF @dN <0
			SET @Bearing = @Bearing + PI()
		IF @Bearing >= 2* PI()
			SET @Bearing = @Bearing - 2*PI()
		INSERT INTO @t VALUES (@Bearing,@Distance)

		RETURN 
	END
GO

------------------------------------------------ MidOrdinate Function ------------------------------------------------
--Calculated the middle ordinate value (vertical or horizontal) on a curve defined by a start, middle and end coordinate.
IF OBJECT_ID (N'dbo.MidOrdinate', N'FN') IS NOT NULL
	DROP FUNCTION [dbo].MidOrdinate;
GO

CREATE FUNCTION [dbo].MidOrdinate (@East_Start float, @North_Start float, @East_Mid float, @North_Mid float, @East_End float, @North_End float) RETURNS float
AS
    BEGIN
		DECLARE @BearingLongChord float
		DECLARE @BearingMidChord float
		DECLARE @DistanceMidChord float
		DECLARE @dAngle float

		SELECT @BearingLongChord=Bearing  from dbo.BandD(@East_Start,@North_Start,@East_End,@North_End)
		SELECT @BearingMidChord=Bearing,@DistanceMidChord=Distance  from dbo.BandD(@East_Start,@North_Start,@East_Mid,@North_Mid)
		SET @dAngle = @BearingLongChord-@BearingMidChord

		RETURN  Sin(@dAngle)*@DistanceMidChord
	END
GO


------------------------------------------------ Create TrackGeometry ------------------------------------------------
--Used databse for all the track geometry calculations
IF DB_ID ('TrackGeometry') IS NULL
CREATE DATABASE TrackGeometry;
GO

USE [TrackGeometry]

---------------------------------------------- Create TrackListing Table ----------------------------------------------
--Used for storing track details of each rail line which requires geometry calculations
IF OBJECT_ID (N'dbo.TrackListing', N'U') IS NULL
BEGIN
CREATE TABLE	TrackListing		([ID] int IDENTITY(1,1) PRIMARY KEY, [Track_Name] varchar(255), [Track_Code] varchar(127), [Track_Details] varchar (max), 
									[Calculation_Status] bit, [Calculation_Time] datetime)
END

---------------------------------------------- Create GeometryHistory Table ----------------------------------------------
--Used for storing all historic calculations of track geometry parameters. Can be linked to the PrismHistory table via the [Calculaton_ID] column.
IF OBJECT_ID (N'dbo.GeometryHistory', N'U') IS NULL
BEGIN
CREATE TABLE	GeometryHistory		([Calculation_ID] int, [Track_CL_Chainage] varchar(100), [Track_Code] varchar(100) NULL, [DataWindow_Start] datetime, [DataWindow_End] datetime,
									[Rail_Cant] decimal (20,6), [Rail_Gauge] decimal (20,6), [Twist_Short] decimal (20,6), [Twist_Long] decimal (20,6),
									[LR_ID] varchar(100), [LR_Easting] decimal (20,6), [LR_Northing] decimal (20,6), [LR_Height] decimal (20,6), 
									[LR_Radius] decimal (20,6), [LR_Top_Short] decimal (20,6), [LR_Top_Long] decimal (20,6), [LR_Line_Short] decimal (20,6),
									[LR_Line_Long] decimal (20,6), [RR_ID] varchar(100), [RR_Easting] decimal (20,6), [RR_Northing] decimal (20,6), 
									[RR_Height] decimal (20,6), [RR_Radius] decimal (20,6), [RR_Top_Short] decimal (20,6), [RR_Top_Long] decimal (20,6),
									[RR_Line_Short] decimal (20,6), [RR_Line_Long] decimal (20,6), [CL_ID] varchar(100), [CL_Easting] decimal (20,6),
									[CL_Northing] decimal (20,6), [CL_Height] decimal (20,6), [CL_Radius] decimal (20,6), [CL_Top_Short] decimal (20,6),
									[CL_Top_Long] decimal (20,6), [CL_Line_Short] decimal (20,6), [CL_Line_Long] decimal (20,6))
END

---------------------------------------------- Create PrismHistory Table ----------------------------------------------
--Used for storing all historic prism data that was used for interpolation and computation of track geometry parameters. 
--Can be linked to the PrismHistory table via the [Calculaton_ID] column.
IF OBJECT_ID (N'dbo.PrismHistory', N'U') IS NULL
BEGIN
CREATE TABLE	PrismHistory		([Calculation_ID] int, [Point_Name] nvarchar(100) NULL, [Point_Epoch] dateTime NULL, [Point_Group] nvarchar(100) NULL, 
									[Point_ExpTime_DD] decimal(20,6) NULL, [Point_ExpTime_DHM] varchar (100) NULL, [Point_Easting] float NULL,
									[Point_Northing] float NULL, [Point_Height] float NULL, [Point_EOffset] float NULL, [Point_NOffset] float NULL,
									[Point_HOffset] float NULL,	[Track_Chainage] float NULL, [Track_RailSide] nvarchar(1) NULL,	[Track_Code] nvarchar(100) NULL,
									[Track_Easting] float NULL,	[Track_Northing] float NULL, [Track_Height] float NULL)
END