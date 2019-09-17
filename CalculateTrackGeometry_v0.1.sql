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
2019-09-17			Lewis Walsh			Rebuild of data extraction statement to retrieve latest readings
										withing the provided extraction window in one step. 
2018-03-22          Maan Widaplan       General formatting and added header information.
2018-03-22          Maan Widaplan       Added logic to automatically Move G <-> H after 12 months.
***************************************************************************************************/


IF OBJECT_ID ('tempdb..##CalculationListing') IS NOT NULL Begin DROP TABLE ##CalculationListing; End
IF OBJECT_ID ('tempdb..#PrismData') IS NOT NULL Begin DROP TABLE #PrismData; End
IF OBJECT_ID ('tempdb..#TrackGeometry') IS NOT NULL Begin DROP TABLE #TrackGeometry; End


IF OBJECT_ID (N'dbo.RailResults_ALL', N'U') IS NOT NULL Begin TRUNCATE TABLE RailResults_ALL; End
IF OBJECT_ID ('tempdb..#myTrackPoints') IS NOT NULL Begin DROP TABLE #myTrackPoints; End
IF OBJECT_ID ('tempdb..#MyTableALL') IS NOT NULL Begin DROP TABLE #MyTableALL; End

SET DATEFORMAT dmy
SET XACT_ABORT ON
SET NOCOUNT ON
SET ANSI_WARNINGS OFF


------------------------------------------------ Track Analysis Script ------------------------------------------------
------------------------------------------------- SET VARIABLES -------------------------------------------------------

----- User Input
DECLARE @CalculationWindow as int = 0		-- The required frequency (in minutes) between required calculations.
DECLARE @DataExtractionWindow as int = 96	-- Number of hours to look back when extracting data for the calculations

DECLARE @PrismSpacingLimit as float = 7.2	-- A value (in meters) used to check the spacing between track prisms any prisms seperated by more than this value will not get geometry calculations.

DECLARE @ChainageStep as float = 0.5		-- The spacing at which you want to calculate track geometry at. i.e. every x meters.
DECLARE @ShortTwistStep as int = 2			-- The spacing at which short twist should be calculated, looking in reverse chainage.
DECLARE @LongTwistStep as int = 14			-- The spacing at which long twist should be calculated, looking in reverse chainage.


--Script variables
DECLARE @Database_Script varchar(max), @Execute_Script varchar(max)

--Data extraction variables
DECLARE @TrackCounter int, @CalculationID int, @CalcCounter int
DECLARE @CurrentTrack as varchar(100), @TrackID int --@myTrack = @CurrentTrack
DECLARE @CurrentDatabase as varchar(max)
DECLARE @CurrentDateTime datetime = GETDATE(), @LastRailCalcTime datetime
DECLARE @ExtractStartTime datetime, @ExtractEndTime datetime

--Track geometry variables
DECLARE @ChainageIndex as float, @Diff_Chainage_Left float, @Diff_Chainage_Rght float
DECLARE @Prev_PointName varchar(100), @Prev_Chainage float, @Prev_Easting float, @Prev_Northing float, @Prev_Height float
DECLARE @Next_PointName varchar(100), @Next_Chainage float, @Next_Easting float, @Next_Northing float, @Next_Height float		
DECLARE @Left_Easting float, @Left_Northing float, @Left_Height float
DECLARE @Rght_Easting float, @Rght_Northing float, @Rght_Height float
DECLARE @Track_Cant float, @Track_Guage float, @Twist_Short float, @Twist_Long float

--Retrieve track information to initalise calculation parameters
SET @Database_Script=	'USE [TrackGeometry]
						SELECT ROW_NUMBER() OVER(ORDER BY [Track_Name] ASC) As Row_ID, [ID], [Track_Code], [Expected_Database], 
						[Calculation_Time], (SELECT MAX([Calculation_ID]) FROM [GeometryHistory]) as [Calculation_ID] 
						INTO ##CalculationListing 
						FROM [TrackListing] WHERE [Calculation_Status] = 1'
EXEC (@Database_Script)

-- Intalise track and calculation counters
SELECT	@TrackCounter = Min([Row_ID]) FROM ##CalculationListing
SELECT  @CalculationID = Max([Calculation_ID]) FROM ##CalculationListing
SET		@CalcCounter = 0
-------------------------------------------------------------------------------------------------------------
SELECT * FROM ##CalculationListing

-- Start track geometry calculations
WHILE @TrackCounter IS NOT NULL
BEGIN

	--Get track info for current rail line
	SELECT	@CurrentTrack = [Track_Code], 
			@TrackID = [ID], 
			@CurrentDatabase = [Expected_Database],
			@LastRailCalcTime = [Calculation_Time] 
	FROM	##CalculationListing  
	WHERE	[Row_ID] = @TrackCounter

	--Start of rail analysis calculation trigger
	IF	@CurrentDateTime > DateADD(MINUTE,@CalculationWindow,@LastRailCalcTime) AND @CurrentDatabase = DB_NAME() 
		BEGIN
		
			--Determine the calculation ID for the given dataset
			IF @CalculationID IS NULL SET @CalculationID = 1
			ELSE SET @CalculationID = @CalculationID + 1

			--Determine the start datetime for the data extraction
			SELECT @ExtractStartTime = DateADD(hh, -@DataExtractionWindow, @CurrentDateTime), @ExtractEndTime = @CurrentDateTime;
		
			--Update the TrackListing table with the new calculation time
			SET @Database_Script=	'USE [TrackGeometry] Update [TrackListing] SET [Calculation_Time] = convert(datetime,''' 
									+ convert(varchar, @CurrentDateTime, 109) + ''', 109) WHERE [ID] = ' + convert(varchar, @TrackID)
			EXEC (@Database_Script)
		
			---------------------------------------IMPORT POINT DATA INTO TEMPORARY TABLE(s)----------------------------------------------
			------------------------------------------------------------------------------------------------------------------------------
			-------------------------------------------- Create temp #myTrackPoints ------------------------------------------------------
			------------------------------------------------------------------------------------------------------------------------------
			--Create temporary table #PrismData to store all the required prism and track coordinate data
			CREATE TABLE	#PrismData	([Calculation_ID] int, [Point_Name] nvarchar(100) NULL, [Point_Epoch] dateTime NULL, [Point_Group] nvarchar(100) NULL, 
										[Point_ExpTime_DD] decimal(20,6) NULL, [Point_ExpTime_DHM] varchar (100) NULL, [Point_Easting] float NULL,
										[Point_Northing] float NULL, [Point_Height] float NULL, [Point_EOffset] float NULL, [Point_NOffset] float NULL,
										[Point_HOffset] float NULL,	[Track_Chainage] float NULL, [Track_RailSide] nvarchar(50) NULL, [Track_Code] nvarchar(100) NULL,
										[Track_Easting] float NULL,	[Track_Northing] float NULL, [Track_Height] float NULL, [Epoch_Index] int NULL)

			------------------------------------------------------------------------------------------------------------------------------
			-------------------------------------------- Create temp #myTrackPoints ------------------------------------------------------
			------------------------------------------------------------------------------------------------------------------------------
			-- Store relevant data containing all the latest readings inside the given extraction window into the #PrismData table
			INSERT INTO #PrismData
			SELECT		*  FROM 
						(SELECT @CalculationID as [Calculation_ID], Points.Name as [Point_Name], Results.Epoch as [Point_Epoch], PointGroups.Name as [Point_Group], DateDIFF(SECOND, Results.Epoch, @CurrentDateTime) / 86400.0 as [Point_ExpTime_DD],
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
						AND (Points.Name LIKE '%%%' + @CurrentTrack + '%%%' ) AND (Points.Name LIKE '%RPL%' OR Points.Name LIKE '%RPR%' ) AND [dbo].[ParseString](Points.Description, 'CH:') IS NOT NULL) as AllData
			WHERE		AllData.EpochIndex=1
		
			-- Shift prism coordinate data onto the track via the defined offset values in the point description field
			UPDATE		#PrismData SET [Track_Easting] = [Point_Easting] + [Point_EOffset]
			UPDATE		#PrismData SET [Track_Northing] = [Point_Northing] + [Point_NOffset]
			UPDATE		#PrismData SET [Track_Height] = [Point_Height] + [Point_HOffset]

			DECLARE @MinChainage as Float
			DECLARE @MaxChainage as Float

			--Retrieve the minimum and maximum chainage for all prism points of a given rail line (not just the availalbe data)
			SELECT		@MinChainage=CEILING(MIN([dbo].[ParseString](Points.Description,'CH:'))), @MaxChainage=FLOOR(MAX([dbo].[ParseString](Points.Description,'CH:')))
			FROM        Points LEFT OUTER JOIN
                        PointGroups INNER JOIN
                        PointGroupItems ON PointGroups.ID = PointGroupItems.PointGroup_ID ON Points.ID = PointGroupItems.Point_ID
			WHERE		(Points.Name LIKE '%%%' + @CurrentTrack + '%%%' ) AND (Points.Name LIKE '%RPL%' OR Points.Name LIKE '%RPR%' ) AND [dbo].[ParseString](Points.Description, 'CH:') IS NOT NULL
			
			SET @ChainageIndex = @MinChainage

			Print @MinChainage

			------------------------------------------------------------------------------------------------------------------------------
			-------------------------------------------- Create temp #TrackGeometry ------------------------------------------------------
			------------------------------------------------------------------------------------------------------------------------------
			
			CREATE TABLE #TrackGeometry	([Calculation_ID] int, [Track_CL_Chainage] float, [Track_Code] varchar(100) NULL, [DataWindow_Start] datetime, [DataWindow_End] datetime,
										[Rail_Cant] decimal (20,6), [Rail_Gauge] decimal (20,6), [Twist_Short] float, [Twist_Long] decimal (20,6),
										[LR_ID] varchar(100), [LR_Easting] decimal (20,6), [LR_Northing] decimal (20,6), [LR_Height] decimal (20,6), 
										[LR_Radius] decimal (20,6), [LR_Top_Short] decimal (20,6), [LR_Top_Long] decimal (20,6), [LR_Line_Short] decimal (20,6),
										[LR_Line_Long] decimal (20,6), [RR_ID] varchar(100), [RR_Easting] decimal (20,6), [RR_Northing] decimal (20,6), 
										[RR_Height] decimal (20,6), [RR_Radius] decimal (20,6), [RR_Top_Short] decimal (20,6), [RR_Top_Long] decimal (20,6),
										[RR_Line_Short] decimal (20,6), [RR_Line_Long] decimal (20,6), [CL_ID] varchar(100), [CL_Easting] decimal (20,6),
										[CL_Northing] decimal (20,6), [CL_Height] decimal (20,6), [CL_Radius] decimal (20,6), [CL_Top_Short] decimal (20,6),
										[CL_Top_Long] decimal (20,6), [CL_Line_Short] decimal (20,6), [CL_Line_Long] decimal (20,6), [Diff_Chainage_Left] decimal(20,6), [Diff_Chainage_Rght] decimal(20,6))

			------------------------------------------------------------------------------------------------------------------------------
			-- Generate interpolated rail points at the specified chainage step
			------------------------------------------------------------------------------------------------------------------------------
			WHILE @ChainageIndex <= @MaxChainage
			BEGIN
			
				--Reset all variables to maintain NULL storage of out of bound data
				SELECT  @Diff_Chainage_Left = NULL, @Diff_Chainage_Rght = NULL
				SELECT @Prev_PointName = NULL, @Prev_Chainage = NULL, @Prev_Easting = NULL, @Prev_Northing = NULL, @Prev_Height = NULL
				SELECT @Next_PointName = NULL, @Next_Chainage = NULL, @Next_Easting = NULL, @Next_Northing = NULL, @Next_Height = NULL		
				SELECT @Left_Easting = NULL, @Left_Northing = NULL, @Left_Height = NULL
				SELECT @Rght_Easting = NULL, @Rght_Northing = NULL, @Rght_Height = NULL
				SELECT @Track_Cant = NULL, @Track_Guage = NULL, @Twist_Short = NULL, @Twist_Long = NULL

				--Get previous LEFT rail data
				SELECT	TOP 1 @Prev_PointName=[Point_Name], @Prev_Chainage=[Track_Chainage], @Prev_Easting=[Track_Easting], @Prev_Northing=[Track_Northing], @Prev_Height=[Track_Height]
				FROM	#PrismData WHERE [Track_Chainage] < @ChainageIndex and [Track_RailSide] ='RPL' ORDER BY [Track_Chainage] DESC
				--Get next LEFT rail data
				SELECT	TOP 1 @Next_PointName=[Point_Name], @Next_Chainage=[Track_Chainage], @Next_Easting=[Track_Easting], @Next_Northing=[Track_Northing], @Next_Height=[Track_Height]
				FROM	#PrismData WHERE [Track_Chainage] >= @ChainageIndex and [Track_RailSide] ='RPL' ORDER BY [Track_Chainage] ASC
				--Set LEFT rail chainage difference
				SET @Diff_Chainage_Left = @Next_Chainage - @Prev_Chainage
				
				IF @Diff_Chainage_Left <= @PrismSpacingLimit
					BEGIN
						--Interploate LEFT rail points at the current @ChainageIndex value
						SET @Left_Easting = (@ChainageIndex - @Prev_Chainage) * (@Next_Easting - @Prev_Easting) / NULLIF(@Diff_Chainage_Left,0) + @Prev_Easting
						SET @Left_Northing = (@ChainageIndex - @Prev_Chainage) * (@Next_Northing - @Prev_Northing) / NULLIF(@Diff_Chainage_Left,0) + @Prev_Northing
						SET @Left_Height = (@ChainageIndex - @Prev_Chainage) * (@Next_Height - @Prev_Height) / NULLIF(@Diff_Chainage_Left,0) + @Prev_Height
					END

				--Get previous RIGHT rail data
				SELECT	TOP 1 @Prev_PointName=[Point_Name], @Prev_Chainage=[Track_Chainage], @Prev_Easting=[Track_Easting], @Prev_Northing=[Track_Northing], @Prev_Height=[Track_Height]
				FROM	#PrismData WHERE [Track_Chainage] < @ChainageIndex and [Track_RailSide] ='RPR' ORDER BY [Track_Chainage] DESC
				--Get next RIGHT rail data
				SELECT	TOP 1 @Next_PointName=[Point_Name], @Next_Chainage=[Track_Chainage], @Next_Easting=[Track_Easting], @Next_Northing=[Track_Northing], @Next_Height=[Track_Height]
				FROM	#PrismData WHERE [Track_Chainage] >= @ChainageIndex and [Track_RailSide] ='RPR' ORDER BY [Track_Chainage] ASC
				--Set RIGHT rail chainage difference
				SET @Diff_Chainage_Rght = @Next_Chainage - @Prev_Chainage

				IF @Diff_Chainage_Rght <= @PrismSpacingLimit
					BEGIN
						--Interploate RIGHT rail points at the current @ChainageIndex value
						SET @Rght_Easting = (@ChainageIndex - @Prev_Chainage) * (@Next_Easting - @Prev_Easting) / NULLIF(@Diff_Chainage_Rght,0) + @Prev_Easting
						SET @Rght_Northing = (@ChainageIndex - @Prev_Chainage) * (@Next_Northing - @Prev_Northing) / NULLIF(@Diff_Chainage_Rght,0) + @Prev_Northing
						SET @Rght_Height = (@ChainageIndex - @Prev_Chainage) * (@Next_Height - @Prev_Height) / NULLIF(@Diff_Chainage_Rght,0) + @Prev_Height
					END

				IF @Diff_Chainage_Left <= @PrismSpacingLimit OR @Diff_Chainage_Rght <= @PrismSpacingLimit
					BEGIN	
						--Calculate the fixed location track geometry parameters
						SET @Track_Cant = @Left_Height - @Rght_Height
						SET @Track_Guage = SQRT(SQUARE(@Left_Easting - @Rght_Easting) + SQUARE(@Left_Northing - @Rght_Northing) + SQUARE(@Left_Height - @Rght_Height))
						SET @Twist_Short = @Track_Cant - (SELECT Rail_Cant FROM #TrackGeometry WHERE [Track_CL_Chainage] = (@ChainageIndex - @ShortTwistStep))
						SET @Twist_Long = @Track_Cant - (SELECT Rail_Cant FROM #TrackGeometry WHERE [Track_CL_Chainage] = @ChainageIndex - @LongTwistStep)
					END
				
				--Insert the current results into the #TrackGeometry table
				INSERT INTO #TrackGeometry	([Calculation_ID], [Track_CL_Chainage], [Track_Code], [DataWindow_Start], [DataWindow_End], [Rail_Cant], [Rail_Gauge], [Twist_Short],
											[Twist_Long], [LR_ID], [LR_Easting], [LR_Northing], [LR_Height], [RR_ID], [RR_Easting], [RR_Northing], [RR_Height], [CL_ID],
											[CL_Easting], [CL_Northing], [CL_Height], [Diff_Chainage_Left], [Diff_Chainage_Rght])
				VALUES	(@CalculationID, @ChainageIndex, @CurrentTrack, @ExtractStartTime, @ExtractEndTime, @Track_Cant, @Track_Guage, @Twist_Short, @Twist_Long,
						 @CurrentTrack + '-LR-' + RIGHT('0000'+ CAST(CAST(@ChainageIndex as decimal(6,1)) as varchar(15)),6), @Left_Easting, @Left_Northing, @Left_Height,
						 @CurrentTrack + '-RR-' + RIGHT('0000'+ CAST(CAST(@ChainageIndex as decimal(6,1)) as varchar(15)),6), @Rght_Easting, @Rght_Northing, @Rght_Height,
						 @CurrentTrack + '-CL-' + RIGHT('0000'+ CAST(CAST(@ChainageIndex as decimal(6,1)) as varchar(15)),6), (@Left_Easting + @Rght_Easting)/2, 
						 (@Left_Northing + @Rght_Northing)/2, (@Left_Height + @Rght_Height)/2, @Diff_Chainage_Left, @Diff_Chainage_Rght)	
				
				--Increment the chainage index and repeat the computations
				SET @ChainageIndex = @ChainageIndex + @ChainageStep
			
			END

			------------------------------------------------------------------------------------------------------------------------------
			-- Compute top and line values, need Table [myTrackPoints] to be complete as search is Positive into Table
			------------------------------------------------------------------------------------------------------------------------------

			SET @ChainageIndex = @MinChainage

			WHILE @ChainageIndex <= @MaxChainage
			BEGIN


				--Increment the chainage index and repeat the computations
				SET @ChainageIndex = @ChainageIndex + @ChainageStep
			END
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

	--SELECT * FROM #PrismData
	DROP TABLE #PrismData

END

SELECT * FROM #TrackGeometry

IF @CalcCounter>0
PRINT 'Yay'