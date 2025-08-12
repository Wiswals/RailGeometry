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
					[dbo.ReportingData]
					[dbo.PrismHistory]
Affected function:  [dbo.ParseString]
					[dbo.BearingandDistance]
					[dbo.SelectToHTML]
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
2019-09-13          Lewis Walsh			Updated the 'ParseString' function to include a NULL
										value return if the passed @Search variable does not 
										contain a matching @String value.
2019-09-21          Lewis Walsh			Created the [dbo.SelectToHTML] procedure for creating a
										formatted HTML table string from a provided SQL SELECT
										statement and predetermined or default formatting parameters.
2019-09-21          Lewis Walsh			Created an additional table [dbo.ReportingData] for
										storing a combination of prism data and track geometry 
										data which is to be used for reporting purposes. The table
										will contain a copy of the calculated geometry data from the
										[dbo.GeometryHistory] table where the geometry data chainage
										is the nearest neighbour to a [dbo.PrismHistory] observation
										for a given calculation set. 
***************************************************************************************************/

SET DATEFORMAT dmy
SET XACT_ABORT ON
SET NOCOUNT ON
SET ANSI_WARNINGS OFF

--PRINT '----------------------------'
--PRINT convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14)  + ' | Starting initialisation script.'
------------------------------------------------ Parse String Function------------------------------------------------
-- Interrogates and returns character values in a given String using the provided Search values

IF OBJECT_ID (N'dbo.ParseString', N'FN') IS NOT NULL
	DROP FUNCTION ParseString;
GO

CREATE FUNCTION [dbo].ParseString (@String varchar(max), @Search varchar(10)) RETURNS float
AS
	BEGIN
          DECLARE @ix1 int, @ix2 int,  @lx1 int, @Result float
		  
		  IF CHARINDEX(@Search, @String, 0) > 0
			  BEGIN
				  SET @lx1 = LEN(@Search)
				  SET @ix1 = CHARINDEX(@Search,@String,0)
				  SET @ix2 = CHARINDEX(' ',@String,@ix1+@lx1 )
				  IF @ix2=0 SET @ix2=99

				  SET @Result = convert(float,SUBSTRING(@String, @ix1 + @lx1, @ix2-(@ix1 + @lx1)))
			  END
		  ELSE
			 SET @Result = NULL
	RETURN @Result
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

------------------------------------------------ SelectToHTML ------------------------------------------------
-- Description: Turns a query into a formatted HTML table. Useful for emails. 
-- Any ORDER BY clause needs to be passed in the separate ORDER BY parameter.
IF OBJECT_ID (N'dbo.SelectToHTML', N'P') IS NOT NULL
	DROP PROCEDURE [dbo].SelectToHTML;
GO

CREATE PROC [dbo].SelectToHTML 
(
  @query nvarchar(MAX), --A query to turn into HTML format. It should not include an ORDER BY clause.
  @orderBy nvarchar(MAX) = NULL, --An optional ORDER BY clause. It should contain the words 'ORDER BY'.
  @tablefontsize nvarchar(40) = '10pt', --10pt
  @tablefontstyle nvarchar(256) = 'calibri, sans-serif',
  @tablewidth nvarchar(40) = '60%',
  @cellpadding nvarchar(40) = '10',
  @tableboarderstyle nvarchar(100) = 'solid',
  @tableboardersize nvarchar(40) = '1',
  @tabletextalign nvarchar(100) = 'left',
  @columnwidth nvarchar(40) = '100px',
  @headerheight nvarchar(40) = '30px',
  @rowheight nvarchar(40) = '20px',
  @headerbackcolour nvarchar(100) = '#dddddd',
  @headerfrontcolour nvarchar(100) = '#000000',
  @headerboardercolour nvarchar(100) = '#dddddd',
  @rowbackcolour nvarchar(100) = '#ffffff',
  @rowfrontcolour nvarchar(100) = '#000000',
  @rowboardercolour nvarchar(100) = '#dddddd',
  @html nvarchar(MAX) = NULL OUTPUT --The HTML output of the procedure.
)
AS
BEGIN   
  SET NOCOUNT ON;

  --Set default values
  IF @orderBy IS NULL BEGIN
    SET @orderBy = ''  
  END

  SET @orderBy = REPLACE(@orderBy, '''', '''''');

  DECLARE @realQuery nvarchar(MAX) = '
    DECLARE @headerRow nvarchar(MAX);
    DECLARE @cols nvarchar(MAX);    

    SELECT * INTO #dynSql FROM (' + @query + ') sub;

    SELECT @cols = COALESCE(@cols + '', '''''''', '', '''') + ''['' + name + ''] AS ''''td''''''
    FROM tempdb.sys.columns 
    WHERE object_id = object_id(''tempdb..#dynSql'')
    ORDER BY column_id;

    SET @cols = ''SET @html = CAST(( SELECT '' + @cols + '' FROM #dynSql ' + @orderBy + ' FOR XML PATH(''''tr''''), ELEMENTS XSINIL) AS nvarchar(max))''    

    EXEC sys.sp_executesql @cols, N''@html nvarchar(MAX) OUTPUT'', @html=@html OUTPUT

    SELECT @headerRow = COALESCE(@headerRow + '''', '''') + ''<th style="width: ' + @columnwidth + '; border-color: ' + @headerboardercolour + '; background-color: ' + @headerbackcolour + '; height: ' + @headerheight + '; text-align: ' + @tabletextalign + ';"><span style="font-family: ' + @tablefontstyle + '; font-size: ' + @tablefontsize + '; color: ' + @headerfrontcolour + ';">'' + name + ''</span></th>'' 
    FROM tempdb.sys.columns 
    WHERE object_id = object_id(''tempdb..#dynSql'')
    ORDER BY column_id;

    SET @headerRow = ''<tr style="height: ' + @rowheight + ';">'' + @headerRow + ''</tr>'';
	SELECT @html = REPLACE(@html, ''<tr xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'', ''<tr style="height: ' + @rowheight + ';">'')
	SELECT @html = REPLACE(@html, ''<td>'', ''<td style="width: ' + @columnwidth + '; height: ' + @rowheight + '; border-color: ' + @rowboardercolour + '; border-style: ' + @tableboarderstyle + '; text-align: ' + @tabletextalign + '; background-color: ' + @rowbackcolour + ';"><span style="font-size: ' + @tablefontsize + '; font-family: ' + @tablefontstyle + '; color: ' + @rowfrontcolour + ';">'')
	SELECT @html = REPLACE(@html, ''</td>'', ''</span></td>'')

    SET @html = ''<table style="width: ' + @tablewidth + '; border-collapse: collapse; border-style: ' + @tableboarderstyle + '; border-color: ' + @rowboardercolour + ';" border="' + @tableboardersize + '" cellpadding="' + @cellpadding + '"><tbody>'' + @headerRow + @html + ''</tbody></table>'';    
    ';

  EXEC sys.sp_executesql @realQuery, N'@html nvarchar(MAX) OUTPUT', @html=@html OUTPUT
END
GO

PRINT convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14)  + ' | Functions added to database.'

------------------------------------------------ Create TrackGeometry ------------------------------------------------
--Used databse for all the track geometry calculations
IF DB_ID ('TrackGeometry') IS NULL
	BEGIN
		CREATE DATABASE TrackGeometry;
		PRINT convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14)  + ' | TrackGeometry database created.'
	END
	GO

USE [TrackGeometry]
---------------------------------------------- Create TrackListing Table ----------------------------------------------
--Used for storing track details of each rail line which requires geometry calculations
IF OBJECT_ID (N'dbo.TrackListing', N'U') IS NULL
BEGIN
CREATE TABLE	TrackListing		([ID] int IDENTITY(1,1) PRIMARY KEY, [Track_Name] varchar(255), [Track_Code] varchar(127), [Track_Details] varchar (max), 
									[Calculation_Status] bit, [Expected_Database] varchar(255), [Calculation_Time] datetime)
				PRINT convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14)  + ' | TrackListing table created.'
END

---------------------------------------------- Create GeometryHistory Table ----------------------------------------------
--Used for storing all historic calculations of track geometry parameters. Can be linked to the PrismHistory table via the [Calculaton_ID] column.
IF OBJECT_ID (N'dbo.GeometryHistory', N'U') IS NULL
BEGIN
CREATE TABLE	GeometryHistory		([Calculation_ID] int, [Track_CL_Chainage] decimal(30,10), [Track_Code] varchar(100) NULL, [DataWindow_Start] datetime, [DataWindow_End] datetime,
									[Rail_Cant] decimal (20,6), [Rail_Gauge] decimal (20,6), [Twist_Short] decimal(30,10), [Twist_Long] decimal (20,6),
									[LR_ID] varchar(100), [LR_Easting] decimal (20,6), [LR_Northing] decimal (20,6), [LR_Height] decimal (20,6), 
									[LR_Radius] decimal (20,6), [LR_Top_Short] decimal (20,6), [LR_Top_Long] decimal (20,6), [LR_Line_Short] decimal (20,6),
									[LR_Line_Long] decimal (20,6), [RR_ID] varchar(100), [RR_Easting] decimal (20,6), [RR_Northing] decimal (20,6), 
									[RR_Height] decimal (20,6), [RR_Radius] decimal (20,6), [RR_Top_Short] decimal (20,6), [RR_Top_Long] decimal (20,6),
									[RR_Line_Short] decimal (20,6), [RR_Line_Long] decimal (20,6), [CL_ID] varchar(100), [CL_Easting] decimal (20,6),
									[CL_Northing] decimal (20,6), [CL_Height] decimal (20,6), [CL_Radius] decimal (20,6), [CL_Top_Short] decimal (20,6),
									[CL_Top_Long] decimal (20,6), [CL_Line_Short] decimal (20,6), [CL_Line_Long] decimal (20,6), [Diff_Chainage_Left] decimal(20,6), 
									[Diff_Chainage_Rght] decimal(20,6), [Calculation_Comment] varchar(max))
				PRINT convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14)  + ' | GeometryHistory table created.'
END

---------------------------------------------- Create ReportingData Table ----------------------------------------------
--A combination of the PrismHistory and GeometryHistory tables stored into at runtime. Will store original prism locations and track geometry results at nearest chainage.
IF OBJECT_ID (N'dbo.ReportingData', N'U') IS NULL
BEGIN
CREATE TABLE	ReportingData		([Calculation_ID] int, [Parent_Instrument] varchar (200), [Geometry_Instrument] varchar (200), 
									[Point_Chainage] decimal(20,6), [Calculation_Chainage] decimal(20,6), [Chainage_Diff] decimal(20,6), [Point_Epoch] datetime,
									[Calculation_Epoch] datetime, [Epoch_Diff] decimal (20,6), [Rail_Cant] decimal (20,6), [Rail_Gauge] decimal (20,6), 
									[Twist_Short] decimal(30,10), [Twist_Long] decimal (20,6), [LR_ID] varchar(100), [LR_Easting] decimal (20,6), 
									[LR_Northing] decimal (20,6), [LR_Height] decimal (20,6), [LR_Radius] decimal (20,6), [LR_Top_Short] decimal (20,6), 
									[LR_Top_Long] decimal (20,6), [LR_Line_Short] decimal (20,6), [LR_Line_Long] decimal (20,6), [RR_ID] varchar(100), 
									[RR_Easting] decimal (20,6), [RR_Northing] decimal (20,6), [RR_Height] decimal (20,6), [RR_Radius] decimal (20,6), 
									[RR_Top_Short] decimal (20,6), [RR_Top_Long] decimal (20,6), [RR_Line_Short] decimal (20,6), [RR_Line_Long] decimal (20,6), 
									[CL_ID] varchar(100), [CL_Easting] decimal (20,6), [CL_Northing] decimal (20,6), [CL_Height] decimal (20,6), 
									[CL_Radius] decimal (20,6), [CL_Top_Short] decimal (20,6),[CL_Top_Long] decimal (20,6), [CL_Line_Short] decimal (20,6), 
									[CL_Line_Long] decimal (20,6),[Diff_Chainage_Left] decimal(20,6), [Diff_Chainage_Rght] decimal(20,6), [Calculation_Comment] varchar(max))
				PRINT convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14)  + ' | ReportingData table created.'
END

---------------------------------------------- Create PrismHistory Table ----------------------------------------------
--Used for storing all historic prism data that was used for interpolation and computation of track geometry parameters. 
--Can be linked to the PrismHistory table via the [Calculaton_ID] column.
IF OBJECT_ID (N'dbo.PrismHistory', N'U') IS NULL
BEGIN
CREATE TABLE	PrismHistory		([Calculation_ID] int, [Point_Name] nvarchar(100) NULL, [Point_Epoch] dateTime NULL, [Point_Group] nvarchar(100) NULL, 
									[Point_ExpTime_DD] decimal(20,6) NULL, [Point_ExpTime_DHM] varchar (100) NULL, [Point_Easting] decimal(30,10) NULL,
									[Point_Northing] decimal(30,10) NULL, [Point_Height] decimal(30,10) NULL, [Point_EOffset] decimal(30,10) NULL, [Point_NOffset] decimal(30,10) NULL,
									[Point_HOffset] decimal(30,10) NULL,	[Track_Chainage] decimal(30,10) NULL, [Track_RailSide] nvarchar(50) NULL, [Track_Code] nvarchar(100) NULL,
									[Track_Easting] decimal(30,10) NULL,	[Track_Northing] decimal(30,10) NULL, [Track_Height] decimal(30,10) NULL)
				PRINT convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14)  + ' | PrismHistory table created.'
END

PRINT convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14)  + ' | Initialisation script finished.'
--PRINT '----------------------------' + Char(13)