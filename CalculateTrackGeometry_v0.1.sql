/***************************************************************************************************
Procedure:          CalculateTrackGeometry
Create Date:        2019-09-16
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
2019-09-16			Lewis Walsh			Added changes to match the new naming scheme in the 
										'InitaliseTrackeometry' script.
2018-03-22          Maan Widaplan       General formatting and added header information.
2018-03-22          Maan Widaplan       Added logic to automatically Move G <-> H after 12 months.
***************************************************************************************************/


IF OBJECT_ID ('tempdb..##CalculationListing') IS NOT NULL Begin DROP TABLE ##CalculationListing; End
IF OBJECT_ID ('tempdb..#PrismData') IS NOT NULL Begin DROP TABLE #PrismData; End


IF OBJECT_ID (N'dbo.RailResults_ALL', N'U') IS NOT NULL Begin TRUNCATE TABLE RailResults_ALL; End
IF OBJECT_ID ('tempdb..#myTrackPoints') IS NOT NULL Begin DROP TABLE #myTrackPoints; End
IF OBJECT_ID ('tempdb..#MyTableALL') IS NOT NULL Begin DROP TABLE #MyTableALL; End

SET DATEFORMAT dmy
SET XACT_ABORT ON
SET NOCOUNT ON


------------------------------------------------ Track Analysis Script ------------------------------------------------
------------------------------------------------- SET VARIABLES -------------------------------------------------------


----- User Input
DECLARE @CalculationWindow as int = 0
DECLARE @DataExtractionWindow as int = 5


----- Script Variables
--DECLARE @DatabaseList TABLE (DatabaseName varchar(128) not null);
DECLARE @DatabaseName varchar(128)
DECLARE @Database_Script varchar(max) 
DECLARE @Execute_Script varchar(max)

DECLARE @TrackCounter int
DECLARE @CalcCounter int

DECLARE @CurrentTrack as varchar(100) --@myTrack = @CurrentTrack
DECLARE @CurrentDatabase as varchar(max)
DECLARE @ExpectedDatabase as varchar(max) = DB_NAME() 
DECLARE @TrackID int
DECLARE @CurrentDateTime datetime = GETDATE() 
DECLARE @LastRailCalcTime datetime
DECLARE @ExtractStartTime datetime
DECLARE @ExtractEndTime datetime

-- Build list of Database Names
-- INSERT INTO @DatabaseList
-- SELECT name FROM sys.databases WHERE name IN ('CSMW-001');
-- Set the first database to be used
-- SET @DatabaseName = (select min(DatabaseName) from @DatabaseList);


-- Intalise track and calculation counters
SET @Database_Script='USE [TrackGeometry] SELECT ROW_NUMBER() OVER(ORDER BY [Track_Name] ASC) As Row_ID, [ID], [Track_Code], [Expected_Database], [Calculation_Time] INTO ##CalculationListing FROM [TrackListing] WHERE [Calculation_Status] = 1'
EXEC (@Database_Script)

SELECT	@TrackCounter = Min([Row_ID]) FROM ##CalculationListing
SET		@CalcCounter = 0

SELECT * FROM ##CalculationListing

-- Start track geometry calculations
WHILE	@TrackCounter is not null
	BEGIN

	--Get track info for current rail line
	SELECT	@CurrentTrack = [Track_Code], 
			@TrackID = [ID], 
			@CurrentDatabase = [Expected_Database],
			@LastRailCalcTime = [Calculation_Time] 
	FROM	##CalculationListing  
	WHERE	[Row_ID] = @TrackCounter

	--Start of rail analysis calculation trigger
	IF	@CurrentDateTime > DateADD(MINUTE,@CalculationWindow,@LastRailCalcTime)
	BEGIN
		
		--Determine the start datetime for the data extraction
		SELECT @ExtractStartTime = DateADD(hh, -@DataExtractionWindow, @CurrentDateTime), @ExtractEndTime = @CurrentDateTime;
		
		--Update the TrackListing table with the new calculation time
		SET @Database_Script='USE [TrackGeometry] Update [TrackListing] SET [Calculation_Time] = convert(datetime,''' + convert(varchar, @CurrentDateTime, 109) + ''', 109) WHERE [ID] = ' + convert(varchar, @TrackID)
		EXEC (@Database_Script)
		
		---------------------------------------IMPORT POINT DATA INTO TEMPORARY TABLE(s)----------------------------------------------

		------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------- Create temp table #PrismDataALL  ----------------------------------------------------------
		------------------------------------------------------------------------------------------------------------------------------
		
		CREATE TABLE	#PrismData	([Calculation_ID] int, [Point_Name] nvarchar(100) NULL, [Point_Epoch] dateTime NULL, [Point_Group] nvarchar(100) NULL, 
									[Point_ExpTime_DD] decimal(20,6) NULL, [Point_ExpTime_DHM] varchar (100) NULL, [Point_Easting] float NULL,
									[Point_Northing] float NULL, [Point_Height] float NULL, [Point_EOffset] float NULL, [Point_NOffset] float NULL,
									[Point_HOffset] float NULL,	[Track_Chainage] float NULL, [Track_RailSide] nvarchar(50) NULL, [Track_Code] nvarchar(100) NULL,
									[Track_Easting] float NULL,	[Track_Northing] float NULL, [Track_Height] float NULL, [Epoch_Index] int NULL)
		
		INSERT INTO #PrismData
		SELECT		*  FROM 
					(SELECT NULL as [Calculation_ID], Points.Name as [Point_Name], Results.Epoch as [Point_Epoch], PointGroups.Name as [Point_Group], DateDIFF(SECOND, Results.Epoch, @CurrentDateTime) / 86400.0 as [Point_ExpTime_DD],
					Format(convert(INT, (DateDIFF(Second, Results.Epoch, @CurrentDateTime)/86400)),'D2') + 'd ' + Format(convert(INT, ((DateDIFF(Second, Results.Epoch, @CurrentDateTime)%86400)/3600)),'D2') + 'h '+
					Format(convert(INT, (((DateDIFF(Second, Results.Epoch, @CurrentDateTime)%86400)%3600)/60)),'D2') + 'm' as [Point_ExpTime_DHM], Results.Easting as [Point_Easting], Results.Northing as [Point_Northing], 
					Results.Height as [Point_Height], [dbo].[ParseString](Points.Description, 'EoS:') as [Point_EOffset], [dbo].[ParseString](Points.Description, 'NoS:') as [Point_NOffset], 
					[dbo].[ParseString](Points.Description, 'HoS:') as [Point_HOffset], [dbo].[ParseString](Points.Description, 'CH:') as [Track_Chainage],	SUBSTRING(Points.Name, CHARINDEX('-RP', Points.Name) + 1, 3) as [Track_RailSide], 
					@CurrentTrack as [Track_Code], NULL as [Track_Easting], NULL as [Track_Northing], NULL as [Track_Height], row_number() over(partition by Points.Name order by Results.Epoch desc) as EpochIndex
		FROM	    Results INNER JOIN
					Points ON Results.Point_ID = Points.ID LEFT OUTER JOIN
					PointGroups INNER JOIN
					PointGroupItems ON PointGroups.ID = PointGroupItems.PointGroup_ID ON Points.ID = PointGroupItems.Point_ID
		WHERE		(Results.Type = 0) AND (Results.Epoch >= @ExtractStartTime) AND (Results.Epoch < @ExtractEndTime) 
					AND (Points.Name LIKE '%%%' + @CurrentTrack + '%%%' ) AND (Points.Name LIKE '%RPL%' OR Points.Name LIKE '%RPR%' ) ) as AllData
		WHERE		AllData.EpochIndex=1
		
		-- Finsih this to send out an email when prism readings have gone past 12 hours
		-- IF 12 < SOME (SELECT dTime FROM #MyTable)  
			-- BEGIN
			--EXEC msdb.dbo.sp_send_dbmail  
				--@recipients = 'LWalsh@landsurveys.net.au',
				--@body = 'WARNING: One or more prisms have not been observed within the last 12 hours...',  
				--@query = 'SELECT * FROM #MyTable WHERE dTime > 12',    
				--@subject = 'V13B Rail Calculations - Prism Reading Warning',  
				--@attach_query_result_as_file = 1 ;  
			-- END
		-- ELSE  
		-- PRINT 'FALSE' ;

	

	SET @CalcCounter = @CalcCounter+1

	END

	SELECT @TrackCounter = MIN([Row_ID]) FROM ##CalculationListing WHERE Row_ID > @TrackCounter

END

IF @CalcCounter>0

SELECT * FROM #PrismData

