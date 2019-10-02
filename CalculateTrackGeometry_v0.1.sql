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
					[dbo.SelectToHTML]
Used By:            N/A 
Usage:              This is the automated script with will be scheduled to run at predefined intervals
					throughout the monitoring programme. The script relys on the [dbo.TrackListing] 
					table within the [TrackGeometry] database to determine when and if calculation
					should occur along with the required identifiers for what data within GeoMoS is 
					associated to a given set of rail line prisms.
****************************************************************************************************
SUMMARY OF CHANGES
Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------- ------------------------------------------------------------
2019-09-16			Lewis Walsh			Added changes to match the new naming scheme in the 
										'InitaliseTrackeometry' script.
2019-09-17			Lewis Walsh			Rebuild of data extraction statement to retrieve latest readings
										withing the provided extraction window in one step. 
2019-09-17			Lewis Walsh			Built in a prism spacing check to ensure that missing
										prisms along a rail are treated correctly. For example
										if there is a gap in prisms more than 10m in length
										do not interpolate rail coordinates within this gap.
2019-09-20			Lewis Walsh			Reconfigured code to allow for non-integer chainage steps
										and non-integer reference chord lengths.
2019-09-22			Lewis Walsh			Added calculation comments to allow historic reference to 
										calculation issues within the track geometry.
2019-09-23			Lewis Walsh			Added logic check on chainge step and reference lengths to 
										see if user defined input values are compatable. Uses
										Modulo calculation to see if reference chord and twist lengths
										have a remainder of 0.
2019-09-23			Lewis Walsh			Included a user definable track side string indicator so that
										unique naming schemes can be adopted in future applications.
2019-09-23			Lewis Walsh			Added email alert response for when there is overdue data in 
										the #prismdata table
2019-09-24			Lewis Walsh			Added processing printouts for a log file when track geometry 
										routine gets executed.
2019-09-24			Lewis Walsh			Created data storage routine for GeometryHistory and PrismHistory
										tables within the TrackGeometry database.
2019-09-25			Lewis Walsh			Reconfigured the GeometryReport SELECT statement to accept
										non-integer chainages (coverting FLOOR to ROUND).
***************************************************************************************************/

IF OBJECT_ID ('tempdb..##CalculationListing') IS NOT NULL Begin DROP TABLE ##CalculationListing; End
IF OBJECT_ID ('tempdb..#PrismData') IS NOT NULL Begin DROP TABLE #PrismData; End
IF OBJECT_ID ('tempdb..##OverdueData') IS NOT NULL Begin DROP TABLE ##OverdueData; End
IF OBJECT_ID ('tempdb..#TrackGeometry') IS NOT NULL Begin DROP TABLE #TrackGeometry; End
IF OBJECT_ID ('tempdb..#TrackReport') IS NOT NULL Begin DROP TABLE #TrackReport; End

SET DATEFORMAT dmy
SET XACT_ABORT ON
SET NOCOUNT ON
SET ANSI_WARNINGS OFF

--===============================================================================================================================
-- Set and declare variables
--===============================================================================================================================
DECLARE @Debug as int = 0								-- If set to 0 = live automation from exe, 1 = Psuedo live (keep data), 2 = dubug mode (clear and reset tables)

--User Input
DECLARE @CalculationFrequency as int = 0				-- The required frequency (in minutes) of calcualtions. i.e the time spacing between required calculations.
DECLARE @DataExtractionWindow as int = 96				-- Number of hours to look back when extracting data for the calculations
DECLARE @OverdueDataWarning as int = 72					-- Number of hours by which a prism will be flagged as having overdue (old) observations. Observations will still be used in calculations, however a warning will be sent to email recipents.
DECLARE @SendOverdueEmail as bit = 0					-- Identifier to enable or disable the sending of email alerts (1 = enable, 0 = disable)
DECLARE @PrismSpacingLimit as decimal(38,10) = 7.2		-- A value (in meters) used to check the spacing between track prisms any prisms seperated by more than this value will not get geometry calculations.

DECLARE @ChainageStep decimal(38,10) = 1.2				-- The spacing at which you want to calculate track geometry at. i.e. every x meters.
DECLARE @ShortTwistStep decimal(38,10) = 2.4			-- The spacing at which short twist should be calculated, looking in reverse chainage.
DECLARE @LongTwistStep decimal(38,10) = 14.4			-- The spacing at which long twist should be calculated, looking in reverse chainage.

DECLARE @ShortLineChord decimal(38,10) = 4.8			-- The chord length for the short line calculation, looking foward and back half of this length from reference chainage.
DECLARE @LongLineChord decimal(38,10) = 9.6				-- The chord length for the long line calculation, looking foward and back half of this length from reference chainage.
DECLARE @ShortTopChord decimal(38,10) = 4.8				-- The chord length for the short top calculation, looking foward and back half of this length from reference chainage.
DECLARE @LongTopChord decimal(38,10) = 9.6				-- The chord length for the long top calculation, looking foward and back half of this length from reference chainage.

DECLARE @LeftRailIndicator varchar(30) = 'RPL'			-- Search string to identify all left rail prisms. Script will try to find a string match in the instrument name and group point as a left rail prism.
DECLARE @RightRailIndicator varchar(30) = 'RPR'			-- Search string to identify all right rail prisms. Script will try to find a string match in the instrument name and group point as a right rail prism.

DECLARE @EmailProfile varchar(256) = 'Track Geometry Alerts Profile'	-- The name of the email profile for sending alerts.
DECLARE @EmailRecipients varchar(max) = 'lwalsh@landsurveys.net.au'		-- Recipients list for the email alerts.

--For setting variable values from sqlcmd prompt
IF (@Debug = 0) 
	BEGIN

		IF '$(CalculationFrequency)' IS NULL OR '$(CalculationFrequency)'='' OR '$(CalculationFrequency)'<0 SET @CalculationFrequency=0 ELSE SET @CalculationFrequency = CAST('$(CalculationFrequency)' as int)
		IF '$(DataExtractionWindow)' IS NULL OR '$(DataExtractionWindow)'='' OR '$(DataExtractionWindow)'<0 SET @DataExtractionWindow=96 ELSE SET @DataExtractionWindow = CAST('$(DataExtractionWindow)' as int)
		IF '$(OverdueDataWarning)' IS NULL OR '$(OverdueDataWarning)'='' OR '$(OverdueDataWarning)'<0 SET @OverdueDataWarning=72 ELSE SET @OverdueDataWarning = CAST('$(OverdueDataWarning)' as int)
		IF '$(SendOverdueEmail)' IS NULL OR '$(SendOverdueEmail)'='' OR ('$(SendOverdueEmail)'<0 OR '$(SendOverdueEmail)'>1) SET @SendOverdueEmail=0 ELSE SET @SendOverdueEmail = CAST('$(SendOverdueEmail)' as bit)
		IF '$(PrismSpacingLimit)' IS NULL OR '$(PrismSpacingLimit)'='' OR '$(PrismSpacingLimit)'<CAST(0.0 as decimal (30,10)) SET @PrismSpacingLimit=4.0 ELSE SET @PrismSpacingLimit = CAST('$(PrismSpacingLimit)' as decimal(30,10))
		IF '$(ChainageStep)' IS NULL OR '$(ChainageStep)'='' OR '$(ChainageStep)'<CAST(0.0 as decimal (30,10)) SET @ChainageStep=1.0 ELSE SET @ChainageStep = CAST('$(ChainageStep)' as decimal(30,10))
		IF '$(ShortTwistStep)' IS NULL OR '$(ShortTwistStep)'='' OR '$(ShortTwistStep)'<CAST(0.0 as decimal (30,10)) SET @ShortTwistStep=2.0 ELSE SET @ShortTwistStep = CAST('$(ShortTwistStep)' as decimal(30,10)) 
		IF '$(LongTwistStep)' IS NULL OR '$(LongTwistStep)'='' OR '$(LongTwistStep)'<CAST(0.0 as decimal (30,10)) SET @LongTwistStep=14.0 ELSE SET @LongTwistStep = CAST('$(LongTwistStep)' as decimal(30,10))
		IF '$(ShortLineChord)' IS NULL OR '$(ShortLineChord)'='' OR '$(ShortLineChord)'<CAST(0.0 as decimal (30,10)) SET @ShortLineChord=10.0 ELSE SET @ShortTopChord = CAST('$(ShortTopChord)' as decimal(30,10))
		IF '$(LongTopChord)' IS NULL OR '$(LongTopChord)'='' OR '$(LongTopChord)'<CAST(0.0 as decimal (30,10)) SET @LongLineChord=20.0 ELSE SET @LongLineChord = CAST('$(LongLineChord)' as decimal(30,10))
		IF '$(ShortTopChord)' IS NULL OR '$(ShortTopChord)'='' OR '$(ShortTopChord)'<CAST(0.0 as decimal (30,10)) SET @ShortTopChord=10.0 ELSE SET @ShortTopChord = CAST('$(ShortTopChord)' as decimal(30,10))
		IF '$(LongTopChord)' IS NULL OR '$(LongTopChord)'='' OR '$(LongTopChord)'<CAST(0.0 as decimal (30,10)) SET @LongTopChord=20.0 ELSE SET @LongTopChord = CAST('$(LongTopChord)' as decimal(30,10))
		IF '$(LeftRailIndicator)'='' SET @LeftRailIndicator='L' ELSE SET @LeftRailIndicator= '$(LeftRailIndicator)'
		IF '$(RightRailIndicator)'='' SET @RightRailIndicator='R' ELSE SET @RightRailIndicator='$(RightRailIndicator)'
		IF '$(EmailProfile)'='' SET @EmailProfile='' ELSE SET @EmailProfile='$(EmailProfile)'
		IF '$(EmailRecipients)'='' SET @EmailRecipients='' ELSE SET @EmailRecipients='$(EmailRecipients)'

	END

--Print settings to log file
PRINT '**********************************************************************************'
--PRINT convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Starting Track Geometry script' + Char(13)
PRINT 'CURRENT SCRIPT SETTINGS:'  + Char(13) 
PRINT ' - Calculation frequency: '+ CAST(@CalculationFrequency as varchar) + ' min | Repeat calcualtions if last calculations were performed more than ' + CAST(@CalculationFrequency as varchar) + ' minutes ago.'
PRINT ' - Data extraction window: ' + CAST(@DataExtractionWindow as varchar) + ' hrs | Gather GeoMoS prism data that has been observed within the last ' + CAST(@DataExtractionWindow as varchar) + ' hours.'
PRINT ' - Send overdue data email: ' + CAST(@SendOverdueEmail as varchar) + ' | 1 = enabled (send email), 0 = disabled (dont send email). Ignore the limit below if emails are disabled.'
PRINT ' - Overdue data limit: ' + CAST(@OverdueDataWarning as varchar) + ' hrs | Report any prisms that have not had readings taken within the last ' + CAST(@OverdueDataWarning as varchar) + ' hours.'
PRINT ' - Prism spacing limit: ' + CAST(CAST(@PrismSpacingLimit as decimal(5,1)) as varchar) + 'm | Do not perform track coordinate interpolation when prism data is seperated by more than ' + CAST(CAST(@PrismSpacingLimit as decimal(5,1)) as varchar) + ' meters.'
PRINT ' - Track interpolation step: ' + CAST(CAST(@ChainageStep as decimal(5,1)) as varchar) + 'm | Calculate interpolated track locations at chainages increasing in ' + CAST(CAST(@ChainageStep as decimal(5,1)) as varchar) + ' meter steps.' + Char(13)

PRINT ' - Short Twist Step: '+ CAST(CAST(@ShortTwistStep as decimal(5,1)) as varchar) + 'm | Chainage spacing for short twist calculations (looking back from the calculation chainage).'
PRINT ' - Long Twist Step: ' + CAST(CAST(@LongTwistStep as decimal(5,1)) as varchar) + 'm | Chainage spacing for long twist calculations (looking back from the calculation chainage).'
PRINT ' - Short Line Chord: ' + CAST(CAST(@ShortLineChord as decimal(5,1)) as varchar) + 'm | Chord length for short line (horizontal versine) calculations (looking back and foward half of the chord length from the calculation chainage).'
PRINT ' - Long Line Chord: ' + CAST(CAST(@LongLineChord as decimal(5,1)) as varchar) + 'm |  Chord length for long line (horizontal versine) calculations (looking back and foward half of the chord length from the calculation chainage).'
PRINT ' - Short Top Chord: ' + CAST(CAST(@ShortTopChord as decimal(5,1)) as varchar) + 'm |  Chord length for short top (vertical versine) calculations (looking back and foward half of the chord length from the calculation chainage).'
PRINT ' - Long Top Chord: ' + CAST(CAST(@LongTopChord as decimal(5,1)) as varchar) + 'm | Chord length for long top (vertical versine) calculations (looking back and foward half of the chord length from the calculation chainage).'
PRINT ' - Left Rail Indicator: ' + CAST(@LeftRailIndicator as varchar) + ' | String identifer for left rail points. Must match with left rail names from GeoMoS.'
PRINT ' - Right Rail Indicator: ' + CAST(@RightRailIndicator as varchar) + ' | String identifer for right rail points. Must match with right rail names from GeoMoS.' + Char(13)

--Check inital user input
DECLARE @ErrorLevel int = 0
DECLARE @Calculation_Check int = 0
--Check to see if the provided calculation chord lengths and steps are compatable
IF		@ShortTwistStep%@ChainageStep <> 0 OR 
		@LongTwistStep%@ChainageStep <> 0 OR 
		@ShortLineChord%@ChainageStep <> 0 OR 
		@LongLineChord%@ChainageStep <> 0 OR 
		@ShortTopChord%@ChainageStep <> 0 OR 
		@ShortTopChord%@ChainageStep <> 0 OR 
		@LongTopChord%@ChainageStep <> 0
BEGIN	
	SET		@ErrorLevel = 1
	SET		@Calculation_Check = 3
	GOTO	ExitScript
END

--Set adjustment lengths for chord based calculations
SET @ShortLineChord = @ShortLineChord/2
SET @LongLineChord = @LongLineChord/2
SET @ShortTopChord = @ShortTopChord/2
SET @LongTopChord = @LongTopChord/2

--Script variables
DECLARE @Database_Script varchar(max), @Execute_Script varchar(max)

--Data extraction variables
DECLARE @TrackCounter int, @CalculationID int
DECLARE @CurrentTrack as varchar(100), @TrackID int --@myTrack = @CurrentTrack
DECLARE @ExpectedDatabase as varchar(max)
DECLARE @CurrentDateTime datetime = GETDATE(), @LastRailCalcTime datetime
DECLARE @ExtractStartTime datetime, @ExtractEndTime datetime
DECLARE @PrismCount int, @PrismTotalCount int, @TrackTotal int, @TrackCalculationTime int

--Track alignment variables
DECLARE @MinChainage as decimal(30,5), @MaxChainage as decimal(30,5)
DECLARE @ChainageIndex as decimal(30,5), @Diff_Chainage_Left decimal(30,5), @Diff_Chainage_Rght decimal(30,5)
DECLARE @Prev_PointName varchar(100), @Prev_Chainage decimal(38,10), @Prev_Easting decimal(38,10), @Prev_Northing decimal(38,10), @Prev_Height decimal(38,10)
DECLARE @Next_PointName varchar(100), @Next_Chainage decimal(38,10), @Next_Easting decimal(38,10), @Next_Northing decimal(38,10), @Next_Height decimal(38,10)		
DECLARE @Left_Easting decimal(38,10), @Left_Northing decimal(38,10), @Left_Height decimal(38,10)
DECLARE @Rght_Easting decimal(38,10), @Rght_Northing decimal(38,10), @Rght_Height decimal(38,10)

--Track geometry variables
DECLARE @Track_Cant decimal(38,10), @Track_Guage decimal(38,10), @Twist_Short decimal(38,10), @Twist_Long decimal(38,10)
DECLARE @CalculationComment varchar(max), @CalculationWarning  int, @OverdueCount int, @OverdueTotalCount int
DECLARE @Point_From nvarchar(100), @Point_At nvarchar(100), @Point_To nvarchar(100)
DECLARE @Param_Top float, @Param_Line float, @Param_Radius float
DECLARE @Side_A float, @Side_B float, @Side_C float
DECLARE @Bearing_LongChord decimal(38,10), @Bearing_MidChord decimal(38,10), @Bearing_Diff decimal(38,10)
DECLARE @Data_E_From decimal(38,10), @Data_N_From decimal(38,10), @Data_H_From decimal(38,10)
DECLARE @Data_E_At decimal(38,10), @Data_N_At decimal(38,10), @Data_H_At decimal(38,10)
DECLARE @Data_E_To decimal(38,10), @Data_N_To decimal(38,10), @Data_H_To decimal(38,10)

--===============================================================================================================================
-- Initalise calculation variables
--===============================================================================================================================
--Retrieve track information to initalise calculation parameters
SET @Database_Script=	'USE [TrackGeometry]
						SELECT ROW_NUMBER() OVER(ORDER BY [Track_Name] ASC) As Row_ID, [ID], [Track_Code], [Expected_Database], 
						[Calculation_Time], (SELECT MAX([Calculation_ID]) FROM [GeometryHistory]) as [Calculation_ID] 
						INTO ##CalculationListing 
						FROM [TrackListing] WHERE [Calculation_Status] = 1'
EXEC (@Database_Script)

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--SELECT * FROM ##CalculationListing------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

-- Intalise track and calculation counters
SELECT	@TrackCounter = MIN([Row_ID]), @CalculationID = Max([Calculation_ID]), @TrackTotal = COUNT([ID]) FROM ##CalculationListing
SELECT	@TrackCalculationTime = COUNT([ID]) FROM ##CalculationListing WHERE [Calculation_Time] < DateADD(MINUTE, -@CalculationFrequency, @CurrentDateTime)
SET		@Calculation_Check = 0 -- 0 = no calculations, 1 = atleast one calculation, 3 = Error encountered
SET		@CalculationWarning = 0
SET		@PrismTotalCount = 0
SET		@OverdueTotalCount = 0

--===============================================================================================================================
-- Commence track geometry calculations
--===============================================================================================================================
PRINT 'COMMENCING TRACK GEOMETRY CALCULATIONS:' + Char(13)
PRINT ' ' + CAST(@TrackTotal as varchar) + ' tracks currently enabled for calculation.'
PRINT ' ' + CAST(@TrackCalculationTime as varchar) + ' tracks currently within the specified calculation window.'

WHILE @TrackCounter IS NOT NULL
BEGIN

	--Get track info for current rail line
	SELECT	@CurrentTrack = [Track_Code], 
			@TrackID = [ID], 
			@ExpectedDatabase = [Expected_Database],
			@LastRailCalcTime = [Calculation_Time] 
	FROM	##CalculationListing  
	WHERE	[Row_ID] = @TrackCounter

	SET		@Calculation_Check = 0

	--Start of rail analysis calculation trigger
	IF	@CurrentDateTime > DateADD(MINUTE, @CalculationFrequency, @LastRailCalcTime) AND @ExpectedDatabase = DB_NAME() 
		BEGIN
		
			--Determine the calculation ID for the given dataset
			IF @CalculationID IS NULL 
				SET @CalculationID = 1
			ELSE 
				SET @CalculationID = @CalculationID + 1

			PRINT Char(13) + ' - Calculation set: ' + CAST(@CalculationID as varchar) + '.'
			PRINT '   Track Code: ' + @CurrentTrack + ', Track ID: ' + CAST(@TrackID as varchar) + '.'

			--Determine the start datetime for the data extraction
			SELECT @ExtractStartTime = DATEADD(hh, -@DataExtractionWindow, @CurrentDateTime), @ExtractEndTime = @CurrentDateTime;
		
			--Update the TrackListing table with the new calculation time
			SET @Database_Script=	'USE [TrackGeometry] UPDATE [TrackListing] SET [Calculation_Time] = CONVERT(datetime,''' 
									+ CONVERT(varchar, @CurrentDateTime, 109) + ''', 109) WHERE [ID] = ' + CONVERT(varchar, @TrackID)
			EXEC (@Database_Script)
			
			--===============================================================================================================================================
			-- Gather prism data and offset to track
			--===============================================================================================================================================
			PRINT '   ' + convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Starting prism data extraction.'
			--Create temporary table #PrismData to store all the required prism and track coordinate data
			IF OBJECT_ID ('tempdb..#PrismData') IS NULL 
			CREATE TABLE	#PrismData	([Calculation_ID] int, [Point_Name] nvarchar(100) NULL, [Point_Epoch] dateTime NULL, [Point_Group] nvarchar(100) NULL, 
										[Point_ExpTime_DD] decimal(38,10) NULL, [Point_ExpTime_DHM] varchar (100) NULL, [Point_Easting] decimal(38,10) NULL,
										[Point_Northing] decimal(38,10) NULL, [Point_Height] decimal(38,10) NULL, [Point_EOffset] decimal(38,10) NULL, [Point_NOffset] decimal(38,10) NULL,
										[Point_HOffset] decimal(38,10) NULL,	[Track_Chainage] decimal(38,10) NULL, [Track_RailSide] nvarchar(50) NULL, [Track_Code] nvarchar(100) NULL,
										[Track_Easting] decimal(38,10) NULL,	[Track_Northing] decimal(38,10) NULL, [Track_Height] decimal(38,10) NULL, [Epoch_Index] int NULL)

			-- Store relevant data containing all the latest readings inside the given extraction window into the #PrismData table
			INSERT INTO #PrismData
			SELECT		*  FROM 
						(SELECT @CalculationID as [Calculation_ID], Points.Name as [Point_Name], Results.Epoch as [Point_Epoch], PointGroups.Name as [Point_Group], DateDIFF(SECOND, Results.Epoch, @CurrentDateTime) / 86400.0 as [Point_ExpTime_DD],
						Format(convert(INT, (DateDIFF(Second, Results.Epoch, @CurrentDateTime)/86400)),'D2') + 'd ' + Format(convert(INT, ((DateDIFF(Second, Results.Epoch, @CurrentDateTime)%86400)/3600)),'D2') + 'h '+
						Format(convert(INT, (((DateDIFF(Second, Results.Epoch, @CurrentDateTime)%86400)%3600)/60)),'D2') + 'm' as [Point_ExpTime_DHM], Results.Easting as [Point_Easting], Results.Northing as [Point_Northing], 
						Results.Height as [Point_Height], [dbo].[ParseString](Points.Description, 'EoS:') as [Point_EOffset], [dbo].[ParseString](Points.Description, 'NoS:') as [Point_NOffset], 
						[dbo].[ParseString](Points.Description, 'HoS:') as [Point_HOffset], [dbo].[ParseString](Points.Description, 'CH:') as [Track_Chainage],
						CASE 
							WHEN Points.Name LIKE '%'+ @LeftRailIndicator + '%' THEN 'Left'
							WHEN Points.Name LIKE '%'+ @RightRailIndicator + '%' THEN 'Right'
						END as [Track_RailSide], 
						@CurrentTrack as [Track_Code], NULL as [Track_Easting], NULL as [Track_Northing], NULL as [Track_Height], ROW_NUMBER() over(partition by Points.Name order by Results.Epoch desc) as EpochIndex
			FROM	    Results INNER JOIN
						Points ON Results.Point_ID = Points.ID LEFT OUTER JOIN
						PointGroups INNER JOIN
						PointGroupItems ON PointGroups.ID = PointGroupItems.PointGroup_ID ON Points.ID = PointGroupItems.Point_ID
			WHERE		(Results.Type = 0) AND (Results.Epoch >= @ExtractStartTime) AND (Results.Epoch < @ExtractEndTime) 
						AND (Points.Name LIKE '%%%' + @CurrentTrack + '%%%' ) AND (Points.Name LIKE '%' + @LeftRailIndicator + '%' OR Points.Name LIKE '%' + @RightRailIndicator + '%' ) AND [dbo].[ParseString](Points.Description, 'CH:') IS NOT NULL) as AllData
			WHERE		AllData.EpochIndex=1
		
			-- Shift prism coordinate data onto the track via the defined offset values in the point description field
			UPDATE		#PrismData SET [Track_Easting] = [Point_Easting] + [Point_EOffset]
			UPDATE		#PrismData SET [Track_Northing] = [Point_Northing] + [Point_NOffset]
			UPDATE		#PrismData SET [Track_Height] = [Point_Height] + [Point_HOffset]

			--Get prism extraction data for printing results of extraction to log
			SELECT @PrismCount = COUNT([Point_Name]) FROM #PrismData
			SET @PrismTotalCount = @PrismTotalCount + @PrismCount
			PRINT '   ' + convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | ' + CAST(@PrismCount as varchar) + ' valid observations extracted.'

			--IF there is no prism data for the current track, skip the interpolation and and track geometry calculation steps
			IF @PrismCount = 0
				PRINT '   ' + convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Skipping track geometry routine.'
			ELSE
				BEGIN
					--===============================================================================================================================================
					-- Begin building of track geometry table
					--===============================================================================================================================================
					PRINT '   ' + convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Starting track interpolation calculations at a ' + CAST(CAST(@ChainageStep as decimal(10,1)) as varchar) + ' meter step.'
					IF OBJECT_ID ('tempdb..#TrackGeometry') IS NULL 
					CREATE TABLE #TrackGeometry	([Calculation_ID] int, [Track_CL_Chainage] decimal(38,10), [Track_Code] varchar(100) NULL, [DataWindow_Start] datetime, [DataWindow_End] datetime,
												[Rail_Cant] decimal (20,6), [Rail_Gauge] decimal (20,6), [Twist_Short] decimal(38,10), [Twist_Long] decimal (20,6),
												[LR_ID] varchar(100), [LR_Easting] decimal (20,6), [LR_Northing] decimal (20,6), [LR_Height] decimal (20,6), 
												[LR_Radius] decimal (20,6), [LR_Top_Short] decimal (20,6), [LR_Top_Long] decimal (20,6), [LR_Line_Short] decimal (20,6),
												[LR_Line_Long] decimal (20,6), [RR_ID] varchar(100), [RR_Easting] decimal (20,6), [RR_Northing] decimal (20,6), 
												[RR_Height] decimal (20,6), [RR_Radius] decimal (20,6), [RR_Top_Short] decimal (20,6), [RR_Top_Long] decimal (20,6),
												[RR_Line_Short] decimal (20,6), [RR_Line_Long] decimal (20,6), [CL_ID] varchar(100), [CL_Easting] decimal (20,6),
												[CL_Northing] decimal (20,6), [CL_Height] decimal (20,6), [CL_Radius] decimal (20,6), [CL_Top_Short] decimal (20,6),
												[CL_Top_Long] decimal (20,6), [CL_Line_Short] decimal (20,6), [CL_Line_Long] decimal (20,6), [Diff_Chainage_Left] decimal(20,6), 
												[Diff_Chainage_Rght] decimal(20,6), [Calculation_Comment] varchar(max))

					--===============================================================================================================================================
					-- Determine track alignment at given interpolation step interval - Start of first chainage loop
					--===============================================================================================================================================
					--Set chainage limits
					SELECT @MinChainage = CEILING(MIN([Track_Chainage])), @MaxChainage = FLOOR(MAX([Track_Chainage])) FROM #PrismData
					SET @ChainageIndex = @MinChainage
			
					WHILE @ChainageIndex <= @MaxChainage
						BEGIN
			
							--Reset all variables to maintain NULL storage of out of bound data
							SELECT  @Diff_Chainage_Left = NULL, @Diff_Chainage_Rght = NULL
							SELECT @Prev_PointName = NULL, @Prev_Chainage = NULL, @Prev_Easting = NULL, @Prev_Northing = NULL, @Prev_Height = NULL
							SELECT @Next_PointName = NULL, @Next_Chainage = NULL, @Next_Easting = NULL, @Next_Northing = NULL, @Next_Height = NULL		
							SELECT @Left_Easting = NULL, @Left_Northing = NULL, @Left_Height = NULL
							SELECT @Rght_Easting = NULL, @Rght_Northing = NULL, @Rght_Height = NULL
							SELECT @Track_Cant = NULL, @Track_Guage = NULL, @Twist_Short = NULL, @Twist_Long = NULL
							SELECT @CalculationComment = NULL

							--Get previous left rail data
							SELECT	TOP 1 @Prev_PointName=[Point_Name], @Prev_Chainage=[Track_Chainage], @Prev_Easting=[Track_Easting], @Prev_Northing=[Track_Northing], @Prev_Height=[Track_Height]
							FROM	#PrismData WHERE [Track_Chainage] < @ChainageIndex and [Track_RailSide] = 'Left' ORDER BY [Track_Chainage] DESC
							--Get next left rail data
							SELECT	TOP 1 @Next_PointName=[Point_Name], @Next_Chainage=[Track_Chainage], @Next_Easting=[Track_Easting], @Next_Northing=[Track_Northing], @Next_Height=[Track_Height]
							FROM	#PrismData WHERE [Track_Chainage] >= @ChainageIndex and [Track_RailSide] = 'Left' ORDER BY [Track_Chainage] ASC
							--Set left rail chainage difference
							SET @Diff_Chainage_Left = @Next_Chainage - @Prev_Chainage
				
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
							FROM	#PrismData WHERE [Track_Chainage] < @ChainageIndex and [Track_RailSide] = 'Right' ORDER BY [Track_Chainage] DESC
							--Get next right rail data
							SELECT	TOP 1 @Next_PointName=[Point_Name], @Next_Chainage=[Track_Chainage], @Next_Easting=[Track_Easting], @Next_Northing=[Track_Northing], @Next_Height=[Track_Height]
							FROM	#PrismData WHERE [Track_Chainage] >= @ChainageIndex and [Track_RailSide] = 'Right' ORDER BY [Track_Chainage] ASC
							--Set right rail chainage difference
							SET @Diff_Chainage_Rght = @Next_Chainage - @Prev_Chainage

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
							INSERT INTO #TrackGeometry	([Calculation_ID], [Track_CL_Chainage], [Track_Code], [DataWindow_Start], [DataWindow_End], [Rail_Cant], [Rail_Gauge], [Twist_Short],
														[Twist_Long], [LR_ID], [LR_Easting], [LR_Northing], [LR_Height], [RR_ID], [RR_Easting], [RR_Northing], [RR_Height], [CL_ID],
														[CL_Easting], [CL_Northing], [CL_Height], [Diff_Chainage_Left], [Diff_Chainage_Rght], [Calculation_Comment])
							VALUES	(@CalculationID, ROUND(@ChainageIndex, 2), @CurrentTrack, @ExtractStartTime, @ExtractEndTime, @Track_Cant, @Track_Guage, @Twist_Short, @Twist_Long,
									@CurrentTrack + '-LR-' + RIGHT('0000'+ CAST(CAST(@ChainageIndex as decimal(10,1)) as varchar(15)),6), @Left_Easting, @Left_Northing, @Left_Height,
									@CurrentTrack + '-RR-' + RIGHT('0000'+ CAST(CAST(@ChainageIndex as decimal(10,1)) as varchar(15)),6), @Rght_Easting, @Rght_Northing, @Rght_Height,
									@CurrentTrack + '-CL-' + RIGHT('0000'+ CAST(CAST(@ChainageIndex as decimal(10,1)) as varchar(15)),6), (@Left_Easting + @Rght_Easting)/2, 
									(@Left_Northing + @Rght_Northing)/2, (@Left_Height + @Rght_Height)/2, @Diff_Chainage_Left, @Diff_Chainage_Rght, @CalculationComment)	
				
							--Increment the chainage index and repeat the computations
							SET @ChainageIndex = @ChainageIndex + @ChainageStep
						END

					--===============================================================================================================================================
					-- Begin track geometry calculations - Start of second chainage loop
					--===============================================================================================================================================
					--Reset chainage index
					SET @ChainageIndex = @MinChainage
					PRINT '   ' + convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Starting track geometry calculations.'
					WHILE @ChainageIndex <= @MaxChainage
					BEGIN

						--===============================================================================================================================================
						-- Compute short top (vertical versine) values
						--===============================================================================================================================================
						IF @ChainageIndex >= @MinChainage + @ShortTopChord AND @ChainageIndex <= @MaxChainage - @ShortTopChord
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
									IF ABS(@Bearing_Diff)>0.0000001
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
											ELSE IF CHARINDEX('Top short failed: Vertical radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + ', Top short failed: Vertical radius too large'
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
									IF ABS(@Bearing_Diff)>0.0000001
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
											ELSE IF CHARINDEX('Top short failed: Vertical radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + ', Top short failed: Vertical radius too large'
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
						-- Compute long top (vertical versine) values
						--===============================================================================================================================================
						IF @ChainageIndex >= @MinChainage + @LongTopChord AND @ChainageIndex <= @MaxChainage - @LongTopChord
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
									IF ABS(@Bearing_Diff)>0.0000001
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
											ELSE IF CHARINDEX('Top long failed: Vertical radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + ', Top long failed: Vertical radius too large'
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
									IF ABS(@Bearing_Diff)>0.0000001
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
											ELSE IF CHARINDEX('Top long failed: Vertical radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + ', Top long failed: Vertical radius too large'
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
						-- Compute short line (horizontal versine) values
						--===============================================================================================================================================
						IF @ChainageIndex >= @MinChainage + @ShortLineChord AND @ChainageIndex <= @MaxChainage - @ShortLineChord
							BEGIN

								--Left Rail--------------------------------------------------------------------------------------------------------
								--Reset all left rail variables to maintain NULL storage of out of bound data
								SELECT @Data_E_From = NULL, @Data_N_From = NULL, @Data_H_From = NULL
								SELECT @Data_E_At = NULL, @Data_N_At = NULL, @Data_H_At = NULL
								SELECT @Data_E_To = NULL, @Data_N_To = NULL, @Data_H_To = NULL
								SELECT @Side_A = NULL, @Side_B = NULL, @Side_C = NULL
								SELECT @Param_Top = NULL, @CalculationComment = NULL

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
									IF ABS(@Bearing_Diff)>0.0000001
										BEGIN
											SET @Param_Radius = (@Side_A * @Side_B * @Side_C) / NULLIF(SQRT((@Side_A + @Side_B + @Side_C) * (@Side_B + @Side_C - @Side_A) * (@Side_A + @Side_C - @Side_B) * (@Side_A + @Side_B - @Side_C)),0)
											SET @Param_Top = SQUARE(@Side_C) / (8 * @Param_Radius) * (@Bearing_Diff / NULLIF(ABS(@Bearing_Diff),0))
										END
									ELSE	
										BEGIN 
											SET @Param_Radius = NULL
											SET @Param_Top = NULL
											SET @CalculationWarning = @CalculationWarning + 1
											IF @CalculationComment IS NULL SET @CalculationComment = 'Line short failed: Horizontal radius too large' 
											ELSE IF CHARINDEX('Line short failed: Horizontal radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + ', Line short failed: Horizontal radius too large'
										END
								END
								--Import left rail results into the #TrackGeometry table
								UPDATE #TrackGeometry SET [LR_Line_Short] = CAST(@Param_Top as Decimal (14,4)), [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

								--Right Rail--------------------------------------------------------------------------------------------------------
								--Reset all right rail variables to maintain NULL storage of out of bound data
								SELECT @Data_E_From = NULL, @Data_N_From = NULL, @Data_H_From = NULL
								SELECT @Data_E_At = NULL, @Data_N_At = NULL, @Data_H_At = NULL
								SELECT @Data_E_To = NULL, @Data_N_To = NULL, @Data_H_To = NULL
								SELECT @Side_A = NULL, @Side_B = NULL, @Side_C = NULL
								SELECT @Param_Top = NULL
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
									IF ABS(@Bearing_Diff)>0.0000001
										BEGIN
											SET @Param_Radius = (@Side_A * @Side_B * @Side_C) / NULLIF(SQRT((@Side_A + @Side_B + @Side_C) * (@Side_B + @Side_C - @Side_A) * (@Side_A + @Side_C - @Side_B) * (@Side_A + @Side_B - @Side_C)),0)
											SET @Param_Top = SQUARE(@Side_C) / (8 * @Param_Radius) * (@Bearing_Diff / NULLIF(ABS(@Bearing_Diff),0))
										END
									ELSE	
										BEGIN 
											SET @Param_Radius = NULL
											SET @Param_Top = NULL
											SET @CalculationWarning = @CalculationWarning + 1
											IF @CalculationComment IS NULL SET @CalculationComment = 'Line short failed: Horizontal radius too large' 
											ELSE IF CHARINDEX('Line short failed: Horizontal radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + ', Line short failed: Horizontal radius too large'
										END
								END
								--Import left rail results into the #TrackGeometry table
								UPDATE #TrackGeometry SET [RR_Line_Short] = CAST(@Param_Top as Decimal (14,4)), [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
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
						-- Compute long line (horizontal versine) values
						--===============================================================================================================================================
						IF @ChainageIndex >= @MinChainage + @LongLineChord AND @ChainageIndex <= @MaxChainage - @LongLineChord
							BEGIN

								--Left Rail--------------------------------------------------------------------------------------------------------
								--Reset all left rail variables to maintain NULL storage of out of bound data
								SELECT @Data_E_From = NULL, @Data_N_From = NULL, @Data_H_From = NULL
								SELECT @Data_E_At = NULL, @Data_N_At = NULL, @Data_H_At = NULL
								SELECT @Data_E_To = NULL, @Data_N_To = NULL, @Data_H_To = NULL
								SELECT @Side_A = NULL, @Side_B = NULL, @Side_C = NULL
								SELECT @Param_Top = NULL
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
									IF ABS(@Bearing_Diff)>0.0000001
										BEGIN
											SET @Param_Radius = (@Side_A * @Side_B * @Side_C) / NULLIF(SQRT((@Side_A + @Side_B + @Side_C) * (@Side_B + @Side_C - @Side_A) * (@Side_A + @Side_C - @Side_B) * (@Side_A + @Side_B - @Side_C)),0)
											SET @Param_Top = SQUARE(@Side_C) / (8 * @Param_Radius) * (@Bearing_Diff / NULLIF(ABS(@Bearing_Diff),0))
										END
									ELSE	
										BEGIN 
											SET @Param_Radius = NULL
											SET @Param_Top = NULL
											SET @CalculationWarning = @CalculationWarning + 1
											IF @CalculationComment IS NULL SET @CalculationComment = 'Line long failed: Horizontal radius too large' 
											ELSE IF CHARINDEX('Line long failed: Horizontal radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + ', Line long failed: Horizontal radius too large'
										END
								END
								--Import left rail results into the #TrackGeometry table
								UPDATE #TrackGeometry SET [LR_Line_Long] = CAST(@Param_Top as Decimal (14,4)), [LR_Radius] = @Param_Radius, [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)

								--Right Rail--------------------------------------------------------------------------------------------------------
								--Reset all right rail variables to maintain NULL storage of out of bound data
								SELECT @Data_E_From = NULL, @Data_N_From = NULL, @Data_H_From = NULL
								SELECT @Data_E_At = NULL, @Data_N_At = NULL, @Data_H_At = NULL
								SELECT @Data_E_To = NULL, @Data_N_To = NULL, @Data_H_To = NULL
								SELECT @Side_A = NULL, @Side_B = NULL, @Side_C = NULL
								SELECT @Param_Top = NULL
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
									IF ABS(@Bearing_Diff)>0.0000001
										BEGIN
											SET @Param_Radius = (@Side_A * @Side_B * @Side_C) / NULLIF(SQRT((@Side_A + @Side_B + @Side_C) * (@Side_B + @Side_C - @Side_A) * (@Side_A + @Side_C - @Side_B) * (@Side_A + @Side_B - @Side_C)),0)
											SET @Param_Top = SQUARE(@Side_C) / (8 * @Param_Radius) * (@Bearing_Diff / NULLIF(ABS(@Bearing_Diff),0))
										END
									ELSE	
										BEGIN 
											SET @Param_Radius = NULL
											SET @Param_Top = NULL
											SET @CalculationWarning = @CalculationWarning + 1
											IF @CalculationComment IS NULL SET @CalculationComment = 'Line long failed: Horizontal radius too large' 
											ELSE IF CHARINDEX('Line long failed: Horizontal radius too large', @CalculationComment) = 0 SET @CalculationComment = @CalculationComment + ', Line long failed: Horizontal radius too large'
										END
								END
								--Import left rail results into the #TrackGeometry table
								UPDATE #TrackGeometry SET [RR_Line_Long] = CAST(@Param_Top as Decimal (14,4)), [RR_Radius] = @Param_Radius, [Calculation_Comment] = @CalculationComment WHERE [Track_CL_Chainage] = ROUND(@ChainageIndex,2)
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

					--Write all of the completed lef tnad right track results to the centerline of the rail
					UPDATE #TrackGeometry SET [CL_Radius] = ([LR_Radius] + [RR_Radius])/2, [CL_Top_Short] = ([LR_Top_Short] + [RR_Top_Short])/2, [CL_Top_Long] = ([LR_Top_Long] + [RR_Top_Long])/2, [CL_Line_Short] = ([LR_Line_Short] + [RR_Line_Short])/2, [CL_Line_Long] = ([LR_Line_Long] + [RR_Line_Long])/2

					--Counter to check if any calculations were performed - this (along with track interpolation and geometry calculations) will be skipped when the 
					-- @PrismCount from GeoMoS extraction returns 0 prisms. 
					SET @Calculation_Check = 1
				END
		END
	
	--Check to see if any calculations were performed for the current rail line
	IF @Calculation_Check = 1
	BEGIN

		------------------------------------------------------------------------------------------------------------------------
		------------------------------------------------------------------------------------------------------------------------
		--SELECT * FROM #PrismData ------------------------------------------------------------------------------------------------------------------------
		--SELECT * FROM #TrackGeometry------------------------------------------------------------------------------------------------------------------------
		------------------------------------------------------------------------------------------------------------------------
		------------------------------------------------------------------------------------------------------------------------

		--===============================================================================================================================================
		-- Create and store results to temporary and permenant tables
		--===============================================================================================================================================
		PRINT '   ' + convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Storing results into [TrackGeometry] database.'
		
		--If first round of storage create a header template for the temporary storage of results
		IF OBJECT_ID ('tempdb..#ReportingData') IS NULL 
			BEGIN
				--Create headers for ##OverdueData 
				SELECT	[Point_Name], [Point_Epoch], [Point_Group], [Point_ExpTime_DD], [Point_ExpTime_DHM], [Point_Easting], [Point_Northing], [Point_Height], [Track_Code] 
				INTO	##OverdueData 
				FROM	#PrismData 
				WHERE	1=2
			END

		--Make a copy of overdue data for later error reporting
		INSERT INTO ##OverdueData 
		SELECT		[Point_Name], [Point_Epoch], [Point_Group], [Point_ExpTime_DD], [Point_ExpTime_DHM], [Point_Easting], [Point_Northing], [Point_Height], [Track_Code] 
		FROM		#PrismData 
		WHERE		Point_ExpTime_DD > @OverdueDataWarning/24.0

		--Create and store some variables for log reporting
		SELECT @OverdueCount = COUNT(Point_Name) FROM ##OverdueData WHERE Point_ExpTime_DD > @OverdueDataWarning/24.0
		SET @OverdueTotalCount = @OverdueTotalCount + @OverdueCount

		--Store the current round of prism data into the PrismHistory table
		SET @Database_Script =	'USE [TrackGeometry]
								INSERT INTO PrismHistory SELECT [Calculation_ID], [Point_Name], [Point_Epoch], [Point_Group], [Point_ExpTime_DD], [Point_ExpTime_DHM], 
								[Point_Easting], [Point_Northing], [Point_Height], [Point_EOffset], [Point_NOffset], [Point_HOffset], [Track_Chainage], [Track_RailSide], 
								[Track_Code], [Track_Easting], [Track_Northing], [Track_Height] FROM #PrismData'
		EXEC (@Database_Script)
		
		--Store the current round of geometry data into the GeometryHistory table
		SET @Database_Script =	'USE [TrackGeometry]
								INSERT INTO GeometryHistory SELECT [Calculation_ID], [Track_CL_Chainage], [Track_Code], [DataWindow_Start], [DataWindow_End], [Rail_Cant], 
								[Rail_Gauge], [Twist_Short], [Twist_Long], [LR_ID], [LR_Easting], [LR_Northing], [LR_Height], [LR_Radius], [LR_Top_Short], [LR_Top_Long], 
								[LR_Line_Short], [LR_Line_Long], [RR_ID], [RR_Easting], [RR_Northing], [RR_Height], [RR_Radius], [RR_Top_Short], [RR_Top_Long],
								[RR_Line_Short], [RR_Line_Long], [CL_ID], [CL_Easting], [CL_Northing], [CL_Height], [CL_Radius], [CL_Top_Short], [CL_Top_Long], 
								[CL_Line_Short], [CL_Line_Long], [Diff_Chainage_Left], [Diff_Chainage_Rght], [Calculation_Comment] FROM #TrackGeometry'
		EXEC (@Database_Script)

		--Store a merge of the #PrismData and #TrackGeometry tables containing all prism locations and the nearest neighbouring geometry calculation based on
		--chainage. Used for reporting purposes.
		SET @Database_Script =	'USE [TrackGeometry]
								INSERT INTO ReportingData SELECT CrossMatch.[Calculation_ID], [Point_Name] as [Parent_Instrument], CrossMatch.[Track_Code] + ''-'' + 
								RIGHT(''00''+CAST(CAST([Track_CL_Chainage] as decimal(10,0)) as varchar),3) as [Geometry_Instrument],[Track_Chainage] as [Point_Chainage], 
								[Track_CL_Chainage] as [Calculation_Chainage], [Track_CL_Chainage]-[Track_Chainage] as [Chainage_Diff],	[Point_Epoch], 
								[DataWindow_End] as [Calculation_Epoch], [Point_ExpTime_DD], [Rail_Cant], [Rail_Gauge],	[Twist_Short], [Twist_Long], [LR_ID], [LR_Easting], 
								[LR_Northing], [LR_Height], [LR_Radius], [LR_Top_Short], [LR_Top_Long], [LR_Line_Short], [LR_Line_Long], [RR_ID], [RR_Easting], [RR_Northing],
								[RR_Height], [RR_Radius], [RR_Top_Short], [RR_Top_Long], [RR_Line_Short], [RR_Line_Long], [CL_ID], [CL_Easting], [CL_Northing], 
								[CL_Height], [CL_Radius], [CL_Top_Short], [CL_Top_Long], [CL_Line_Short], [CL_Line_Long], [Diff_Chainage_Left],	[Diff_Chainage_Rght], 
								[Calculation_Comment] 
								FROM #PrismData CROSS APPLY (SELECT TOP (1) * FROM #TrackGeometry ORDER BY ABS(#TrackGeometry.[Track_CL_Chainage] - #PrismData.[Track_Chainage]), 
								#TrackGeometry.[Track_CL_Chainage]) AS CrossMatch
								ORDER BY [Track_CL_Chainage]'
		EXEC (@Database_Script)
		
		--Drop the #PrismData and #TrackGeometry tabled in preperation for the next round of calculations
		DROP TABLE #PrismData
		DROP TABLE #TrackGeometry

		IF @Debug = 2
			BEGIN
				--Enable the code below to clear the Geometry history and the PrismHistory tables
				SET @Database_Script =	'USE [TrackGeometry] DELETE FROM GeometryHistory DELETE FROM PrismHistory DELETE FROM ReportingData'
				EXEC (@Database_Script)
			END
	END

	-- Increase @Trackcounter index for next round of track calculations
	SELECT @TrackCounter = MIN([Row_ID]) FROM ##CalculationListing WHERE Row_ID > @TrackCounter

END

--===============================================================================================================================================
-- Exit Script Routine
--===============================================================================================================================================
ExitScript:

IF @Calculation_Check = 0 OR @Calculation_Check = 1
BEGIN
	PRINT Char(13) + 'TRACK GEOMETRY CALCULATIONS COMPLETE:' + Char(13)
	PRINT ' - Total number of prisms extracted for calculations: '+ CAST(@PrismTotalCount as varchar) + '.'
	PRINT ' - Total number of prisms failing the overdue data check: '+ CAST(@OverdueTotalCount as varchar) + '.'
	PRINT ' - Total number of calculation warnings recieved: '+ CAST(@CalculationWarning as varchar) + '.'
	PRINT ' - Calculations completed in: '+ CAST(CAST((DATEDIFF(ms, @CurrentDateTime, GETDATE())/1000.0) as decimal(10,2)) as varchar) + ' seconds.'
END

IF @ErrorLevel = 1
BEGIN
	PRINT	'ERROR REPORTED:' + Char(13)
	PRINT	'Modulo of provided "ChainageStep" and twist step or top/line chord length variables are not equal to 0.'
	PRINT	'Geometry parameters can not be calculated when the stepped interpolation of track prisms does not align with the required calculation lengths.'
	PRINT	'Please adjust the "ChainageStep" variable to align with the provided chord lengths or vice versa.'
	PRINT	''
	PRINT	'Modulo of short twist step = ' + STR(@ShortTwistStep%@ChainageStep,5,2)
	PRINT	'Modulo of long twist step = ' + STR(@LongTwistStep%@ChainageStep,5,2)
	PRINT	'Modulo of short line chord = ' + STR(@ShortLineChord%@ChainageStep,5,2)
	PRINT	'Modulo of long line chord = ' + STR(@LongLineChord%@ChainageStep,5,2)
	PRINT	'Modulo of short top chord = ' + STR(@ShortTopChord%@ChainageStep,5,2)
	PRINT	'Modulo of long top chord = ' + STR(@LongTopChord%@ChainageStep,5,2)
END

IF @SendOverdueEmail = 1
BEGIN
	
	IF @OverdueCount >= 1
	BEGIN
		--Send out email alert to all required recipients
		IF NOT EXISTS (SELECT * FROM msdb.dbo.sysmail_profile WHERE name = @EmailProfile)
			BEGIN
				PRINT(' - Error: The specified Database Mail profile: "' + @EmailProfile + '" does not exsit. Please contact script author for assistance.');
			END
		ELSE
			BEGIN
				
				PRINT ' - Sending overdue data alert to the following recipient(s): '+ CAST(@EmailRecipients as varchar) + '.'

				--Create an HTML table of all prisms which are outside of the required overdue limit
				DECLARE @Query nvarchar(MAX);
				DECLARE @html nvarchar(MAX);
				SET @Query = 'SELECT Point_Name as [Instrument Name:], Point_Group as [Point Group Name:], Point_ExpTime_DHM as [Time Since Last Reading:] FROM ##OverdueData WHERE Point_ExpTime_DD >' + CAST(@OverdueDataWarning as varchar) + '/24'
				EXEC SelectToHTML	@html = @html OUTPUT, 
									@query = @Query,
									@tablefontsize = '10pt',
									@tablefontstyle = 'calibri, sans-serif',
									@tablewidth = '500px',
									@cellpadding = '4',
									@tableboarderstyle = 'solid',
									@tableboardersize = '2',
									@tabletextalign = 'left',
									@columnwidth = '150px',
									@headerheight = '30px',
									@rowheight = '18px',
									@headerbackcolour = '#f44542',
									@headerfrontcolour = '#ffffff',
									@headerboardercolour = '#f44542',
									@rowbackcolour = '#ffffff',
									@rowfrontcolour = '#000000',
									@rowboardercolour = '#dddddd';

				--Extract metadata for the email alert
				DECLARE @MaxOverdueName varchar (256)
				DECLARE @MaxOverdueDuration varchar (256)
				SELECT TOP 1 @MaxOverdueName = Point_Name, @MaxOverdueDuration = Point_ExpTime_DD FROM ##OverdueData WHERE Point_ExpTime_DD > @OverdueDataWarning/24.0 ORDER BY Point_ExpTime_DD DESC

				--Build the subject and the body of the email
				DECLARE @Subject varchar (max)
				DECLARE @Body varchar (max)
				SET @Subject =	'Warning - Prisms Failed the Track Geometry Overdue Reading Check'
				SET @Body =		'<p><strong><span style="font-size: 11.0pt; font-family: Calibri,sans-serif;">'+
								'Prism data extracted for the "Track Geometry" script running on ' + @@servername + ' has failed the overdue reading check.' + CHAR(13) +
								'</span></strong></p><ul>'+
								'<li><span style="font-size: 10pt; font-family: Calibri, sans-serif;">'+
								CAST(@OverdueCount as varchar) + ' prism(s) have been identified as overdue using the set time limit of ' + CAST(@OverdueDataWarning as varchar) +' hour(s) (' + CAST(CAST(@OverdueDataWarning/24.0 as decimal(10,1)) as varchar) + ' day(s)).' + CHAR(13) + CHAR(13) + 
								'</span></li>'+
								'<li><span style="font-size: 10pt; font-family: Calibri, sans-serif;">'+
								'The most overdue track prism, ' + @MaxOverdueName + ' has not been observed for over ' + CAST(CAST(@MaxOverdueDuration as decimal(10,1)) as varchar) + ' day(s).' + CHAR(13) + CHAR(13) + 
								'</span></li></ul>'+
								'<p><span style="color: #000000;"><span style="font-size: 10pt; font-family: Calibri, sans-serif;">'+
								'The overdue observations will still be used in calculations, however, once the prisms are unobserved for more than ' + CAST(@DataExtractionWindow as varchar) +' hour(s) (' + CAST(CAST(@DataExtractionWindow/24.0 as decimal(10,1)) as varchar) + ' day(s)), the prism data cannot be included in the "Track Geometry" calculations.' + CHAR(13) +
								'Please check the prisms listed in the attached file or adjust GeoMoS point listing accordingly.' +
								'</span></span></span></p>'+
								@html+
								'</span></span></span></p>'+
								'<p class="footer"><span style="font-size: 10pt; color: #999999;"><em><span style="font-family: calibri, sans-serif;">Generated by TFdX - contact <a href="mailto:lwalsh@landsurveys.net.au">lwalsh@landsurveys.net.au</a> for updates.</span></em></span></p>'
		
				--Send the email alert
				EXEC msdb.dbo.[sp_send_dbmail]   
					@profile_name = @EmailProfile,								-- Is the name of the profile to send the message from.
					@recipients = @EmailRecipients,								-- Is a semicolon-delimited list of e-mail addresses to send the message to.
					@subject = @Subject,										-- Is the subject of the e-mail message.
					@body = @Body,												-- Is the body of the e-mail message.
					@body_format = 'HTML',										-- Is the format of the message body. 
					@query = 'SET NOCOUNT ON SELECT * FROM ##OverdueData',		-- Is a query to execute. The results of the query can be attached as a file, or included in the body of the e-mail message. 
					@attach_query_result_as_file = 1,							-- Specifies whether the result set of the query is returned as an attached file. 
					@query_result_header = 1,									-- Specifies whether the query results include column headers.
					@query_result_no_padding = 1,								-- When you set to 1, the query results are not padded, possibly reducing the file size.
					@query_result_separator = ',',								-- Is the character used to separate columns in the query output.
					@query_attachment_filename = 'Overdue_Prism_Listing.csv',	-- Specifies the file name to use for the result set of the query attachment.
					@exclude_query_output = 1									-- Specifies whether to return the output of the query execution in the e-mail message.
			END
		END
END

PRINT Char(13) + convert(varchar, GETDATE(),103) + ' ' + convert(varchar, GETDATE(), 14) + ' | Exiting Track Geometry script'
PRINT '**********************************************************************************' + Char(13)