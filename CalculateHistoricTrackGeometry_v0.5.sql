/***************************************************************************************************
Procedure:          Calculate Historic Track Geometry
Create Date:        2024-11-14
Version:            0.5
Author:             Updated by [Your Name]
Description:        This script calculates historic track geometry parameters using extracted prism 
                    data from GeoMoS and stores results in the [GeometryHistory] and [PrismHistory] tables 
                    within the [Automated Track Geometry] database. This script processes data for 
                    specified historical date ranges and track sections.
Affected table(s):  [dbo.TrackListing]
                    [dbo.GeometryHistory]
                    [dbo.PrismHistory]
Affected function(s): [dbo.ParseString]
                      [dbo.BearingandDistance]
                      [dbo.SelectToHTML]
Used By:            Scheduled for execution at predefined intervals or for historical data analysis 
                    during the monitoring program.
Usage:              Configure parameters for track sections, prism spacing, chainage steps, and time 
                    windows before running. The script extracts relevant prism data, calculates 
                    geometry parameters, and stores the results for later analysis.
****************************************************************************************************
SUMMARY OF CHANGES
Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------- ------------------------------------------------------------
2019-09-16          Lewis Walsh         Initial implementation of the geometry calculation routine.
2019-09-17          Lewis Walsh         Added non-integer chainage steps and reference chord lengths.
2019-09-20          Lewis Walsh         Introduced logic for prism spacing checks to avoid invalid
                                        interpolations in large gaps.
2019-09-22          Lewis Walsh         Enhanced error handling and calculation comments.
2019-09-24          Lewis Walsh         Added data storage routines for [GeometryHistory] and [PrismHistory].
2021-04-28          Lewis Walsh         Bug fix: Adjusted [ChainageNameFormat] logic for compatibility 
                                        with variable chainage formats.
2024-11-14          Lewis Walsh         Modernized script for processing historic data intervals. 
                                        Refactored for clarity and modularity, including the ability 
                                        to dynamically process multiple track sections and intervals.
2024-11-14          Lewis Walsh         Added detailed logging and performance enhancements.
2024-11-14          Lewis Walsh         Improved error handling during data extraction and geometry 
                                        calculations to handle unexpected data gaps or inconsistencies.
2024-12-13          Lewis Walsh         Added Track Section Paramters into restructured Prism and 
                                        Geometry History tables.
***************************************************************************************************/


IF OBJECT_ID ('tempdb..##CalculationListing') IS NOT NULL Begin DROP TABLE ##CalculationListing; End
IF OBJECT_ID ('tempdb..#PrismHistory') IS NOT NULL Begin DROP TABLE #PrismHistory; End
IF OBJECT_ID ('tempdb..##OverdueData') IS NOT NULL Begin DROP TABLE ##OverdueData; End
IF OBJECT_ID ('tempdb..#TrackGeometry') IS NOT NULL Begin DROP TABLE #TrackGeometry; End
IF OBJECT_ID ('tempdb..#TrackReport') IS NOT NULL Begin DROP TABLE #TrackReport; End

SET DATEFORMAT ymd
SET XACT_ABORT ON
SET NOCOUNT ON
SET ANSI_WARNINGS OFF

--===============================================================================================================================
-- 1.0 Set and declare variables
--===============================================================================================================================
--Debug Settings
	DECLARE @Debug as int = 1								-- If set to 0 = live automation from exe, 1 = Psuedo live (keep data), 2 = dubug mode (clear and reset tables)

--Calculation Settings
	DECLARE @CalculationFrequency as int = 0				-- The required frequency (in minutes) of calcualtions. i.e the time spacing between required calculations.
	DECLARE @DataExtractionWindow as int = 12				-- Number of hours to look back when extracting data for the calculations
	DECLARE @AverageData as bit = 1							-- Identifier to enable or disable averaging of extracted data (1 = enable, 0 = disable)
	DECLARE @PrismSpacingLimit as decimal(38,10) = 12		-- A value (in meters) used to check the spacing between track prisms any prisms separated by more than this value will not get geometry calculations.

	DECLARE @ChainageStep decimal(38,10) = 1				-- The spacing at which you want to calculate track geometry at. i.e. every x meters.
	DECLARE @ShortTwistStep decimal(38,10) = 3			-- The spacing at which short twist should be calculated, looking in reverse chainage.
	DECLARE @LongTwistStep decimal(38,10) = 10				-- The spacing at which long twist should be calculated, looking in reverse chainage.

	DECLARE @ShortLineChord decimal(38,10) = 10				-- The chord length for the short line calculation, looking forward and back half of this length from reference chainage.
	DECLARE @LongLineChord decimal(38,10) = 20				-- The chord length for the long line calculation, looking forward and back half of this length from reference chainage.
	DECLARE @ShortTopChord decimal(38,10) = 10				-- The chord length for the short top calculation, looking forward and back half of this length from reference chainage.
	DECLARE @LongTopChord decimal(38,10) = 20				-- The chord length for the long top calculation, looking forward and back half of this length from reference chainage.

	DECLARE @LeftRailIndicator varchar(30) = 'LR'			-- Search string to identify all left rail prisms. Script will try to find a string match in the instrument name and group point as a left rail prism.
	DECLARE @RightRailIndicator varchar(30) = 'RR'			-- Search string to identify all right rail prisms. Script will try to find a string match in the instrument name and group point as a right rail prism.
	DECLARE @ChainageNameFormat varchar(256) = '#'		-- Format string applied to calcualtion chainage when determinig the geometry name for each instrument


--Section for setting variable values from sqlcmd prompt
IF (@Debug = 0) 
	BEGIN

		IF '$(CalculationFrequency)' IS NULL OR '$(CalculationFrequency)'='' OR '$(CalculationFrequency)'<0 SET @CalculationFrequency=0 ELSE SET @CalculationFrequency = CAST('$(CalculationFrequency)' as int)
		IF '$(DataExtractionWindow)' IS NULL OR '$(DataExtractionWindow)'='' OR '$(DataExtractionWindow)'<0 SET @DataExtractionWindow=96 ELSE SET @DataExtractionWindow = CAST('$(DataExtractionWindow)' as int)
		IF '$(PrismSpacingLimit)' IS NULL OR '$(PrismSpacingLimit)'='' OR '$(PrismSpacingLimit)'<CAST(0.0 as decimal (30,10)) SET @PrismSpacingLimit=4.0 ELSE SET @PrismSpacingLimit = CAST('$(PrismSpacingLimit)' as decimal(30,10))
		IF '$(ChainageStep)' IS NULL OR '$(ChainageStep)'='' OR '$(ChainageStep)'<CAST(0.0 as decimal (30,10)) SET @ChainageStep=1.0 ELSE SET @ChainageStep = CAST('$(ChainageStep)' as decimal(30,10))
		IF '$(ShortTwistStep)' IS NULL OR '$(ShortTwistStep)'='' OR '$(ShortTwistStep)'<CAST(0.0 as decimal (30,10)) SET @ShortTwistStep=2.0 ELSE SET @ShortTwistStep = CAST('$(ShortTwistStep)' as decimal(30,10)) 
		IF '$(LongTwistStep)' IS NULL OR '$(LongTwistStep)'='' OR '$(LongTwistStep)'<CAST(0.0 as decimal (30,10)) SET @LongTwistStep=14.0 ELSE SET @LongTwistStep = CAST('$(LongTwistStep)' as decimal(30,10))
		IF '$(ShortLineChord)' IS NULL OR '$(ShortLineChord)'='' OR '$(ShortLineChord)'<CAST(0.0 as decimal (30,10)) SET @ShortLineChord=10.0 ELSE SET @ShortLineChord = CAST('$(ShortLineChord)' as decimal(30,10))
		IF '$(LongTopChord)' IS NULL OR '$(LongTopChord)'='' OR '$(LongTopChord)'<CAST(0.0 as decimal (30,10)) SET @LongLineChord=20.0 ELSE SET @LongLineChord = CAST('$(LongLineChord)' as decimal(30,10))
		IF '$(ShortTopChord)' IS NULL OR '$(ShortTopChord)'='' OR '$(ShortTopChord)'<CAST(0.0 as decimal (30,10)) SET @ShortTopChord=10.0 ELSE SET @ShortTopChord = CAST('$(ShortTopChord)' as decimal(30,10))
		IF '$(LongTopChord)' IS NULL OR '$(LongTopChord)'='' OR '$(LongTopChord)'<CAST(0.0 as decimal (30,10)) SET @LongTopChord=20.0 ELSE SET @LongTopChord = CAST('$(LongTopChord)' as decimal(30,10))
		IF '$(LeftRailIndicator)'='' SET @LeftRailIndicator='L' ELSE SET @LeftRailIndicator= '$(LeftRailIndicator)'
		IF '$(RightRailIndicator)'='' SET @RightRailIndicator='R' ELSE SET @RightRailIndicator='$(RightRailIndicator)'
		IF '$(ChainageNameFormat)'='' SET @ChainageNameFormat='#.000' ELSE SET @ChainageNameFormat='$(ChainageNameFormat)'

	END


--===============================================================================================================================
-- 1.1 Inform the user of settings: Print settings to log file
--=============================================================================================================================== 
	PRINT 'CURRENT SCRIPT SETTINGS:'  + Char(13) 
	PRINT ' - Calculation frequency: '+ CAST(@CalculationFrequency as varchar) + ' min | Repeat calculations if last calculations were performed more than ' + CAST(@CalculationFrequency as varchar) + ' minutes ago.'
	PRINT ' - Data extraction window: ' + CAST(@DataExtractionWindow as varchar) + ' hrs | Gather GeoMoS prism data that has been observed within the last ' + CAST(@DataExtractionWindow as varchar) + ' hours.'
	PRINT ' - Prism spacing limit: ' + CAST(CAST(@PrismSpacingLimit as decimal(5,1)) as varchar) + 'm | Do not perform track coordinate interpolation when prism data is separated by more than ' + CAST(CAST(@PrismSpacingLimit as decimal(5,1)) as varchar) + ' meters.'
	PRINT ' - Track interpolation step: ' + CAST(CAST(@ChainageStep as decimal(5,1)) as varchar) + 'm | Calculate interpolated track locations at chainages increasing in ' + CAST(CAST(@ChainageStep as decimal(5,1)) as varchar) + ' meter steps.'
	PRINT ' - Geometry name chainage format: '+ CAST(@ChainageNameFormat as varchar) + ' | Format string for chainage component of each geometry calculation set.'
	PRINT ' - Short Twist Step: '+ CAST(CAST(@ShortTwistStep as decimal(5,1)) as varchar) + 'm | Chainage spacing for short twist calculations (looking back from the calculation chainage).'
	PRINT ' - Long Twist Step: ' + CAST(CAST(@LongTwistStep as decimal(5,1)) as varchar) + 'm | Chainage spacing for long twist calculations (looking back from the calculation chainage).'
	PRINT ' - Short Line Chord: ' + CAST(CAST(@ShortLineChord as decimal(5,1)) as varchar) + 'm | Chord length for short line (horizontal versine) calculations (looking back and forward half of the chord length from the calculation chainage).'
	PRINT ' - Long Line Chord: ' + CAST(CAST(@LongLineChord as decimal(5,1)) as varchar) + 'm |  Chord length for long line (horizontal versine) calculations (looking back and forward half of the chord length from the calculation chainage).'
	PRINT ' - Short Top Chord: ' + CAST(CAST(@ShortTopChord as decimal(5,1)) as varchar) + 'm |  Chord length for short top (vertical versine) calculations (looking back and forward half of the chord length from the calculation chainage).'
	PRINT ' - Long Top Chord: ' + CAST(CAST(@LongTopChord as decimal(5,1)) as varchar) + 'm | Chord length for long top (vertical versine) calculations (looking back and forward half of the chord length from the calculation chainage).'
	PRINT ' - Left Rail Indicator: ' + CAST(@LeftRailIndicator as varchar) + ' | String identifier for left rail points. Must match with left rail names from GeoMoS.'
	PRINT ' - Right Rail Indicator: ' + CAST(@RightRailIndicator as varchar) + ' | String identifier for right rail points. Must match with right rail names from GeoMoS.' + Char(13)

--===============================================================================================================================
-- 2.0 Commence track geometry calculations
--===============================================================================================================================

-- Print a message indicating the start of calculations
    PRINT 'COMMENCING TRACK GEOMETRY CALCULATIONS:' + CHAR(13);

-- Declare variables for error handling and control flow
	DECLARE @Calculation_Check INT = 0; -- 0 = no calculations, 1 = at least one calculation, 3 = Error encountered
	DECLARE @CalculationWarning INT = 0;
	DECLARE @PrismTotalCount INT = 0;
	DECLARE @TrackTotal INT = 0;

--Declare dynamic script variables
	DECLARE @Database_Script varchar(max)

--Data extraction variables
	DECLARE @TrackCounter int, @CalculationID int
	DECLARE @CurrentTrack as varchar(100), @TrackID int
	DECLARE @CurrentSection as varchar(max)
	DECLARE @CalcStartChainage as decimal(38,10)
	DECLARE @CalcEndChainage as decimal(38,10)
	DECLARE @ExpectedDatabase as varchar(max)
	DECLARE @ScriptStartDateTime datetime = GETDATE()
	DECLARE @CurrentDateTime datetime = GETDATE(), @LastRailCalcTime datetime
	DECLARE @ExtractStartTime datetime, @ExtractEndTime datetime
	DECLARE @PrismCount int, @TrackCalculationTime int

--Track alignment variables
	DECLARE @ChainageIndex as decimal(30,5), @Diff_Chainage_Left decimal(30,5), @Diff_Chainage_Rght decimal(30,5)
	DECLARE @Prev_PointName varchar(100), @Prev_Chainage decimal(38,10), @Prev_Easting decimal(38,10), @Prev_Northing decimal(38,10), @Prev_Height decimal(38,10)
	DECLARE @Next_PointName varchar(100), @Next_Chainage decimal(38,10), @Next_Easting decimal(38,10), @Next_Northing decimal(38,10), @Next_Height decimal(38,10)		
	DECLARE @Left_Easting decimal(38,10), @Left_Northing decimal(38,10), @Left_Height decimal(38,10)
	DECLARE @Rght_Easting decimal(38,10), @Rght_Northing decimal(38,10), @Rght_Height decimal(38,10)

--Track geometry variables
	DECLARE @Track_Cant decimal(38,10), @Track_Guage decimal(38,10), @Twist_Short decimal(38,10), @Twist_Long decimal(38,10)
	DECLARE @CalculationComment varchar(max), @PrismComment varchar(max)

	DECLARE @Param_Top float, @Param_Line float, @Param_Radius float
	DECLARE @Side_A float, @Side_B float, @Side_C float
	DECLARE @Bearing_LongChord decimal(38,10), @Bearing_MidChord decimal(38,10), @Bearing_Diff decimal(38,10)
	DECLARE @Data_E_From decimal(38,10), @Data_N_From decimal(38,10), @Data_H_From decimal(38,10)
	DECLARE @Data_E_At decimal(38,10), @Data_N_At decimal(38,10), @Data_H_At decimal(38,10)
	DECLARE @Data_E_To decimal(38,10), @Data_N_To decimal(38,10), @Data_H_To decimal(38,10)

--===============================================================================================================================
-- 2.1 Check inital calculation variables for compatability
--=============================================================================================================================== 
--Check to see if the provided calculation chord lengths and steps are compatable
	BEGIN TRY
		IF @ShortTwistStep % @ChainageStep <> 0 OR 
		   @LongTwistStep % @ChainageStep <> 0 OR 
		   @ShortLineChord % @ChainageStep <> 0 OR 
		   @LongLineChord % @ChainageStep <> 0 OR 
		   @ShortTopChord % @ChainageStep <> 0 OR 
		   @LongTopChord % @ChainageStep <> 0
		BEGIN
			-- Force an error using RAISERROR
			RAISERROR('The provided "ChainageStep" and chord lengths are not compatible.', 16, 1);
		END
	END TRY
	BEGIN CATCH
		-- Print the error message with a timestamp
		PRINT '   ' + CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Compatibility check failed: ' + ERROR_MESSAGE();
		PRINT CHAR(13) + '   Modulo of provided "ChainageStep" and twist step or top/line chord length variables are not equal to 0.';
		PRINT '   Geometry parameters cannot be calculated when the stepped interpolation of track prisms does not align with the required calculation lengths.';
		PRINT '   Please adjust the "ChainageStep" variable to align with the provided chord lengths or vice versa.' + CHAR(13);
		PRINT '      Modulo of short twist step = ' + STR(@ShortTwistStep % @ChainageStep, 5, 2);
		PRINT '      Modulo of long twist step = ' + STR(@LongTwistStep % @ChainageStep, 5, 2);
		PRINT '      Modulo of short line chord = ' + STR(@ShortLineChord % @ChainageStep, 5, 2);
		PRINT '      Modulo of long line chord = ' + STR(@LongLineChord % @ChainageStep, 5, 2);
		PRINT '      Modulo of short top chord = ' + STR(@ShortTopChord % @ChainageStep, 5, 2);
		PRINT '      Modulo of long top chord = ' + STR(@LongTopChord % @ChainageStep, 5, 2);

		PRINT CHAR(13) + '   ' +  convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Exiting Track Geometry script.'
		RETURN;
	END CATCH;

--Set adjustment lengths for chord based calculations
	SET @ShortLineChord = @ShortLineChord/2
	SET @LongLineChord = @LongLineChord/2
	SET @ShortTopChord = @ShortTopChord/2
	SET @LongTopChord = @LongTopChord/2

--===============================================================================================================================
-- X.X Start of time based iteration loops for historic calculations
--=============================================================================================================================== 

--Clear the historic data tables prior to running new calculations
SET @Database_Script =	'USE [Automated Track Geometry] DELETE FROM GeometryHistory DELETE FROM PrismHistory'
EXEC (@Database_Script)

-- Set the date range and interval
DECLARE @Historic_StartTime DATETIME = '2024-07-29 00:00:00'; -- Start time
DECLARE @Historic_EndTime DATETIME = '2024-09-09 00:00:00';   -- End time
DECLARE @Historic_TrackCode	VARCHAR(MAX) = 'QRD'
DECLARE @Historic_Track_Section	VARCHAR(MAX) = '65590-65835'
DECLARE @Historic_TimeStep INT = 1; -- Time step in hours (e.g., 24 for 1 day intervals)

PRINT '   ' + 'Historic processing for interval: ' + CONVERT(VARCHAR, @Historic_StartTime, 103) + ' ' + FORMAT(@Historic_StartTime, 'HH:mm') + ' to ' + CONVERT(VARCHAR, @Historic_EndTime, 103) + ' ' + FORMAT(@Historic_EndTime, 'HH:mm');

--===============================================================================================================================
-- 2.2 Retrieve track information to initalise calculation parameters
--=============================================================================================================================== 
BEGIN TRY
	SET @Database_Script = 'USE [Automated Track Geometry]
							SELECT ROW_NUMBER() OVER(ORDER BY [Track_Name] ASC) AS Row_ID, 
									[ID], 
									[Track_Code], 
									[Expected_Database], 
									[Calculation_Time], 
									[Track_Section],  
									[Start_Chainage], 
									[End_Chainage],
									(SELECT MAX([Calculation_ID]) FROM [GeometryHistory]) AS [Calculation_ID]
							INTO ##CalculationListing 
							FROM [TrackListing] 
							WHERE [Track_Code] = '''+ @Historic_TrackCode +''' AND [Track_Section] = '''+ @Historic_Track_Section +''';'
	EXEC (@Database_Script);
	--Note: Enable below for testing/debugging
	--SELECT * FROM ##CalculationListing
END TRY
BEGIN CATCH
	-- Print the error message with a timestamp
	PRINT '   ' + CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Error occurred while retrieving track information: ' + ERROR_MESSAGE();
	PRINT CHAR(13) + '   ' +  convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Exiting Track Geometry script.'
	RETURN;

END CATCH;

-- Initialize the current time
SET @CurrentDateTime = @Historic_StartTime;

WHILE @CurrentDateTime <= @Historic_EndTime
BEGIN
	--===============================================================================================================================
	-- 2.3 Initialize track and calculation counters
	--===============================================================================================================================
	-- Use a single query to retrieve all the required values
		SELECT 
			@TrackCounter = MIN(Row_ID), 
			--@CalculationID = MAX(Calculation_ID), 
			@TrackTotal = COUNT(ID)
			--@TrackCalculationTime = SUM(CASE WHEN Calculation_Time < DATEADD(MINUTE, -@CalculationFrequency, @CurrentDateTime) THEN 1 ELSE 0 END)
		FROM ##CalculationListing;

	-- Print track information
		PRINT '   ' + CAST(@TrackTotal AS VARCHAR) + ' tracks currently enabled for calculation.';
		--PRINT '   ' + CAST(@TrackCalculationTime AS VARCHAR) + ' tracks currently within the specified calculation window.';

	--===============================================================================================================================
	-- 3.0 Start calculation loop through the current ##CalculationListing line entries
	--===============================================================================================================================
	WHILE @TrackCounter IS NOT NULL --While you are not at the end of the calcualtion listing
		BEGIN

			-- Retrieve track information for the current rail line
				SELECT 
					@CurrentTrack = Track_Code,
					@CurrentSection = Track_Section,
					@CalcStartChainage = Start_Chainage,
					@CalcEndChainage =  End_Chainage,
					@TrackID = ID, 
					@ExpectedDatabase = Expected_Database, 
					@LastRailCalcTime = Calculation_Time
				FROM ##CalculationListing
				WHERE Row_ID = @TrackCounter;

				--Force the date check to be less than the last rail calculation time
				SET	@Calculation_Check = 0
				SET @LastRailCalcTime = DateADD(DAY, -9999, @LastRailCalcTime)

				-- Update the data extraction window based on the current time
				SET @ExtractStartTime = DATEADD(HOUR, -@DataExtractionWindow, @CurrentDateTime);
				SET @ExtractEndTime = @CurrentDateTime;

			--===============================================================================================================================================
			-- 3.1 Start of rail analysis calculation trigger - check if the current rail line is due another calcualtion round based on time
			--===============================================================================================================================================
			IF	@CurrentDateTime > DateADD(MINUTE, @CalculationFrequency, @LastRailCalcTime)  --AND @ExpectedDatabase = DB_NAME() 
				BEGIN
				
					--Set to the expected database for execution
						SET @Database_Script = 'USE [' + @ExpectedDatabase +']';
						EXEC (@Database_Script);

					--Determine the calculation ID for the given dataset
						IF @CalculationID IS NULL 
							SET @CalculationID = 1
						ELSE 
							SET @CalculationID = @CalculationID + 1
							PRINT CHAR(13) + ' - Calculation set: ' + CAST(@CalculationID as varchar) + '.'
							PRINT '   Track ID: ' + CAST(@TrackID as varchar) + ', Track Code: ' + CAST(@CurrentTrack as varchar) + ', Track Section: ' + CAST(@CurrentSection as varchar)+ '.'

					--Determine the start datetime for the data extraction
						SELECT @ExtractStartTime = DATEADD(hh, -@DataExtractionWindow, @CurrentDateTime), @ExtractEndTime = @CurrentDateTime;
						PRINT '   ' + convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Extraction Window: '+ CONVERT(VARCHAR, @ExtractStartTime, 103) + ' ' + FORMAT(@ExtractStartTime, 'HH:mm') + ' to '+ CONVERT(VARCHAR, @ExtractEndTime, 103) + ' ' + FORMAT(@ExtractEndTime, 'HH:mm')+'.'

					--Update the TrackListing table with the new calculation time
						SET @Database_Script=	'USE [Automated Track Geometry] UPDATE [TrackListing] SET [Calculation_Time] = CONVERT(datetime,''' 
												+ CONVERT(varchar, @CurrentDateTime, 109) + ''', 109) WHERE [ID] = ' + CONVERT(varchar, @TrackID)
						EXEC (@Database_Script)
				
				
					--===============================================================================================================================================
					-- 3.2 Gather prism data and offset to track
					--===============================================================================================================================================
					--Create temporary table #PrismHistory to store all the required prism and track coordinate data
						IF OBJECT_ID ('tempdb..#PrismHistory') IS NULL 
						CREATE TABLE	#PrismHistory	([Calculation_ID] int, [Point_Name] nvarchar(100) NULL, [Point_Epoch] dateTime NULL, [Point_Group] nvarchar(100) NULL, 
													[Point_ExpTime_DD] decimal(38,10) NULL, [Point_Easting] decimal(38,10) NULL,	[Point_Northing] decimal(38,10) NULL, [Point_Height] decimal(38,10) NULL, [Point_EOffset] decimal(38,10) NULL, 
													[Point_NOffset] decimal(38,10) NULL, [Point_HOffset] decimal(38,10) NULL,	[Track_Chainage] decimal(38,10) NULL, [Track_Section] nvarchar(100) NULL, [Track_RailSide] nvarchar(100) NULL,  
													[Track_Code] nvarchar(100) NULL, [Track_Easting] decimal(38,10) NULL,	[Track_Northing] decimal(38,10) NULL, [Track_Height] decimal(38,10) NULL, [Epoch_Index] int NULL, [Point_Remark] nvarchar(MAX) NULL)

					-- Store relevant data containing all the latest readings inside the given extraction window into the #PrismHistory table				
						IF @AverageData = 1
							BEGIN
								BEGIN TRY
									PRINT '   ' + CONVERT(varchar, GETDATE(),103) + ' ' + CONVERT(varchar, GETDATE(), 14) + ' | Starting prism data extraction (average of available data).'
									INSERT INTO #PrismHistory 
									SELECT	@CalculationID AS Calculation_ID, 
											Min(Points.Name) AS Point_Name, Max(Results.Epoch) AS Point_Epoch, Max(PointGroups.Name) AS Point_Group, 
											DateDIFF(SECOND, MAX(Results.Epoch), @CurrentDateTime) / 86400.0 as [Point_ExpTime_DD],
											AVG(Results.Easting) AS Point_Easting,	AVG(Results.Northing) AS Point_Northing, AVG(Results.Height) AS Point_Height, 
											CONVERT(DECIMAL(38, 10), dbo.ParseString(Max(Points.Description), 'XOS:', 'decimal')) AS Point_EOffset,
											CONVERT(DECIMAL(38, 10), dbo.ParseString(Max(Points.Description), 'YOS:', 'decimal')) AS Point_NOffset, 
											CONVERT(DECIMAL(38, 10), dbo.ParseString(Max(Points.Description), 'ZOS:', 'decimal')) AS Point_HOffset,
											CONVERT(DECIMAL(38, 10), dbo.ParseString(Max(Points.Description), 'CHN:', 'decimal')) AS Track_Chainage,
											CONVERT(VARCHAR(100), dbo.ParseString(Max(Points.Description), 'SEC:', 'varchar')) AS Track_Section,
											CASE 
												WHEN Min(Points.Name) LIKE '%' + @LeftRailIndicator + '%' THEN 'Left'
												WHEN Min(Points.Name) LIKE '%' + @RightRailIndicator + '%' THEN 'Right'
											END AS Track_RailSide, 
											@CurrentTrack AS Track_Code, 
											NULL AS Track_Easting, NULL AS Track_Northing, NULL AS Track_Height, NULL Epoch_Index,
											'Observations: ' + CAST(COUNT(Points.Name) AS NVARCHAR) +  
											' | X Range: ' + FORMAT((MAX(Results.Easting) - MIN(Results.Easting))*1000, 'N1') +
											' | Y Range: ' + FORMAT((MAX(Results.Northing) - MIN(Results.Northing))*1000, 'N1') +
											' | Z Range: ' + FORMAT((MAX(Results.Height) - MIN(Results.Height))*1000, 'N1') AS Point_Remark
									FROM	Results 
											INNER JOIN Points ON Results.Point_ID = Points.ID 
											LEFT OUTER JOIN PointGroups 
											INNER JOIN PointGroupItems ON PointGroups.ID = PointGroupItems.PointGroup_ID 
											ON Points.ID = PointGroupItems.Point_ID 
									WHERE	Results.Type = 0 
											AND Results.Epoch >= @ExtractStartTime AND Results.Epoch < @ExtractEndTime AND Points.Name LIKE '%' + @CurrentTrack + '%' 
											AND (Points.Name LIKE '%' + @LeftRailIndicator + '%' OR Points.Name LIKE '%' + @RightRailIndicator + '%') 
											AND dbo.ParseString(Points.Description, 'CHN:', 'varchar') IS NOT NULL 
											AND dbo.ParseString(Points.Description, 'SEC:', 'varchar') LIKE @CurrentSection
									GROUP BY Points.Name
								END TRY
								BEGIN CATCH
									-- Print the error message
									PRINT '   ' + CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Error occurred during prism data extraction: ' + ERROR_MESSAGE() ;
									RETURN
								END CATCH;
							END

						ELSE
							BEGIN
								BEGIN TRY
									PRINT '   ' + CONVERT(varchar, GETDATE(),103) + ' ' + CONVERT(varchar, GETDATE(), 14) + ' | Starting prism data extraction (latest available data).'
									INSERT INTO #PrismHistory
									SELECT * FROM 
										(	SELECT 
												@CalculationID AS Calculation_ID, 
												Points.Name AS Point_Name, Results.Epoch AS Point_Epoch, PointGroups.Name AS Point_Group,
												DateDIFF(SECOND, Results.Epoch, @CurrentDateTime) / 86400.0 as [Point_ExpTime_DD],
												Results.Easting AS Point_Easting, Results.Northing AS Point_Northing, Results.Height AS Point_Height, 
												CONVERT(DECIMAL(38, 10), dbo.ParseString(Points.Description, 'XOS:', 'decimal')) AS Point_EOffset,
												CONVERT(DECIMAL(38, 10), dbo.ParseString(Points.Description, 'YOS:', 'decimal')) AS Point_NOffset, 
												CONVERT(DECIMAL(38, 10), dbo.ParseString(Points.Description, 'ZOS:', 'decimal')) AS Point_HOffset,
												CONVERT(DECIMAL(38, 10), dbo.ParseString(Points.Description, 'CHN:', 'decimal')) AS Track_Chainage,
												CONVERT(VARCHAR(100), dbo.ParseString(Points.Description, 'SEC:', 'varchar')) AS Track_Section,
												CASE 
													WHEN Points.Name LIKE '%' + @LeftRailIndicator + '%' THEN 'Left'
													WHEN Points.Name LIKE '%' + @RightRailIndicator + '%' THEN 'Right'
												END AS Track_RailSide, 
												@CurrentTrack AS Track_Code, 
												NULL AS Track_Easting, NULL AS Track_Northing, NULL AS Track_Height, 
												ROW_NUMBER() OVER (PARTITION BY Points.Name ORDER BY Results.Epoch DESC) AS Epoch_Index,
												'Observations: 1'+  
												' | Data Age: ' + FORMAT(DateDIFF(SECOND, Results.Epoch, @CurrentDateTime) / 86400.0, 'N1') + ' Days' AS Point_Remark
											FROM 
												Results 
												INNER JOIN Points ON Results.Point_ID = Points.ID 
												LEFT OUTER JOIN PointGroups 
												INNER JOIN PointGroupItems ON PointGroups.ID = PointGroupItems.PointGroup_ID 
												ON Points.ID = PointGroupItems.Point_ID
											WHERE 
												Results.Type = 0 
												AND Results.Epoch >= @ExtractStartTime AND Results.Epoch < @ExtractEndTime AND Points.Name LIKE '%' + @CurrentTrack + '%' 
												AND (Points.Name LIKE '%' + @LeftRailIndicator + '%' OR Points.Name LIKE '%' + @RightRailIndicator + '%') 
												AND dbo.ParseString(Points.Description, 'CHN:', 'varchar') IS NOT NULL 
												AND dbo.ParseString(Points.Description, 'SEC:', 'varchar') LIKE @CurrentSection
										) AS AllData
									WHERE 
										AllData.Epoch_Index = 1;	
								END TRY
								BEGIN CATCH
									-- Print the error message
									PRINT '   ' + CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Error occurred during prism data extraction: ' + ERROR_MESSAGE();
									RETURN
								END CATCH;
							END;
				
					-- Shift prism coordinate data onto the track via the defined offset values in the point description field
						UPDATE #PrismHistory SET Track_Easting = Point_Easting + Point_EOffset;
						UPDATE #PrismHistory SET Track_Northing = Point_Northing + Point_NOffset;
						UPDATE #PrismHistory SET Track_Height = Point_Height + Point_HOffset;

					-- Get prism extraction data for printing results of extraction to log
						SELECT @PrismCount = COUNT(Point_Name) FROM #PrismHistory;
						SET @PrismTotalCount = @PrismTotalCount + @PrismCount;
						PRINT '   ' + CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | ' + CAST(@PrismCount AS VARCHAR) + ' valid observations extracted.';

					--===============================================================================================================================================
					-- 3.3 Start track geometry calculations
					--===============================================================================================================================================
					--If there is no prism data for the current track, skip the interpolation and and track geometry calculation steps
					IF @PrismCount = 0
						PRINT '   ' + convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Skipping track geometry routine.'
					ELSE
						BEGIN
							PRINT '   ' + convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Starting track geometry calculations.'

							--===============================================================================================================================================
							-- 3.3.1 Begin building of track geometry table
							--===============================================================================================================================================
							IF OBJECT_ID ('tempdb..#TrackGeometry') IS NULL 
							CREATE TABLE #TrackGeometry	([Calculation_ID] int, [Track_CL_Chainage] decimal(38,10), [Track_Code] varchar(100) NULL, [Track_Section] varchar(100) NULL,
														[DataWindow_Start] datetime, [DataWindow_End] datetime,
														[Rail_Cant] decimal (20,6), [Rail_Gauge] decimal (20,6), [Twist_Short] decimal(38,10), [Twist_Long] decimal (20,6),
														[LR_ID] varchar(100), [LR_Easting] decimal (20,6), [LR_Northing] decimal (20,6), [LR_Height] decimal (20,6), 
														[LR_Radius] decimal (20,6), [LR_Top_Short] decimal (20,6), [LR_Top_Long] decimal (20,6), [LR_Line_Short] decimal (20,6),
														[LR_Line_Long] decimal (20,6), [RR_ID] varchar(100), [RR_Easting] decimal (20,6), [RR_Northing] decimal (20,6), 
														[RR_Height] decimal (20,6), [RR_Radius] decimal (20,6), [RR_Top_Short] decimal (20,6), [RR_Top_Long] decimal (20,6),
														[RR_Line_Short] decimal (20,6), [RR_Line_Long] decimal (20,6), [CL_ID] varchar(100), [CL_Easting] decimal (20,6),
														[CL_Northing] decimal (20,6), [CL_Height] decimal (20,6), [CL_Radius] decimal (20,6), [CL_Top_Short] decimal (20,6),
														[CL_Top_Long] decimal (20,6), [CL_Line_Short] decimal (20,6), [CL_Line_Long] decimal (20,6), [Diff_Chainage_Left] decimal(20,6), 
														[Diff_Chainage_Rght] decimal(20,6), [Calculation_Comment] varchar(max), [Prism_Comment]varchar(max))

							--===============================================================================================================================================
							-- 3.3.2 Determine track alignment at given interpolation step interval - Start of first chainage loop
							--===============================================================================================================================================
							-- Print min and max chainage limits
							PRINT '   ' + CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Starting track interpolation calculations at a ' + CAST(CAST(@ChainageStep AS DECIMAL(10,1)) AS VARCHAR) + ' meter step.' 
							PRINT '   ' + CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Chainage limits: Min = ' + FORMAT(@CalcStartChainage, 'N1') + ', Max = ' + FORMAT(@CalcEndChainage, 'N1') + '.'
							PRINT '   ' + CONVERT(varchar, GETDATE(), 103) + ' ' + CONVERT(varchar, GETDATE(), 14) + ' | Calculating cross track parameters (Gauge, Cant, Twist).'

							-- Initialize the chainage index
							SET @ChainageIndex = @CalcStartChainage;

							-- Start the interpolation calculations
							WHILE @ChainageIndex <= @CalcEndChainage
								BEGIN
				
									--Reset all variables to maintain NULL storage of out of bound data
									SELECT  @Diff_Chainage_Left = NULL, @Diff_Chainage_Rght = NULL
									SELECT @Prev_PointName = NULL, @Prev_Chainage = NULL, @Prev_Easting = NULL, @Prev_Northing = NULL, @Prev_Height = NULL
									SELECT @Next_PointName = NULL, @Next_Chainage = NULL, @Next_Easting = NULL, @Next_Northing = NULL, @Next_Height = NULL		
									SELECT @Left_Easting = NULL, @Left_Northing = NULL, @Left_Height = NULL
									SELECT @Rght_Easting = NULL, @Rght_Northing = NULL, @Rght_Height = NULL
									SELECT @Track_Cant = NULL, @Track_Guage = NULL, @Twist_Short = NULL, @Twist_Long = NULL
									SELECT @CalculationComment = NULL
									SELECT @PrismComment = NULL

									--Get previous left rail data
									SELECT	TOP 1 @Prev_PointName=[Point_Name], @Prev_Chainage=[Track_Chainage], @Prev_Easting=[Track_Easting], @Prev_Northing=[Track_Northing], @Prev_Height=[Track_Height]
									FROM	#PrismHistory WHERE [Track_Chainage] < @ChainageIndex and [Track_RailSide] = 'Left' ORDER BY [Track_Chainage] DESC
									--Get next left rail data
									SELECT	TOP 1 @Next_PointName=[Point_Name], @Next_Chainage=[Track_Chainage], @Next_Easting=[Track_Easting], @Next_Northing=[Track_Northing], @Next_Height=[Track_Height]
									FROM	#PrismHistory WHERE [Track_Chainage] >= @ChainageIndex and [Track_RailSide] = 'Left' ORDER BY [Track_Chainage] ASC
								
									--Set left rail chainage difference
									SET @Diff_Chainage_Left = @Next_Chainage - @Prev_Chainage
								
									SET @PrismComment = 'LR Start: ' + @Prev_PointName + ' | LR End: ' + @Next_PointName

									--Check that left rail prism gap is not larger than the provided limit
									IF @Diff_Chainage_Left <= @PrismSpacingLimit
										BEGIN
											--Interploate left rail point at the current @ChainageIndex value
											SET @Left_Easting = (@ChainageIndex - @Prev_Chainage) * (@Next_Easting - @Prev_Easting) / NULLIF(@Diff_Chainage_Left,0) + @Prev_Easting
											SET @Left_Northing = (@ChainageIndex - @Prev_Chainage) * (@Next_Northing - @Prev_Northing) / NULLIF(@Diff_Chainage_Left,0) + @Prev_Northing
											SET @Left_Height = (@ChainageIndex - @Prev_Chainage) * (@Next_Height - @Prev_Height) / NULLIF(@Diff_Chainage_Left,0) + @Prev_Height
										END

									--Get previous right rail data
									SELECT	TOP 1 @Prev_PointName=[Point_Name], @Prev_Chainage=[Track_Chainage], @Prev_Easting=[Track_Easting], @Prev_Northing=[Track_Northing], @Prev_Height=[Track_Height]
									FROM	#PrismHistory WHERE [Track_Chainage] < @ChainageIndex and [Track_RailSide] = 'Right' ORDER BY [Track_Chainage] DESC
									--Get next right rail data
									SELECT	TOP 1 @Next_PointName=[Point_Name], @Next_Chainage=[Track_Chainage], @Next_Easting=[Track_Easting], @Next_Northing=[Track_Northing], @Next_Height=[Track_Height]
									FROM	#PrismHistory WHERE [Track_Chainage] >= @ChainageIndex and [Track_RailSide] = 'Right' ORDER BY [Track_Chainage] ASC
								
									--Set right rail chainage difference
									SET @Diff_Chainage_Rght = @Next_Chainage - @Prev_Chainage

									SET @PrismComment = @PrismComment + ' | RR Start: ' + @Prev_PointName + ' | RR End: ' + @Next_PointName

									--Check that right rail prism gap is not larger than the provided limit
									IF @Diff_Chainage_Rght <= @PrismSpacingLimit
										BEGIN
											--Interploate right rail point at the current @ChainageIndex value
											SET @Rght_Easting = (@ChainageIndex - @Prev_Chainage) * (@Next_Easting - @Prev_Easting) / NULLIF(@Diff_Chainage_Rght,0) + @Prev_Easting
											SET @Rght_Northing = (@ChainageIndex - @Prev_Chainage) * (@Next_Northing - @Prev_Northing) / NULLIF(@Diff_Chainage_Rght,0) + @Prev_Northing
											SET @Rght_Height = (@ChainageIndex - @Prev_Chainage) * (@Next_Height - @Prev_Height) / NULLIF(@Diff_Chainage_Rght,0) + @Prev_Height
										END

									--Check that left and right rail prism gap is not larger than the provided limit
									IF @Diff_Chainage_Left <= @PrismSpacingLimit OR @Diff_Chainage_Rght <= @PrismSpacingLimit
										BEGIN	
											--Calculate the fixed location track geometry parameters
											SET @Track_Cant = @Left_Height - @Rght_Height
											SET @Track_Guage = SQRT(SQUARE(@Left_Easting - @Rght_Easting) + SQUARE(@Left_Northing - @Rght_Northing) + SQUARE(@Left_Height - @Rght_Height))
											SET @Twist_Short = @Track_Cant - (SELECT Rail_Cant FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND((@ChainageIndex - @ShortTwistStep),2))
											SET @Twist_Long = @Track_Cant - (SELECT Rail_Cant FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND((@ChainageIndex - @LongTwistStep),2))
										END
									ELSE 
										BEGIN
											SET @CalculationWarning = @CalculationWarning + 1
											SET @CalculationComment = 'Prism spacing failed: Nearest prism location difference too large'
										END
					
									--Insert the current results into the #TrackGeometry table
									INSERT INTO #TrackGeometry	([Calculation_ID], [Track_CL_Chainage], [Track_Code], [Track_Section], [DataWindow_Start], [DataWindow_End], [Rail_Cant], [Rail_Gauge], [Twist_Short],
																[Twist_Long], [LR_ID], [LR_Easting], [LR_Northing], [LR_Height], [RR_ID], [RR_Easting], [RR_Northing], [RR_Height], [CL_ID],
																[CL_Easting], [CL_Northing], [CL_Height], [Diff_Chainage_Left], [Diff_Chainage_Rght], [Calculation_Comment], [Prism_Comment])
										VALUES	(@CalculationID, ROUND(@ChainageIndex, 2), @CurrentTrack, @CurrentSection, @ExtractStartTime, @ExtractEndTime, @Track_Cant, @Track_Guage, @Twist_Short, @Twist_Long,
												@CurrentTrack + '-LR-' + FORMAT(@ChainageIndex,@ChainageNameFormat), @Left_Easting, @Left_Northing, @Left_Height,
												@CurrentTrack + '-RR-' + FORMAT(@ChainageIndex,@ChainageNameFormat), @Rght_Easting, @Rght_Northing, @Rght_Height,
												@CurrentTrack + '-CL-' + FORMAT(@ChainageIndex,@ChainageNameFormat), (@Left_Easting + @Rght_Easting)/2, 
												(@Left_Northing + @Rght_Northing)/2, (@Left_Height + @Rght_Height)/2, @Diff_Chainage_Left, @Diff_Chainage_Rght, @CalculationComment, @PrismComment)	
					
									--Increment the chainage index and repeat the computations
									SET @ChainageIndex = @ChainageIndex + @ChainageStep
								END
						
							--===============================================================================================================================================
							-- 3.3.3 Begin along track geometry calculations - Start of second chainage loop
							--===============================================================================================================================================
							-- Print indicator of track geometry calculation loop
							PRINT '   ' + convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Calculating along track parameters (Top, Line).'
						
							--Reset chainage index
							SET @ChainageIndex = @CalcStartChainage

							WHILE @ChainageIndex <= @CalcEndChainage
								BEGIN

									--===============================================================================================================================================
									-- 3.3.3.1 Compute short top (vertical versine) values
									--===============================================================================================================================================
									IF @ChainageIndex >= @CalcStartChainage + @ShortTopChord AND @ChainageIndex <= @CalcEndChainage - @ShortTopChord
										BEGIN

											--Left Rail--------------------------------------------------------------------------------------------------------
											--Reset all left rail variables to maintain NULL storage of out of bound data
											SELECT @Data_H_From = NULL, @Data_H_At = NULL, @Data_H_To = NULL
											SELECT @Side_A = NULL, @Side_B = NULL, @Side_C = NULL
											SELECT @Param_Top = NULL, @Param_Radius = NULL
											SELECT @CalculationComment = NULL

											--Get left rail height data for current chainage index
											SELECT @Data_H_From = LR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex - @ShortTopChord,2)
											SELECT @Data_H_At = LR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
											SELECT @Data_H_To = LR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex + @ShortTopChord,2)
											SELECT @CalculationComment = Calculation_Comment FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

											IF @Data_H_At IS NOT NULL 
											BEGIN
												--Determine side parameters for radius calculation
												SET @Side_A = SQRT(SQUARE(@Data_H_At - @Data_H_From) + SQUARE(@ShortTopChord))
												SET @Side_B = SQRT(SQUARE(@Data_H_To - @Data_H_At) + SQUARE(@ShortTopChord))
												SET @Side_C = SQRT(SQUARE(@Data_H_From - @Data_H_To) + SQUARE(2 * @ShortTopChord))

												--Determine the long chord and short chord bearings (vertical angle for top)
												SELECT	@Bearing_LongChord = Bearing  FROM dbo.BearingandDistance(@ChainageIndex - (2 * @ShortTopChord), @Data_H_From, @ChainageIndex + (2 * @ShortTopChord), @Data_H_To)
												SELECT	@Bearing_MidChord = Bearing  FROM dbo.BearingandDistance(@ChainageIndex - (2 * @ShortTopChord), @Data_H_From, @ChainageIndex, @Data_H_At)
												SET		@Bearing_Diff = @Bearing_LongChord - @Bearing_MidChord

												--Check bearing difference: to avoid math error when rail is flat
												IF ABS(@Bearing_Diff)>0.00000001
													BEGIN
														SET @Param_Radius = (@Side_A * @Side_B * @Side_C) / NULLIF(SQRT((@Side_A + @Side_B + @Side_C) * (@Side_B + @Side_C - @Side_A) * (@Side_A + @Side_C - @Side_B) * (@Side_A + @Side_B - @Side_C)),0)
														SET @Param_Top = SQUARE(@Side_C) / (8 * @Param_Radius) * (@Bearing_Diff / NULLIF(ABS(@Bearing_Diff),0))
													END
												ELSE	
													BEGIN 
														SET @Param_Radius = NULL
														SET @Param_Top = NULL 
														SET @CalculationWarning = @CalculationWarning + 1
														IF @CalculationComment IS NULL SET @CalculationComment = 'Top short failed: Vertical radius too large' 
														ELSE IF CHARINDEX('Top short failed: Vertical radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + '| Top short failed: Vertical radius too large'
													END
											END
											--Import left rail results into the #TrackGeometry table
											UPDATE #TrackGeometry SET [LR_Top_Short] = CAST(@Param_Top as Decimal (14,4)), [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

											--Right Rail-------------------------------------------------------------------------------------------------------
											--Reset all right rail variables to maintain NULL storage of out of bound data
											SELECT @Data_H_From = NULL, @Data_H_At = NULL, @Data_H_To = NULL
											SELECT @Side_A = NULL, @Side_B = NULL, @Side_C = NULL
											SELECT @Param_Top = NULL, @Param_Radius = NULL
											SELECT @CalculationComment = NULL

											--Get right rail height data for current chainage index
											SELECT @Data_H_From = RR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex - @ShortTopChord,2)
											SELECT @Data_H_At = RR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
											SELECT @Data_H_To = RR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex + @ShortTopChord,2)
											SELECT @CalculationComment = Calculation_Comment FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

											IF @Data_H_At IS NOT NULL 
											BEGIN
												--Determine side parameters for radius calculation
												SET @Side_A = SQRT(SQUARE(@Data_H_At - @Data_H_From) + SQUARE(@ShortTopChord))
												SET @Side_B = SQRT(SQUARE(@Data_H_To - @Data_H_At) + SQUARE(@ShortTopChord))
												SET @Side_C = SQRT(SQUARE(@Data_H_From - @Data_H_To) + SQUARE(2 * @ShortTopChord))

												--Determine the long chord and short chord bearings (vertical angle for top)
												SELECT	@Bearing_LongChord = Bearing  FROM dbo.BearingandDistance(@ChainageIndex - (2 * @ShortTopChord), @Data_H_From, @ChainageIndex + (2 * @ShortTopChord), @Data_H_To)
												SELECT	@Bearing_MidChord = Bearing  FROM dbo.BearingandDistance(@ChainageIndex - (2 * @ShortTopChord), @Data_H_From, @ChainageIndex, @Data_H_At)
												SET		@Bearing_Diff = @Bearing_LongChord - @Bearing_MidChord

												--Check bearing difference: to avoid math error when rail is flat
												IF ABS(@Bearing_Diff)>0.00000001
													BEGIN
														SET @Param_Radius = (@Side_A * @Side_B * @Side_C) / NULLIF(SQRT((@Side_A + @Side_B + @Side_C) * (@Side_B + @Side_C - @Side_A) * (@Side_A + @Side_C - @Side_B) * (@Side_A + @Side_B - @Side_C)),0)
														SET @Param_Top = SQUARE(@Side_C) / (8 * @Param_Radius) * (@Bearing_Diff / NULLIF(ABS(@Bearing_Diff),0))
													END
												ELSE	
													BEGIN
														SET @Param_Radius = NULL
														SET @Param_Top = NULL
														SET @CalculationWarning = @CalculationWarning + 1
														IF @CalculationComment IS NULL SET @CalculationComment = 'Top short failed: Vertical radius too large' 
														ELSE IF CHARINDEX('Top short failed: Vertical radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + '| Top short failed: Vertical radius too large'
													END
											END
											--Import left rail results into the #TrackGeometry table
											UPDATE #TrackGeometry SET [RR_Top_Short] = CAST(@Param_Top as Decimal (14,4)), [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
										END
									ELSE 
										BEGIN
											SET @CalculationWarning = @CalculationWarning + 1
											SELECT @CalculationComment = Calculation_Comment FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
											IF @CalculationComment IS NULL SET @CalculationComment = 'Top short failed: Data outside of calculation chord' 
											ELSE SET @CalculationComment = @CalculationComment + ', Top short failed: Data outside of calculation chord'
											UPDATE #TrackGeometry SET [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
										END
			
									--===============================================================================================================================================
									-- 3.3.3.2 Compute long top (vertical versine) values
									--===============================================================================================================================================
									IF @ChainageIndex >= @CalcStartChainage + @LongTopChord AND @ChainageIndex <= @CalcEndChainage - @LongTopChord
										BEGIN

											--Left Rail--------------------------------------------------------------------------------------------------------
											--Reset all left rail variables to maintain NULL storage of out of bound data
											SELECT @Data_H_From = NULL, @Data_H_At = NULL, @Data_H_To = NULL
											SELECT @Side_A = NULL, @Side_B = NULL, @Side_C = NULL
											SELECT @Param_Top = NULL, @Param_Radius = NULL
											SELECT @CalculationComment = NULL

											--Get left rail height data for current chainage index
											SELECT @Data_H_From = LR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex - @LongTopChord,2)
											SELECT @Data_H_At = LR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
											SELECT @Data_H_To = LR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex + @LongTopChord,2)
											SELECT @CalculationComment = Calculation_Comment FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

											IF @Data_H_At IS NOT NULL 
											BEGIN

												--Determine side parameters for radius calculation
												SET @Side_A = SQRT(SQUARE(@Data_H_At - @Data_H_From) + SQUARE(@LongTopChord))
												SET @Side_B = SQRT(SQUARE(@Data_H_To - @Data_H_At) + SQUARE(@LongTopChord))
												SET @Side_C = SQRT(SQUARE(@Data_H_From - @Data_H_To) + SQUARE(2 * @LongTopChord))

												--Determine the long chord and short chord bearings (vertical angle for top)
												SELECT	@Bearing_LongChord = Bearing  FROM dbo.BearingandDistance(@ChainageIndex - (2 * @LongTopChord), @Data_H_From, @ChainageIndex + (2 * @LongTopChord), @Data_H_To)
												SELECT	@Bearing_MidChord = Bearing  FROM dbo.BearingandDistance(@ChainageIndex - (2 * @LongTopChord), @Data_H_From, @ChainageIndex, @Data_H_At)
												SET		@Bearing_Diff = @Bearing_LongChord - @Bearing_MidChord

												--Check bearing difference: to avoid math error when rail is flat
												IF ABS(@Bearing_Diff)>0.00000001
													BEGIN
														SET @Param_Radius = (@Side_A * @Side_B * @Side_C) / NULLIF(SQRT((@Side_A + @Side_B + @Side_C) * (@Side_B + @Side_C - @Side_A) * (@Side_A + @Side_C - @Side_B) * (@Side_A + @Side_B - @Side_C)),0)
														SET @Param_Top = SQUARE(@Side_C) / (8 * @Param_Radius) * (@Bearing_Diff / NULLIF(ABS(@Bearing_Diff),0))
													END
												ELSE	
													BEGIN 
														SET @Param_Radius = NULL
														SET @Param_Top = NULL
														SET @CalculationWarning = @CalculationWarning + 1
														IF @CalculationComment IS NULL SET @CalculationComment = 'Top long failed: Vertical radius too large' 
														ELSE IF CHARINDEX('Top long failed: Vertical radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + '| Top long failed: Vertical radius too large'
													END
											END
											--Import left rail results into the #TrackGeometry table
											UPDATE #TrackGeometry SET [LR_Top_Long] = CAST(@Param_Top as Decimal (14,4)), [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

											--Right Rail-------------------------------------------------------------------------------------------------------
											--Reset all right rail variables to maintain NULL storage of out of bound data
											SELECT @Data_H_From = NULL, @Data_H_At = NULL, @Data_H_To = NULL
											SELECT @Side_A = NULL, @Side_B = NULL, @Side_C = NULL
											SELECT @Param_Top = NULL, @Param_Radius = NULL
											SELECT @CalculationComment = NULL

											--Get right rail height data for current chainage index
											SELECT @Data_H_From = RR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex - @LongTopChord,2)
											SELECT @Data_H_At = RR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
											SELECT @Data_H_To = RR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex + @LongTopChord,2)
											SELECT @CalculationComment = Calculation_Comment FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

											IF @Data_H_At IS NOT NULL 
											BEGIN

												--Determine side parameters for radius calculation
												SET @Side_A = SQRT(SQUARE(@Data_H_At - @Data_H_From) + SQUARE(@LongTopChord))
												SET @Side_B = SQRT(SQUARE(@Data_H_To - @Data_H_At) + SQUARE(@LongTopChord))
												SET @Side_C = SQRT(SQUARE(@Data_H_From - @Data_H_To) + SQUARE(2 * @LongTopChord))

												--Determine the long chord and short chord bearings (vertical angle for top)
												SELECT	@Bearing_LongChord = Bearing  FROM dbo.BearingandDistance(@ChainageIndex - (2 * @LongTopChord), @Data_H_From, @ChainageIndex + (2 * @LongTopChord), @Data_H_To)
												SELECT	@Bearing_MidChord = Bearing  FROM dbo.BearingandDistance(@ChainageIndex - (2 * @LongTopChord), @Data_H_From, @ChainageIndex, @Data_H_At)
												SET		@Bearing_Diff = @Bearing_LongChord - @Bearing_MidChord

												--Check bearing difference: to avoid math error when rail is flat
												IF ABS(@Bearing_Diff)>0.00000001
													BEGIN
														SET @Param_Radius = (@Side_A * @Side_B * @Side_C) / NULLIF(SQRT((@Side_A + @Side_B + @Side_C) * (@Side_B + @Side_C - @Side_A) * (@Side_A + @Side_C - @Side_B) * (@Side_A + @Side_B - @Side_C)),0)
														SET @Param_Top = SQUARE(@Side_C) / (8 * @Param_Radius) * (@Bearing_Diff / NULLIF(ABS(@Bearing_Diff),0))
													END
												ELSE	
													BEGIN 
														SET @Param_Radius = NULL
														SET @Param_Top = NULL
														SET @CalculationWarning = @CalculationWarning + 1
														IF @CalculationComment IS NULL SET @CalculationComment = 'Top long failed: Vertical radius too large' 
														ELSE IF CHARINDEX('Top long failed: Vertical radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + '| Top long failed: Vertical radius too large'
													END
											END
											--Import left rail results into the #TrackGeometry table
											UPDATE #TrackGeometry SET [RR_Top_Long] = CAST(@Param_Top as Decimal (14,4)), [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
										END
									ELSE 
										BEGIN
											SET @CalculationWarning = @CalculationWarning + 1
											SELECT @CalculationComment = Calculation_Comment FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
											IF @CalculationComment IS NULL SET @CalculationComment = 'Top long failed: Data outside of calculation chord' 
											ELSE SET @CalculationComment = @CalculationComment + ', Top long failed: Data outside of calculation chord'
											UPDATE #TrackGeometry SET [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
										END

									--===============================================================================================================================================
									-- 3.3.3.3 Compute short line (horizontal versine) values
									--===============================================================================================================================================
									IF @ChainageIndex >= @CalcStartChainage + @ShortLineChord AND @ChainageIndex <= @CalcEndChainage - @ShortLineChord
										BEGIN

											--Left Rail--------------------------------------------------------------------------------------------------------
											--Reset all left rail variables to maintain NULL storage of out of bound data
											SELECT @Data_E_From = NULL, @Data_N_From = NULL, @Data_H_From = NULL
											SELECT @Data_E_At = NULL, @Data_N_At = NULL, @Data_H_At = NULL
											SELECT @Data_E_To = NULL, @Data_N_To = NULL, @Data_H_To = NULL
											SELECT @Side_A = NULL, @Side_B = NULL, @Side_C = NULL
											SELECT @Param_Line = NULL, @CalculationComment = NULL

											--Get left rail coordinate data for current chainage index
											SELECT @Data_E_From = LR_Easting, @Data_N_From = LR_Northing, @Data_H_From = LR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex - @ShortLineChord,2)
											SELECT @Data_E_At = LR_Easting, @Data_N_At = LR_Northing, @Data_H_At = LR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
											SELECT @Data_E_To = LR_Easting, @Data_N_To = LR_Northing, @Data_H_To = LR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex + @ShortLineChord,2)
											SELECT @CalculationComment = Calculation_Comment FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

											IF @Data_E_At IS NOT NULL AND @Data_N_At IS NOT NULL AND @Data_H_At IS NOT NULL
											BEGIN

												--Determine side parameters for radius calculation
												SET @Side_A = SQRT(SQUARE(@Data_E_At - @Data_E_From) + SQUARE(@Data_N_At - @Data_N_From))
												SET @Side_B = SQRT(SQUARE(@Data_E_To - @Data_E_At) + SQUARE(@Data_N_To - @Data_N_At))
												SET @Side_C = SQRT(SQUARE(@Data_E_From - @Data_E_To) + SQUARE(@Data_N_From - @Data_N_To))

												--Determine the long chord and short chord bearings
												SELECT	@Bearing_LongChord = Bearing  FROM dbo.BearingandDistance(@Data_E_From, @Data_N_From, @Data_E_To, @Data_N_To)
												SELECT	@Bearing_MidChord = Bearing  FROM dbo.BearingandDistance(@Data_E_From, @Data_N_From, @Data_E_At, @Data_N_At)
												SET		@Bearing_Diff = @Bearing_LongChord - @Bearing_MidChord

												--Check bearing difference: to avoid math error when rail is flat
												IF ABS(@Bearing_Diff)>0.00000001
													BEGIN
														SET @Param_Radius = (@Side_A * @Side_B * @Side_C) / NULLIF(SQRT((@Side_A + @Side_B + @Side_C) * (@Side_B + @Side_C - @Side_A) * (@Side_A + @Side_C - @Side_B) * (@Side_A + @Side_B - @Side_C)),0)
														SET @Param_Line = SQUARE(@Side_C) / (8 * @Param_Radius) * (@Bearing_Diff / NULLIF(ABS(@Bearing_Diff),0))
													END
												ELSE	
													BEGIN 
														SET @Param_Radius = NULL
														SET @Param_Line = NULL
														SET @CalculationWarning = @CalculationWarning + 1
														IF @CalculationComment IS NULL SET @CalculationComment = 'Line short failed: Horizontal radius too large' 
														ELSE IF CHARINDEX('Line short failed: Horizontal radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + '| Line short failed: Horizontal radius too large'
													END
											END
											--Import left rail results into the #TrackGeometry table
											UPDATE #TrackGeometry SET [LR_Line_Short] = CAST(@Param_Line as Decimal (14,4)), [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

											--Right Rail--------------------------------------------------------------------------------------------------------
											--Reset all right rail variables to maintain NULL storage of out of bound data
											SELECT @Data_E_From = NULL, @Data_N_From = NULL, @Data_H_From = NULL
											SELECT @Data_E_At = NULL, @Data_N_At = NULL, @Data_H_At = NULL
											SELECT @Data_E_To = NULL, @Data_N_To = NULL, @Data_H_To = NULL
											SELECT @Side_A = NULL, @Side_B = NULL, @Side_C = NULL
											SELECT @Param_Line = NULL
											SELECT @CalculationComment = NULL

											--Get right rail coordinate data for current chainage index
											SELECT @Data_E_From = RR_Easting, @Data_N_From = RR_Northing, @Data_H_From = RR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex - @ShortLineChord,2)
											SELECT @Data_E_At = RR_Easting, @Data_N_At = RR_Northing, @Data_H_At = RR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
											SELECT @Data_E_To = RR_Easting, @Data_N_To = RR_Northing, @Data_H_To = RR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex + @ShortLineChord,2)
											SELECT @CalculationComment = Calculation_Comment FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

											IF @Data_E_At IS NOT NULL AND @Data_N_At IS NOT NULL AND @Data_H_At IS NOT NULL
											BEGIN

												--Determine side parameters for radius calculation
												SET @Side_A = SQRT(SQUARE(@Data_E_At - @Data_E_From) + SQUARE(@Data_N_At - @Data_N_From))
												SET @Side_B = SQRT(SQUARE(@Data_E_To - @Data_E_At) + SQUARE(@Data_N_To - @Data_N_At))
												SET @Side_C = SQRT(SQUARE(@Data_E_From - @Data_E_To) + SQUARE(@Data_N_From - @Data_N_To))

												--Determine the long chord and short chord bearings
												SELECT	@Bearing_LongChord = Bearing  FROM dbo.BearingandDistance(@Data_E_From, @Data_N_From, @Data_E_To, @Data_N_To)
												SELECT	@Bearing_MidChord = Bearing  FROM dbo.BearingandDistance(@Data_E_From, @Data_N_From, @Data_E_At, @Data_N_At)
												SET		@Bearing_Diff = @Bearing_LongChord - @Bearing_MidChord

												--Check bearing difference: to avoid math error when rail is flat
												IF ABS(@Bearing_Diff)>0.00000001
													BEGIN
														SET @Param_Radius = (@Side_A * @Side_B * @Side_C) / NULLIF(SQRT((@Side_A + @Side_B + @Side_C) * (@Side_B + @Side_C - @Side_A) * (@Side_A + @Side_C - @Side_B) * (@Side_A + @Side_B - @Side_C)),0)
														SET @Param_Line = SQUARE(@Side_C) / (8 * @Param_Radius) * (@Bearing_Diff / NULLIF(ABS(@Bearing_Diff),0))
													END
												ELSE	
													BEGIN 
														SET @Param_Radius = NULL
														SET @Param_Line = NULL
														SET @CalculationWarning = @CalculationWarning + 1
														IF @CalculationComment IS NULL SET @CalculationComment = 'Line short failed: Horizontal radius too large' 
														ELSE IF CHARINDEX('Line short failed: Horizontal radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + '| Line short failed: Horizontal radius too large'
													END
											END
											--Import left rail results into the #TrackGeometry table
											UPDATE #TrackGeometry SET [RR_Line_Short] = CAST(@Param_Line as Decimal (14,4)), [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
										END
									ELSE
										BEGIN
											SET @CalculationWarning = @CalculationWarning + 1
											SELECT @CalculationComment = Calculation_Comment FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
											IF @CalculationComment IS NULL SET @CalculationComment = 'Line short failed: Data outside of calculation chord' 
											ELSE SET @CalculationComment = @CalculationComment + ', Line short failed: Data outside of calculation chord'
											UPDATE #TrackGeometry SET [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
										END

									--===============================================================================================================================================
									-- 3.3.3.4 Compute long line (horizontal versine) values
									--===============================================================================================================================================
									IF @ChainageIndex >= @CalcStartChainage + @LongLineChord AND @ChainageIndex <= @CalcEndChainage - @LongLineChord
										BEGIN

											--Left Rail--------------------------------------------------------------------------------------------------------
											--Reset all left rail variables to maintain NULL storage of out of bound data
											SELECT @Data_E_From = NULL, @Data_N_From = NULL, @Data_H_From = NULL
											SELECT @Data_E_At = NULL, @Data_N_At = NULL, @Data_H_At = NULL
											SELECT @Data_E_To = NULL, @Data_N_To = NULL, @Data_H_To = NULL
											SELECT @Side_A = NULL, @Side_B = NULL, @Side_C = NULL
											SELECT @Param_Line = NULL
											SELECT @CalculationComment = NULL

											--Get left rail coordinate data for current chainage index
											SELECT @Data_E_From = LR_Easting, @Data_N_From = LR_Northing, @Data_H_From = LR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex - @LongLineChord,2)
											SELECT @Data_E_At = LR_Easting, @Data_N_At = LR_Northing, @Data_H_At = LR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
											SELECT @Data_E_To = LR_Easting, @Data_N_To = LR_Northing, @Data_H_To = LR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex + @LongLineChord,2)
											SELECT @CalculationComment = Calculation_Comment FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

											IF @Data_E_At IS NOT NULL AND @Data_N_At IS NOT NULL AND @Data_H_At IS NOT NULL
											BEGIN

												--Determine side parameters for radius calculation
												SET @Side_A = SQRT(SQUARE(@Data_E_At - @Data_E_From) + SQUARE(@Data_N_At - @Data_N_From))
												SET @Side_B = SQRT(SQUARE(@Data_E_To - @Data_E_At) + SQUARE(@Data_N_To - @Data_N_At))
												SET @Side_C = SQRT(SQUARE(@Data_E_From - @Data_E_To) + SQUARE(@Data_N_From - @Data_N_To))

												--Determine the long chord and short chord bearings
												SELECT	@Bearing_LongChord = Bearing  FROM dbo.BearingandDistance(@Data_E_From, @Data_N_From, @Data_E_To, @Data_N_To)
												SELECT	@Bearing_MidChord = Bearing  FROM dbo.BearingandDistance(@Data_E_From, @Data_N_From, @Data_E_At, @Data_N_At)
												SET		@Bearing_Diff = @Bearing_LongChord - @Bearing_MidChord

												--Check bearing difference: to avoid math error when rail is flat
												IF ABS(@Bearing_Diff)>0.00000001
													BEGIN
														SET @Param_Radius = (@Side_A * @Side_B * @Side_C) / NULLIF(SQRT((@Side_A + @Side_B + @Side_C) * (@Side_B + @Side_C - @Side_A) * (@Side_A + @Side_C - @Side_B) * (@Side_A + @Side_B - @Side_C)),0)
														SET @Param_Line = SQUARE(@Side_C) / (8 * @Param_Radius) * (@Bearing_Diff / NULLIF(ABS(@Bearing_Diff),0))
													END
												ELSE	
													BEGIN 
														SET @Param_Radius = NULL
														SET @Param_Line = NULL
														SET @CalculationWarning = @CalculationWarning + 1
														IF @CalculationComment IS NULL SET @CalculationComment = 'Line long failed: Horizontal radius too large' 
														ELSE IF CHARINDEX('Line long failed: Horizontal radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + '| Line long failed: Horizontal radius too large'
													END
											END
											--Import left rail results into the #TrackGeometry table
											UPDATE #TrackGeometry SET [LR_Line_Long] = CAST(@Param_Line as Decimal (14,4)), [LR_Radius] = @Param_Radius, [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

											--Right Rail--------------------------------------------------------------------------------------------------------
											--Reset all right rail variables to maintain NULL storage of out of bound data
											SELECT @Data_E_From = NULL, @Data_N_From = NULL, @Data_H_From = NULL
											SELECT @Data_E_At = NULL, @Data_N_At = NULL, @Data_H_At = NULL
											SELECT @Data_E_To = NULL, @Data_N_To = NULL, @Data_H_To = NULL
											SELECT @Side_A = NULL, @Side_B = NULL, @Side_C = NULL
											SELECT @Param_Line = NULL
											SELECT @CalculationComment = NULL

											--Get right rail coordinate data for current chainage index
											SELECT @Data_E_From = RR_Easting, @Data_N_From = RR_Northing, @Data_H_From = RR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex - @LongLineChord,2)
											SELECT @Data_E_At = RR_Easting, @Data_N_At = RR_Northing, @Data_H_At = RR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
											SELECT @Data_E_To = RR_Easting, @Data_N_To = RR_Northing, @Data_H_To = RR_Height FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex + @LongLineChord,2)
											SELECT @CalculationComment = Calculation_Comment FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

											IF @Data_E_At IS NOT NULL AND @Data_N_At IS NOT NULL AND @Data_H_At IS NOT NULL
											BEGIN

												--Determine side parameters for radius calculation
												SET @Side_A = SQRT(SQUARE(@Data_E_At - @Data_E_From) + SQUARE(@Data_N_At - @Data_N_From))
												SET @Side_B = SQRT(SQUARE(@Data_E_To - @Data_E_At) + SQUARE(@Data_N_To - @Data_N_At))
												SET @Side_C = SQRT(SQUARE(@Data_E_From - @Data_E_To) + SQUARE(@Data_N_From - @Data_N_To))

												--Determine the long chord and short chord bearings
												SELECT	@Bearing_LongChord = Bearing  FROM dbo.BearingandDistance(@Data_E_From, @Data_N_From, @Data_E_To, @Data_N_To)
												SELECT	@Bearing_MidChord = Bearing  FROM dbo.BearingandDistance(@Data_E_From, @Data_N_From, @Data_E_At, @Data_N_At)
												SET		@Bearing_Diff = @Bearing_LongChord - @Bearing_MidChord

												--Check bearing difference: to avoid math error when rail is flat
												IF ABS(@Bearing_Diff)>0.00000001
													BEGIN
														SET @Param_Radius = (@Side_A * @Side_B * @Side_C) / NULLIF(SQRT((@Side_A + @Side_B + @Side_C) * (@Side_B + @Side_C - @Side_A) * (@Side_A + @Side_C - @Side_B) * (@Side_A + @Side_B - @Side_C)),0)
														SET @Param_Line = SQUARE(@Side_C) / (8 * @Param_Radius) * (@Bearing_Diff / NULLIF(ABS(@Bearing_Diff),0))
													END
												ELSE	
													BEGIN 
														SET @Param_Radius = NULL
														SET @Param_Line = NULL
														SET @CalculationWarning = @CalculationWarning + 1
														IF @CalculationComment IS NULL SET @CalculationComment = 'Line long failed: Horizontal radius too large' 
														ELSE IF CHARINDEX('Line long failed: Horizontal radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + '| Line long failed: Horizontal radius too large'
													END
											END
											--Import left rail results into the #TrackGeometry table
											UPDATE #TrackGeometry SET [RR_Line_Long] = CAST(@Param_Line as Decimal (14,4)), [RR_Radius] = @Param_Radius, [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
										END
									ELSE
										BEGIN
											SET @CalculationWarning = @CalculationWarning + 1
											SELECT @CalculationComment = Calculation_Comment FROM #TrackGeometry WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
											IF @CalculationComment IS NULL SET @CalculationComment = 'Line long failed: Data outside of calculation chord' 
											ELSE SET @CalculationComment = @CalculationComment + ', Line long failed: Data outside of calculation chord'
											UPDATE #TrackGeometry SET [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
										END

								--Increment the chainage index and repeat the computations
								SET @ChainageIndex = @ChainageIndex + @ChainageStep
							END

							--Write all of the completed left and right track results to the centerline of the rail
							UPDATE #TrackGeometry SET [CL_Radius] = ([LR_Radius] + [RR_Radius])/2, [CL_Top_Short] = ([LR_Top_Short] + [RR_Top_Short])/2, [CL_Top_Long] = ([LR_Top_Long] + [RR_Top_Long])/2, [CL_Line_Short] = ([LR_Line_Short] + [RR_Line_Short])/2, [CL_Line_Long] = ([LR_Line_Long] + [RR_Line_Long])/2

							--Counter to check if any calculations were performed - this (along with track interpolation and geometry calculations) will be skipped when the 
							-- @PrismCount from GeoMoS extraction returns 0 prisms. 
							SET @Calculation_Check = 1
						END
					END

					--===============================================================================================================================================
					-- 3.4 Check to see if any calculations were performed for the current rail line
					--===============================================================================================================================================
					IF @Calculation_Check = 1
						BEGIN

							--===============================================================================================================================================
							-- 3.4.1 Create and store results to temporary and permenant tables
							--===============================================================================================================================================
							PRINT '   ' + convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Storing results into TrackGeometry database.'
						
							--Store the current round of prism data into the PrismHistory table
							BEGIN TRY
								SET @Database_Script =	'USE [Automated Track Geometry]
														INSERT INTO PrismHistory SELECT [Calculation_ID], [Point_Name], [Point_Epoch], [Point_Group], [Point_ExpTime_DD],  
														[Point_Easting], [Point_Northing], [Point_Height], [Point_EOffset], [Point_NOffset], [Point_HOffset], [Track_Chainage], [Track_Section],
														[Track_RailSide], [Track_Code], [Track_Easting], [Track_Northing], [Track_Height], [Epoch_Index], [Point_Remark] FROM #PrismHistory'
								EXEC (@Database_Script)
								PRINT '   ' + CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Writing to [PrismHistory] table completed.'
							END TRY
							BEGIN CATCH
								PRINT '   ' + CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Writing to [PrismHistory] table failed: ' + ERROR_MESSAGE();
							END CATCH;
	
							--Store the current round of geometry data into the GeometryHistory table
							BEGIN TRY
								SET @Database_Script =	'USE [Automated Track Geometry]
														INSERT INTO GeometryHistory SELECT	[Calculation_ID], [Track_Code], [Track_Section], [Track_Code] + ''-'' + FORMAT(Track_CL_Chainage,'''+ @ChainageNameFormat +''') as [Geometry_Instrument],
														[DataWindow_End] as [Calculation_Epoch], [Track_CL_Chainage] AS [Calculation_Chainage], [DataWindow_Start], [DataWindow_End], [Rail_Cant], [Rail_Gauge],
														[Twist_Short], [Twist_Long], [LR_ID], [LR_Easting], [LR_Northing], [LR_Height], [LR_Radius], [LR_Top_Short], [LR_Top_Long], [LR_Line_Short], [LR_Line_Long],
														[RR_ID], [RR_Easting], [RR_Northing], [RR_Height], [RR_Radius], [RR_Top_Short], [RR_Top_Long], [RR_Line_Short], [RR_Line_Long], [CL_ID], [CL_Easting],
														[CL_Northing], [CL_Height], [CL_Radius], [CL_Top_Short], [CL_Top_Long], [CL_Line_Short], [CL_Line_Long], [Calculation_Comment], [Prism_Comment] AS [Prism_Inputs],
														[Diff_Chainage_Left] As [Left_Prism_Spacing], [Diff_Chainage_Rght] As [Right_Prism_Spacing] FROM #TrackGeometry'
								EXEC (@Database_Script)
								PRINT '   ' + CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Writing to [GeometryHistory] table completed.'
							END TRY
							BEGIN CATCH
								PRINT '   ' + CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Writing to [GeometryHistory] table failed: ' + ERROR_MESSAGE();
							END CATCH;
						
							--===============================================================================================================================================
							-- 3.4.2 Drop the #PrismHistory and #TrackGeometry tabled in preperation for the next round of calculations
							--===============================================================================================================================================
							DROP TABLE #PrismHistory
							DROP TABLE #TrackGeometry

							-- Depending on selected operation mode, reset all calculation tables
							IF @Debug = 2
								BEGIN
									--Enable the code below to clear the Geometry history and the PrismHistory tables
									SET @Database_Script =	'USE [Automated Track Geometry] DELETE FROM GeometryHistory DELETE FROM PrismHistory'
									EXEC (@Database_Script)
								END
						END

		-- Increase @Trackcounter index for next round of track calculations
		SELECT @TrackCounter = MIN([Row_ID]) FROM ##CalculationListing WHERE Row_ID > @TrackCounter
		END

    -- Increment the current time by the time step
    SET @CurrentDateTime = DATEADD(HOUR, @Historic_TimeStep, @CurrentDateTime);
END;

-- Final message
PRINT Char(13) + '   ' + CONVERT(VARCHAR, GETDATE(), 103) + ' ' + CONVERT(VARCHAR, GETDATE(), 14) + ' | Track Geometry script completed.';

--===============================================================================================================================================
-- Exit Script Routine
--===============================================================================================================================================
ExitScript:

IF @Calculation_Check = 0 OR @Calculation_Check = 1
BEGIN
	PRINT Char(13) + 'TRACK GEOMETRY CALCULATIONS COMPLETE:' + Char(13)
	PRINT ' - Total number of prisms extracted for calculations: '+ CAST(@PrismTotalCount as varchar) + '.'
	PRINT ' - Total number of calculation warnings received: '+ CAST(@CalculationWarning as varchar) + '.'
	PRINT ' - Calculations completed in: '+ CAST(CAST((DATEDIFF(ms, @ScriptStartDateTime, GETDATE())/1000.0) as decimal(10,2)) as varchar) + ' seconds.'
END

IF @Calculation_Check = 1
BEGIN
	SET @Database_Script =	'USE [Automated Track Geometry] SELECT * FROM PrismHistory ORDER BY Calculation_ID, Point_Name, Point_Epoch'
	EXEC (@Database_Script)

	SET @Database_Script =	'USE [Automated Track Geometry] SELECT * FROM GeometryHistory ORDER BY Calculation_ID, Geometry_Instrument'
	EXEC (@Database_Script)
END