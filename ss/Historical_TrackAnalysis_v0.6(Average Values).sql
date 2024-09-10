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

------------------------------------------------ BandD Function ------------------------------------------------
--Calculations for Bearing and Distance between given points (EastAt, NorthAt, EastTo, NorthTo)

IF OBJECT_ID (N'dbo.BandD') IS NOT NULL
	DROP FUNCTION [dbo].BandD;
GO

CREATE FUNCTION [dbo].BandD (@EastAt float, @NorthAt float, @EastTo float, @NorthTo float) RETURNS @t TABLE (Bearing float, Distance float)
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

IF OBJECT_ID (N'dbo.#myTable', N'U') IS NOT NULL Begin DROP TABLE #myTable; End
IF OBJECT_ID (N'dbo.#myTrackPoints', N'U') IS NOT NULL Begin DROP TABLE #myTrackPoints; End

------------------------------------------------ Track Analysis Script ------------------------------------------------
------------------------------------------------- SET VARIABLES -------------------------------------------------------

DECLARE @StartTimeCalc as Datetime
DECLARE @EndTimeCalc as Datetime
DECLARE @StartTimeHistory as Datetime
DECLARE @EndTimeHistory as Datetime
DECLARE @Interval as Int
DECLARE @NextRailCalcTime Datetime
DECLARE @myTrack as varchar(2)
DECLARE @CountColumn int

DECLARE @PointGroup as nvarchar(30) 
DECLARE @I as INT
DECLARE @MinChainage as Float
DECLARE @MaxChainage as Float
DECLARE @dChainage as Float
DECLARE @TrackName as nvarchar(32)

DECLARE @ID0 as nvarchar(100)
DECLARE @Chainage0 as Float
DECLARE @Easting0 as Float
DECLARE @Northing0 as Float
DECLARE @Height0 as Float
DECLARE @Easting0NULL as Float
DECLARE @Northing0NULL as Float
DECLARE @Height0NULL as Float
DECLARE @dLong0 as Float
DECLARE @dTran0 as Float
DECLARE @dHgt0 as Float

DECLARE @ID1 as nvarchar(100)
DECLARE @Chainage1 as Float
DECLARE @Easting1 as Float
DECLARE @Northing1 as Float
DECLARE @Height1 as Float
DECLARE @Easting1NULL as Float
DECLARE @Northing1NULL as Float
DECLARE @Height1NULL as Float

DECLARE @dLong1 as Float
DECLARE @dTran1 as Float
DECLARE @dHgt1 as Float

DECLARE @LR_East as Float
DECLARE @LR_North as Float
DECLARE @LR_Height as Float
DECLARE @LR_EastNULL as Float
DECLARE @LR_NorthNULL as Float
DECLARE @LR_HeightNULL as Float
DECLARE	@d_LR_East as Float
DECLARE	@d_LR_North as Float
DECLARE	@d_LR_Height as Float

DECLARE @RR_East as Float
DECLARE @RR_North as Float
DECLARE @RR_Height as Float
DECLARE @RR_EastNULL as Float
DECLARE @RR_NorthNULL as Float
DECLARE @RR_HeightNULL as Float
DECLARE	@d_RR_East as Float
DECLARE	@d_RR_North as Float
DECLARE	@d_RR_Height as Float

DECLARE @LR_3D_Offset as Float
DECLARE @RR_3D_Offset as Float

DECLARE @Cant as Float
DECLARE @Gauge as Float
DECLARE @ShortTwist as Float
DECLARE @LongTwist as Float

DECLARE @DynamicTableName nvarchar(32)
DECLARE @CreateTableQuery nvarchar(1000)
DECLARE @DeleteTableQuery nvarchar(1000)
DECLARE @InsertValuesQuery nvarchar(1000)
DECLARE @SelectTableQuery nvarchar(1000)
DECLARE @DropTableQuery nvarchar(1000)

SET DATEFORMAT dmy
SET NOCOUNT ON
-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
--									TO BE UPDATED BY USER	
SELECT @StartTimeHistory = '20170825 00:00', @EndTimeHistory = '20170825 01:00', @Interval=240
SET @NextRailCalcTime=@StartTimeHistory
-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------

-- Create a temp table for results
SET @DynamicTableName = 'HistoricRailResults'

SET @DeleteTableQuery= 'IF OBJECT_ID (N''dbo.'+@DynamicTableName+''', N''U'') IS NOT NULL Begin DROP TABLE '+@DynamicTableName+'; End'

SET @CreateTableQuery ='CREATE TABLE ' + @DynamicTableName + '(
				ID nvarchar(100) NULL,
				Data_Start datetime NULL,
				Data_End datetime NULL,
				Radius DECIMAL(14,0) NULL,
				Cant DECIMAL(14,4) NULL,
				Gauge DECIMAL (14,4) NULL,
				Short_Twist_2 DECIMAL(14,4) NULL,
				Long_Twist_14 DECIMAL(14,4) NULL,
				Vert_Vsine_10_Off DECIMAL(14,4) NULL,
				Vert_Vsine_10_Mid DECIMAL(14,4) NULL,
				Vert_Vsine_20_Mid DECIMAL(14,4) NULL,
				Horiz_Vsine_10_Mid DECIMAL(14,4) NULL)';

exec (@DeleteTableQuery);
exec (@CreateTableQuery);

SELECT @CountColumn = min( Row_ID ) from RailCalcTimes

WHILE @CountColumn is not null
BEGIN

	SELECT @myTrack=Track_Type FROM RailCalcTimes WHERE Row_ID =@CountColumn
	SET @NextRailCalcTime=@StartTimeHistory		     	

	-- Loop through data between designated start and end dates
	WHILE @EndTimeHistory > @NextRailCalcTime 
	BEGIN

		SET @StartTimeCalc=@NextRailCalcTime
		SET @EndTimeCalc=DateADD(hh,@Interval,@NextRailCalcTime)

		---------------------------------------IMPORT POINT DATA INTO TEMPORARY TABLE(s)----------------------------------------------

		------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------- Create temp #MyTable ----------------------------------------------------------
		------------------------------------------------------------------------------------------------------------------------------
		CREATE TABLE #MyTable(
			[ID] nvarchar(100) NULL,
			[Epoch] DateTime NULL,
			[Easting] float NULL,
			[Northing] float NULL,
			[Height] float NULL,
			[EastingNULL] float NULL,
			[NorthingNULL] float NULL,
			[HeightNULL] float NULL,
			[dE] float NULL,
			[dN] float NULL,
			[dH] float NULL,
			[dLong] float NULL,
			[dTran] float NULL,
			[dHgt] float NULL,
			[Profile] float NULL,
			[Chainage] float NULL,
			[Rail] nvarchar(1) NULL,
			[XOffset] float NULL,
			[YOffset] float NULL,
			[EastingShifted] float NULL,
			[NorthingShifted] float NULL,
			[HeightShifted] float NULL,
			[EastingShiftedNULL] float NULL,
			[NorthingShiftedNULL] float NULL,
			[HeightShiftedNULL] float NULL,
			[RailType] nvarchar(100) NULL)
	
		INSERT INTO #MyTable
		SELECT      Points.Name, CONVERT(varchar(10), @EndTimeCalc, 103) + ' ' + CONVERT(varchar(10), @EndTimeCalc, 108) AS Date, 
					AVG(Results.Easting) AS Easting, AVG(Results.Northing)  AS Northing, AVG(Results.Height)  AS Height, 
					Coordinates.Easting  AS EastNULL, Coordinates.Northing  AS NorthNULL, Coordinates.Height  AS HeightNULL, 
					AVG(Results.Easting) - Coordinates.Easting AS dE, AVG(Results.Northing) - Coordinates.Northing  AS dN, AVG(Results.Height) - Coordinates.Height  AS dH, 
					AVG(Results.LongitudinalDisplacement)  AS dLong, AVG(Results.TransverseDisplacement)  AS dTran, AVG(Results.HeightDisplacement)  AS dHgt, 
					Profiles.Azimuth as Profile, 
					AVG([dbo].[ParseString](Points.Description,'CH:')) AS Chainage,
					substring(Points.Name,4,1) AS Rail,
					AVG([dbo].[ParseString](Points.Description,'X:')) AS XOffset,
					AVG([dbo].[ParseString](Points.Description,'Y:')) AS YOffset, 
					NULL,NULL,NULL,NULL,NULL,NULL,SUBSTRING(Points.Name,1,2)
				
		FROM        Coordinates INNER JOIN
					Results INNER JOIN
					Points ON Results.Point_ID = Points.ID ON Coordinates.Point_ID = Points.ID INNER JOIN
					Profiles ON Points.Profile_ID = Profiles.ID LEFT OUTER JOIN
					PointGroups INNER JOIN
					PointGroupItems ON PointGroups.ID = PointGroupItems.PointGroup_ID ON Points.ID = PointGroupItems.Point_ID
		WHERE       (Results.Type = 0) AND (PointGroups.Name LIKE N'Track%') AND 
					(Results.Epoch >= @StartTimeCalc) AND (Results.Epoch < @EndTimeCalc)
						AND (Points.Name LIKE @myTrack + '%' )
		GROUP BY	Points.Name, Coordinates.Easting, Coordinates.Northing, Coordinates.Height, Coordinates.Type, Profiles.Azimuth
		HAVING		(Coordinates.Type = 1)
		ORDER BY	Chainage, Points.Name

		-- Shift Coordinates Based upon +ve Normal (+90 degrees) to PROFILE and distance by OFFSET
		UPDATE		#MyTable SET EastingShifted = Easting - Sin(Profile - PI()/2)*-XOffset 
		UPDATE		#MyTable SET NorthingShifted = Northing - Cos(Profile - PI()/2)*-XOffset 
		UPDATE		#MyTable SET HeightShifted = Height - YOffset 
		UPDATE		#MyTable SET EastingShiftedNULL = EastingNULL - Sin(Profile - PI()/2)*-XOffset 
		UPDATE		#MyTable SET NorthingShiftedNULL = NorthingNULL - Cos(Profile - PI()/2)*-XOffset 
		UPDATE		#MyTable SET HeightShiftedNULL = HeightNULL - YOffset 

		SELECT      
					@MinChainage=CEILING(MIN([dbo].[ParseString](Points.Description,'CH:'))),
					@MaxChainage=FLOOR(MAX([dbo].[ParseString](Points.Description,'CH:')))
		FROM       
					Points  INNER JOIN
					PointGroups INNER JOIN
					PointGroupItems ON PointGroups.ID = PointGroupItems.PointGroup_ID ON Points.ID = PointGroupItems.Point_ID
		WHERE		(PointGroups.Name LIKE N'Track%') 
					AND (Points.Name LIKE @myTrack + '%' )
	
		SET			@TrackName=(SELECT DISTINCT PointGroups.Name
		FROM       
					Points  INNER JOIN
					PointGroups INNER JOIN
					PointGroupItems ON PointGroups.ID = PointGroupItems.PointGroup_ID ON Points.ID = PointGroupItems.Point_ID
		WHERE		(PointGroups.Name LIKE N'Track%') 
					AND (Points.Name LIKE @myTrack + '%' ))

		SELECT * FROM #MyTable
		------------------------------------------------------------------------------------------------------------------------------
		-------------------------------------------- Create temp #myTrackPoints ------------------------------------------------------
		------------------------------------------------------------------------------------------------------------------------------
		CREATE TABLE #myTrackPoints(
				ID int NULL,
				ID_Name nvarchar(100) NULL,
				Chainage nvarchar(100) NULL,
				Data_Start datetime NULL,
				Data_End datetime NULL,
				LR_ID nvarchar(100) NULL,
				LR_East DECIMAL(14,5)NULL,
				LR_North DECIMAL(14,5)NULL,
				LR_Height DECIMAL(14,5)NULL,
				LR_EastNULL DECIMAL(14,5)NULL,
				LR_NorthNULL DECIMAL(14,5)NULL,
				LR_HeightNULL DECIMAL(14,5)NULL,
				LR_dEast DECIMAL(14,5)NULL,
				LR_dNorth DECIMAL(14,5)NULL,
				LR_dHeight DECIMAL(14,5)NULL,
				LR_3D_Offset DECIMAL(14,5)NULL,
				LR_Radius DECIMAL(14,5) NULL,
				LR_V_VSine_10_Off DECIMAL(14,5) NULL,
				LR_V_VSine_10_Mid DECIMAL(14,5) NULL,
				LR_V_VSine_20 DECIMAL(14,5) NULL,
				LR_H_VSine_10 DECIMAL(14,5) NULL,
				LR_H_VSine_10_NULL DECIMAL(14,5) NULL,	
				RR_ID nvarchar(100) NULL,
				RR_East DECIMAL(14,5)NULL,
				RR_North DECIMAL(14,5)NULL,
				RR_Height DECIMAL(14,5) NULL,
				RR_EastNULL DECIMAL(14,5)NULL,
				RR_NorthNULL DECIMAL(14,5)NULL,
				RR_HeightNULL DECIMAL(14,5)NULL,
				RR_dEast DECIMAL(14,5)NULL,
				RR_dNorth DECIMAL(14,5)NULL,
				RR_dHeight DECIMAL(14,5)NULL,
				RR_3D_Offset DECIMAL(14,5)NULL,
				RR_Radius DECIMAL(14,5) NULL,
				RR_V_VSine_10_Off DECIMAL(14,5) NULL,
				RR_V_VSine_10_Mid DECIMAL(14,5) NULL,
				RR_V_VSine_20 DECIMAL(14,5) NULL,
				RR_H_VSine_10 DECIMAL(14,5) NULL,
				RR_H_VSine_10_NULL DECIMAL(14,5) NULL,
				Cant DECIMAL(14,5) NULL,
				Gauge DECIMAL (14,5) NULL,
				ShortTwist DECIMAL(14,5) NULL,
				LongTwist DECIMAL(14,5) NULL,
				RailType nvarchar(100) NULL)

		-- Start 1m chainage loop
		SET @I = @MinChainage

		WHILE @I <= @MaxChainage
		
			------------------------------------------------------------------------------------------------------------------------------
			-- Generate 1m Interpolated Rail Points
			------------------------------------------------------------------------------------------------------------------------------
			BEGIN
				-- Previous LEFT Rail
				SELECT top 1 @ID0=ID, @Chainage0=Chainage,@dLong0=dLong,@dTran0=dTran,@dHgt0=dHgt,@Easting0=EastingShifted,@Northing0=NorthingShifted,@Height0=HeightShifted,@Easting0NULL=EastingShiftedNULL,@Northing0NULL=NorthingShiftedNULL,@Height0NULL=HeightShiftedNULL from #myTable WHERE Chainage < @I and Rail = 'L' order by Chainage desc
				-- Next LEFT Rail
				SELECT top 1 @ID1=ID, @Chainage1=Chainage,@dLong1=dLong,@dTran1=dTran,@dHgt1=dHgt,@Easting1=EastingShifted,@Northing1=NorthingShifted,@Height1=HeightShifted,@Easting1NULL=EastingShiftedNULL,@Northing1NULL=NorthingShiftedNULL,@Height1NULL=HeightShiftedNULL from #myTable WHERE Chainage >= @I and Rail = 'L' order by Chainage asc
		
				SET @dChainage= @Chainage1-@Chainage0

				SET @LR_East = (@I-@Chainage0)* (@Easting1-@Easting0) / NULLIF(@dChainage,0) + @Easting0
				SET @LR_North = (@I-@Chainage0)* (@Northing1-@Northing0) / NULLIF(@dChainage,0) + @Northing0
				SET @LR_Height = (@I-@Chainage0)* (@Height1-@Height0) / NULLIF(@dChainage,0) + @Height0

				SET @LR_EastNULL = (@I-@Chainage0)* (@Easting1NULL-@Easting0NULL) / NULLIF(@dChainage,0) + @Easting0NULL
				SET @LR_NorthNULL = (@I-@Chainage0)* (@Northing1NULL-@Northing0NULL) / NULLIF(@dChainage,0) + @Northing0NULL
				SET @LR_HeightNULL = (@I-@Chainage0)* (@Height1NULL-@Height0NULL) / NULLIF(@dChainage,0) + @Height0NULL

				-- Previous RIGHT Rail
				SELECT top 1 @ID0=ID, @Chainage0=Chainage,@dLong0=dLong,@dTran0=dTran,@dHgt0=dHgt,@Easting0=EastingShifted,@Northing0=NorthingShifted,@Height0=HeightShifted,@Easting0NULL=EastingShiftedNULL,@Northing0NULL=NorthingShiftedNULL,@Height0NULL=HeightShiftedNULL  from #myTable WHERE Chainage < @I and Rail = 'R' order by Chainage desc
				-- Next RIGHT Rail
				SELECT top 1 @ID1=ID, @Chainage1=Chainage,@dLong1=dLong,@dTran1=dTran,@dHgt1=dHgt,@Easting1=EastingShifted,@Northing1=NorthingShifted,@Height1=HeightShifted,@Easting1NULL=EastingShiftedNULL,@Northing1NULL=NorthingShiftedNULL,@Height1NULL=HeightShiftedNULL  from #myTable WHERE Chainage >= @I and Rail = 'R' order by Chainage asc
		
				SET @dChainage= @Chainage1-@Chainage0

				SET @RR_East = (@I-@Chainage0)* (@Easting1-@Easting0) / NULLIF(@dChainage,0) + @Easting0
				SET @RR_North = (@I-@Chainage0)* (@Northing1-@Northing0) / NULLIF(@dChainage,0) + @Northing0
				SET @RR_Height = (@I-@Chainage0)* (@Height1-@Height0) / NULLIF(@dChainage,0) + @Height0

				SET @RR_EastNULL = (@I-@Chainage0)* (@Easting1NULL-@Easting0NULL) / NULLIF(@dChainage,0) + @Easting0NULL
				SET @RR_NorthNULL = (@I-@Chainage0)* (@Northing1NULL-@Northing0NULL) / NULLIF(@dChainage,0) + @Northing0NULL
				SET @RR_HeightNULL = (@I-@Chainage0)* (@Height1NULL-@Height0NULL) / NULLIF(@dChainage,0) + @Height0NULL

				-- Calculate Cant, Guage and Twists

				SET @d_RR_East=@RR_East-@RR_EastNULL
				SET @d_RR_North=@RR_North-@RR_NorthNULL
				SET @d_RR_Height=@RR_Height-@RR_HeightNULL
				SET @d_LR_East=@LR_East-@LR_EastNULL
				SET @d_LR_North=@LR_North-@LR_NorthNULL
				SET @d_LR_Height=@LR_Height-@LR_HeightNULL

				SET @LR_3D_Offset=SQRT(SQUARE(@d_LR_East)+SQUARE(@d_LR_North)+SQUARE(@d_LR_Height))
				SET @RR_3D_Offset=SQRT(SQUARE(@d_RR_East)+SQUARE(@d_RR_North)+SQUARE(@d_RR_Height))

				SET @Cant=ABS(@RR_Height-@LR_Height)
				SET @Gauge = sqrt((@LR_East-@RR_East)*(@LR_East-@RR_East)+(@LR_North-@RR_North)*(@LR_North-@RR_North)+(@LR_Height-@RR_Height)*(@LR_Height-@RR_Height))

				SET @ShortTwist = @Cant - (Select Cant from #myTrackPoints where ID=@I-2)
				SET @LongTwist = @Cant - (Select Cant from #myTrackPoints where ID=@I-14)

				INSERT INTO #myTrackPoints(ID,ID_Name,Chainage,LR_ID,LR_East,LR_North,LR_Height,LR_EastNULL,LR_NorthNULL,LR_HeightNULL,LR_dEast,LR_dNorth,LR_dHeight,LR_3D_Offset,RR_ID,RR_East,RR_North,RR_Height,RR_EastNULL,RR_NorthNULL,RR_HeightNULL,RR_dEast,RR_dNorth,RR_dHeight, RR_3D_Offset,Cant,Gauge,ShortTwist,LongTwist,RailType)
				VALUES(@I,@myTrack + '_' + CAST(@I as nvarchar(4)),CAST(@I as float),@myTrack + '_L_' + CAST(@I as nvarchar(4)),@LR_East,@LR_North,@LR_Height,@LR_EastNULL,@LR_NorthNULL,@LR_HeightNULL, @d_LR_East, @d_LR_North, @d_LR_Height,@LR_3D_Offset, @myTrack + '_R_' + CAST(@I as nvarchar(4)),@RR_East,@RR_North,@RR_Height,@RR_EastNULL,@RR_NorthNULL,@RR_HeightNULL, @d_RR_East, @d_RR_North, @d_RR_Height,@RR_3D_Offset,@Cant,@Gauge,@ShortTwist,@LongTwist,@myTrack)
   
				SET @I = @I + 1
			END

		SELECT * FROM #myTrackPoints

		------------------------------------------------------------------------------------------------------------------------------
		-- Compute top and line values, need Table [myTrackPoints] to be complete as search is Positive into Table
		------------------------------------------------------------------------------------------------------------------------------
		DECLARE @RowCount INT
		DECLARE @LR_OffsetCheck as Float
		DECLARE @RR_OffsetCheck as Float
		DECLARE @P1 as nvarchar(100), @P2 as nvarchar(100), @P3 as nvarchar(100),@P4 as nvarchar(100), @P5 as nvarchar(100)
		DECLARE @Val1 as float,@Val2 as float,@Val3 as float,@Val4 as float,@Val5 as float
		DECLARE @Horiz_Vsine_10_NULL as float
		DECLARE @Side_a as float, @Side_b as float, @Side_c as float, @Radius as float
		DECLARE @Vert_Vsine_10_Off as float
		DECLARE @Vert_Vsine_10_Mid as float
		DECLARE @Vert_Vsine_20 as float
		DECLARE @E1 as float, @N1 as float, @E3 as float, @N3 as float, @E5 as float, @N5 as float
		DECLARE @E1_NULL as float, @N1_NULL as float, @E3_NULL as float, @N3_NULL as float, @E5_NULL as float, @N5_NULL as float
		DECLARE @Horiz_Vsine_10 as float
		DECLARE @BearingLongChord float
		DECLARE @BearingMidChord float
		DECLARE @DistanceMidChord float
		DECLARE @dAngle float

		SET @RowCount = (SELECT COUNT(ID) FROM #myTrackPoints) + @MinChainage
		SET @I = @MinChainage

		-- Loop through the rows of table #myTrackPoints
		WHILE (@I <= @RowCount)	
		BEGIN

			SELECT @LR_OffsetCheck=LR_3D_Offset from #myTrackPoints where ID=@I
			SELECT @RR_OffsetCheck=RR_3D_Offset from #myTrackPoints where ID=@I

			IF  @LR_OffsetCheck<0.05 AND @RR_OffsetCheck<0.05
			BEGIN
				-------------------------------------------------------------------------------------------------------------------
				-- Compute Vertical Radius and 10m Vertical Versine (With 1.8m Offset and Midordinate)
				-------------------------------------------------------------------------------------------------------------------
				IF @I>=@MinChainage +5 AND @I<= (Select MAX(ID) from #myTrackPoints)-5
					BEGIN
						--Left Rail 5m either side of ID (10m short)
						SELECT @P1=NULL, @P3=NULL, @P5=NULL
						SELECT @Val1=NULL, @Val2=NULL, @Val3=NULL
						SELECT @Vert_Vsine_10_Mid=NULL, @Vert_Vsine_10_Off=NULL

						SELECT @P1=LR_ID from #myTrackPoints where ID=@I-5
						SELECT @P3=LR_ID from #myTrackPoints where ID=@I
						SELECT @P5=LR_ID from #myTrackPoints where ID=@I+5

						SELECT @Val1=LR_Height from #myTrackPoints where LR_ID=@P1
						SELECT @Val2=LR_Height from #myTrackPoints where LR_ID=@P3
						SELECT @Val3=LR_Height from #myTrackPoints where LR_ID=@P5

						SET @Side_a = SQRT(SQUARE(@Val2-@Val1)+SQUARE(5))
						SET @Side_b = SQRT(SQUARE(@Val3-@Val2)+SQUARE(5))
						SET @Side_c = SQRT(SQUARE(@Val1-@Val3)+SQUARE(10))

						SELECT @BearingLongChord=Bearing  from dbo.BandD(@I-10,@Val1,@I+10,@Val3)
						SELECT @BearingMidChord=Bearing  from dbo.BandD(@I-10,@Val1,@I,@Val2)
						SET @dAngle = @BearingLongChord-@BearingMidChord

						IF ABS(@dAngle)>0.0000000001
							BEGIN
							SET @Radius = (@Side_a*@Side_b*@Side_c)/NULLIF(SQRT((@Side_a+@Side_b+@Side_c)*(@Side_b+@Side_c-@Side_a)*(@Side_a+@Side_c-@Side_b)*(@Side_a+@Side_b-@Side_c)),0)
							SET @Vert_Vsine_10_Off = (1.8*8.2)/(2*@Radius)*(@dAngle/NULLIF(ABS(@dAngle),0))
							Set @Vert_Vsine_10_Mid = SQUARE(@Side_c)/(8*@Radius)*(@dAngle/NULLIF(ABS(@dAngle),0))
							END
						ELSE
							BEGIN
							SET @Radius = NULL
							SET	@Vert_Vsine_10_Off = NULL
							SET	@Vert_Vsine_10_Mid = NULL
							END

						Update #myTrackPoints SET LR_V_VSine_10_Off = Cast(@Vert_Vsine_10_Off as Decimal (14,4)), LR_V_VSine_10_Mid = Cast(@Vert_Vsine_10_Mid as Decimal (14,4)) WHERE ID=@I

						--Right Rail 5m either side of ID (10m short)
						SELECT @P1=NULL, @P3=NULL, @P5=NULL
						SELECT @Val1=NULL, @Val2=NULL, @Val3=NULL
						SELECT @Vert_Vsine_10_Mid=NULL, @Vert_Vsine_10_Off=NULL

						SELECT @P1=RR_ID from #myTrackPoints where ID=@I-5
						SELECT @P3=RR_ID from #myTrackPoints where ID=@I
						SELECT @P5=RR_ID from #myTrackPoints where ID=@I+5

						SELECT @Val1=RR_Height from #myTrackPoints where RR_ID=@P1
						SELECT @Val2=RR_Height from #myTrackPoints where RR_ID=@P3
						SELECT @Val3=RR_Height from #myTrackPoints where RR_ID=@P5

						SET @Side_a = SQRT(SQUARE(@Val2-@Val1)+SQUARE(5))
						SET @Side_b = SQRT(SQUARE(@Val3-@Val2)+SQUARE(5))
						SET @Side_c = SQRT(SQUARE(@Val1-@Val3)+SQUARE(10))

						SELECT @BearingLongChord=Bearing  from dbo.BandD(@I-10,@Val1,@I+10,@Val3)
						SELECT @BearingMidChord=Bearing  from dbo.BandD(@I-10,@Val1,@I,@Val2)
						SET @dAngle = @BearingLongChord-@BearingMidChord

						IF ABS(@dAngle)>0.0000000001
							BEGIN
							SET @Radius = (@Side_a*@Side_b*@Side_c)/NULLIF(SQRT((@Side_a+@Side_b+@Side_c)*(@Side_b+@Side_c-@Side_a)*(@Side_a+@Side_c-@Side_b)*(@Side_a+@Side_b-@Side_c)),0)
							SET @Vert_Vsine_10_Off = (1.8*8.2)/(2*@Radius)*(@dAngle/NULLIF(ABS(@dAngle),0))
							Set @Vert_Vsine_10_Mid = SQUARE(@Side_c)/(8*@Radius)*(@dAngle/NULLIF(ABS(@dAngle),0))
							END
						ELSE
							BEGIN
							SET @Radius = NULL
							SET	@Vert_Vsine_10_Off = NULL
							SET	@Vert_Vsine_10_Mid = NULL
							END

						Update #myTrackPoints SET RR_V_VSine_10_Off = Cast(@Vert_Vsine_10_Off as Decimal (14,4)), RR_V_VSine_10_Mid = Cast(@Vert_Vsine_10_Mid as Decimal (14,4)) WHERE ID=@I
					END

				-------------------------------------------------------------------------------------------------------------------
				-- Compute Vertical Radius and 20m Vertical Versine (Mid Ordinate)
				-------------------------------------------------------------------------------------------------------------------
				IF @I>=@MinChainage+10 AND @I<= (Select MAX(ID) from #myTrackPoints)-10
					BEGIN
						--Left Rail 10m either side of ID (20m long)
						SELECT @P1=NULL, @P3=NULL, @P5=NULL
						SELECT @Val1=NULL, @Val2=NULL, @Val3=NULL
						SELECT @Vert_Vsine_20=NULL

						SELECT @P1=LR_ID from #myTrackPoints where ID=@I-10
						SELECT @P3=LR_ID from #myTrackPoints where ID=@I
						SELECT @P5=LR_ID from #myTrackPoints where ID=@I+10

						SELECT @Val1=LR_Height from #myTrackPoints where LR_ID=@P1
						SELECT @Val2=LR_Height from #myTrackPoints where LR_ID=@P3
						SELECT @Val3=LR_Height from #myTrackPoints where LR_ID=@P5

						SET @Side_a = SQRT(SQUARE(@Val2-@Val1)+SQUARE(10))
						SET @Side_b = SQRT(SQUARE(@Val3-@Val2)+SQUARE(10))
						SET @Side_c = SQRT(SQUARE(@Val1-@Val3)+SQUARE(20))

						SELECT @BearingLongChord=Bearing  from dbo.BandD(@I-10,@Val1,@I+10,@Val3)
						SELECT @BearingMidChord=Bearing  from dbo.BandD(@I-10,@Val1,@I,@Val2)
						SET @dAngle = @BearingLongChord-@BearingMidChord

						IF ABS(@dAngle)>0.0000000001
							BEGIN
							SET @Radius = (@Side_a*@Side_b*@Side_c)/NULLIF(SQRT((@Side_a+@Side_b+@Side_c)*(@Side_b+@Side_c-@Side_a)*(@Side_a+@Side_c-@Side_b)*(@Side_a+@Side_b-@Side_c)),0)
							SET @Vert_Vsine_20 = SQUARE(@Side_c)/(8*@Radius)*(@dAngle/NULLIF(ABS(@dAngle),0))
							END
						ELSE
							BEGIN
							SET @Radius = NULL
							SET	@Vert_Vsine_20 = NULL
							END

						Update #myTrackPoints SET LR_V_VSine_20 = Cast(@Vert_Vsine_20 as Decimal (14,4)) WHERE ID=@I

						--Right Rail 10m either side of ID (20m long)
						SELECT @P1=NULL, @P3=NULL, @P5=NULL
						SELECT @Val1=NULL, @Val2=NULL, @Val3=NULL
						SELECT @Vert_Vsine_20=NULL

						SELECT @P1=RR_ID from #myTrackPoints where ID=@I-10
						SELECT @P3=RR_ID from #myTrackPoints where ID=@I
						SELECT @P5=RR_ID from #myTrackPoints where ID=@I+10
	
						SELECT @Val1=RR_Height from #myTrackPoints where RR_ID=@P1
						SELECT @Val2=RR_Height from #myTrackPoints where RR_ID=@P3
						SELECT @Val3=RR_Height from #myTrackPoints where RR_ID=@P5

						SET @Side_a = SQRT(SQUARE(@Val2-@Val1)+SQUARE(10))
						SET @Side_b = SQRT(SQUARE(@Val3-@Val2)+SQUARE(10))
						SET @Side_c = SQRT(SQUARE(@Val1-@Val3)+SQUARE(20))

						SELECT @BearingLongChord=Bearing  from dbo.BandD(@I-10,@Val1,@I+10,@Val3)
						SELECT @BearingMidChord=Bearing  from dbo.BandD(@I-10,@Val1,@I,@Val2)
						SET @dAngle = @BearingLongChord-@BearingMidChord

						IF ABS(@dAngle)>0.0000000001
							BEGIN
							SET @Radius = (@Side_a*@Side_b*@Side_c)/NULLIF(SQRT((@Side_a+@Side_b+@Side_c)*(@Side_b+@Side_c-@Side_a)*(@Side_a+@Side_c-@Side_b)*(@Side_a+@Side_b-@Side_c)),0)
							SET @Vert_Vsine_20 = SQUARE(@Side_c)/(8*@Radius)*(@dAngle/NULLIF(ABS(@dAngle),0))
							END
						ELSE
							BEGIN
							SET @Radius = NULL
							SET	@Vert_Vsine_20 = NULL
							END

						Update #myTrackPoints SET RR_V_VSine_20 = Cast(@Vert_Vsine_20 as Decimal (14,4)) WHERE ID=@I

					END

					-------------------------------------------------------------------------------------------------------------------
					-- Compute Horizontal Radius and 10m Mid Ordinate Offsets using Coordinates 
					-------------------------------------------------------------------------------------------------------------------
		
					--Left Rail
					IF @I>=@MinChainage+5 AND @I<= (Select MAX(ID) from #myTrackPoints)-5
						BEGIN
					
							--Left Rail
							SELECT @P1=NULL, @P3=NULL, @P5=NULL
							SELECT @E1=NULL, @N1=NULL, @E3=NULL, @N3=NULL, @E5=NULL, @N5=NULL, @E1_NULL=NULL, @N1_NULL=NULL, @E3_NULL=NULL, @N3_NULL=NULL, @E5_NULL=NULL, @N5_NULL=NULL
							SELECT @Side_a=NULL, @Side_b=NULL, @Side_c=NULL
							SELECT @Radius=NULL, @Horiz_Vsine_10=NULL

							SELECT @P1=LR_ID from #myTrackPoints where ID=@I-5
							SELECT @P3=LR_ID from #myTrackPoints where ID=@I
							SELECT @P5=LR_ID from #myTrackPoints where ID=@I+5

							SELECT @E1=LR_East,@N1=LR_North,@E1_NULL=LR_EastNULL,@N1_NULL=LR_NorthNULL from #myTrackPoints where LR_ID=@P1
							SELECT @E3=LR_East,@N3=LR_North,@E3_NULL=LR_EastNULL,@N3_NULL=LR_NorthNULL from #myTrackPoints where LR_ID=@P3
							SELECT @E5=LR_East,@N5=LR_North,@E5_NULL=LR_EastNULL,@N5_NULL=LR_NorthNULL from #myTrackPoints where LR_ID=@P5

							SET @Side_a = SQRT(SQUARE(@E3-@E1)+SQUARE(@N3-@N1))
							SET @Side_b = SQRT(SQUARE(@E5-@E3)+SQUARE(@N5-@N3))
							SET @Side_c = SQRT(SQUARE(@E1-@E5)+SQUARE(@N1-@N5))

							SELECT @BearingLongChord=Bearing  from dbo.BandD(@E1,@N1,@E5,@N5)
							SELECT @BearingMidChord=Bearing  from dbo.BandD(@E1,@N1,@E3,@N3)
							SET @dAngle = @BearingLongChord-@BearingMidChord

							IF ABS(@dAngle)>0.0000000001
								BEGIN
								SET @Radius = (@Side_a*@Side_b*@Side_c)/NULLIF(SQRT((@Side_a+@Side_b+@Side_c)*(@Side_b+@Side_c-@Side_a)*(@Side_a+@Side_c-@Side_b)*(@Side_a+@Side_b-@Side_c)),0)
								SET @Horiz_Vsine_10 = SQUARE(@Side_c)/(8*@Radius)*(@dAngle/NULLIF(ABS(@dAngle),0))
								END
							ELSE
								BEGIN
								SET @Radius = NULL
								SET	@Horiz_Vsine_10 = NULL
								END

							SET @Horiz_Vsine_10_NULL =  [dbo].MidOrdinate(@E1_NULL,@N1_NULL,@E3_NULL,@N3_NULL,@E5_NULL,@N5_NULL)
							Update #myTrackPoints SET LR_Radius = Cast(@Radius as Decimal (14,5)), LR_H_VSine_10 = Cast(@Horiz_Vsine_10 as decimal (14,5)), LR_H_VSine_10_NULL = Cast(@Horiz_Vsine_10_NULL as Decimal (14,5)) WHERE ID= @I
	
							--Right Rail
							SELECT @P1=NULL, @P3=NULL, @P5=NULL
							SELECT @E1=NULL, @N1=NULL, @E3=NULL, @N3=NULL, @E5=NULL, @N5=NULL, @E1_NULL=NULL, @N1_NULL=NULL, @E3_NULL=NULL, @N3_NULL=NULL, @E5_NULL=NULL, @N5_NULL=NULL
							SELECT @Side_a=NULL, @Side_b=NULL, @Side_c=NULL
							SELECT @Radius=NULL, @Horiz_Vsine_10=NULL

							SELECT @P1=RR_ID from #myTrackPoints where ID=@I-5
							SELECT @P3=RR_ID from #myTrackPoints where ID=@I
							SELECT @P5=RR_ID from #myTrackPoints where ID=@I+5

							SELECT @E1=RR_East,@N1=RR_North,@E1_NULL=RR_EastNULL,@N1_NULL=RR_NorthNULL from #myTrackPoints where RR_ID=@P1
							SELECT @E3=RR_East,@N3=RR_North,@E3_NULL=RR_EastNULL,@N3_NULL=RR_NorthNULL from #myTrackPoints where RR_ID=@P3
							SELECT @E5=RR_East,@N5=RR_North,@E5_NULL=RR_EastNULL,@N5_NULL=RR_NorthNULL from #myTrackPoints where RR_ID=@P5
					
							SET @Side_a = SQRT(SQUARE(@E3-@E1)+SQUARE(@N3-@N1))
							SET @Side_b = SQRT(SQUARE(@E5-@E3)+SQUARE(@N5-@N3))
							SET @Side_c = SQRT(SQUARE(@E1-@E5)+SQUARE(@N1-@N5))

							SELECT @BearingLongChord=Bearing  from dbo.BandD(@E1,@N1,@E5,@N5)
							SELECT @BearingMidChord=Bearing  from dbo.BandD(@E1,@N1,@E3,@N3)
							SET @dAngle = @BearingLongChord-@BearingMidChord

							IF ABS(@dAngle)>0.0000000001
								BEGIN
								SET @Radius = (@Side_a*@Side_b*@Side_c)/NULLIF(SQRT((@Side_a+@Side_b+@Side_c)*(@Side_b+@Side_c-@Side_a)*(@Side_a+@Side_c-@Side_b)*(@Side_a+@Side_b-@Side_c)),0)
								SET @Horiz_Vsine_10 = SQUARE(@Side_c)/(8*@Radius)*(@dAngle/NULLIF(ABS(@dAngle),0))
								END
							ELSE
								BEGIN
								SET @Radius = NULL
								SET	@Horiz_Vsine_10 = NULL
								END

							SET @Horiz_Vsine_10_NULL =  [dbo].MidOrdinate(@E1_NULL,@N1_NULL,@E3_NULL,@N3_NULL,@E5_NULL,@N5_NULL)
							Update #myTrackPoints SET RR_Radius = Cast(@Radius as Decimal (14,5)), RR_H_VSine_10 = Cast(@Horiz_Vsine_10 as decimal (14,5)), RR_H_VSine_10_NULL = Cast(@Horiz_Vsine_10_NULL as Decimal (14,5)) WHERE ID= @I
		
						END
					END
				ELSE
					BEGIN
					Update #myTrackPoints SET LR_V_VSine_10_Off = NULL, LR_V_VSine_10_Mid = NULL WHERE ID=@I
					Update #myTrackPoints SET RR_V_VSine_10_Off = NULL, RR_V_VSine_10_Mid = NULL WHERE ID=@I
					Update #myTrackPoints SET LR_V_VSine_20 = NULL WHERE ID=@I
					Update #myTrackPoints SET RR_V_VSine_20 = NULL WHERE ID=@I
					Update #myTrackPoints SET LR_Radius = NULL, LR_H_VSine_10 = NULL, LR_H_VSine_10_NULL = NULL WHERE ID= @I
					Update #myTrackPoints SET RR_Radius = NULL, RR_H_VSine_10 = NULL, RR_H_VSine_10_NULL = NULL WHERE ID= @I
					Update #myTrackPoints SET Cant = NULL, Gauge = NULL, ShortTwist = NULL, LongTwist = NULL WHERE ID = @I
					END
			SET @I = @I  + 1
		END

		Update #myTrackPoints SET Data_Start = @StartTimeCalc
		Update #myTrackPoints SET Data_End = @EndTimeCalc

		-------------------------------------------------------------------------------------------------------------------
		-- Create an output table for the current Results
		-------------------------------------------------------------------------------------------------------------------
		SET @InsertValuesQuery = 'INSERT INTO ' + @DynamicTableName + ' (ID,Data_Start,Data_End,Radius,Cant,Gauge,Short_Twist_2,Long_Twist_14,Vert_Vsine_10_Off,Vert_Vsine_10_Mid,Vert_Vsine_20_Mid,Horiz_Vsine_10_Mid)
		SELECT ID_Name,Data_Start,Data_End,(LR_Radius+RR_Radius)/2,Cant,Gauge,ShortTwist,LongTwist,(LR_V_VSine_10_Off+RR_V_VSine_10_Off)/2,(LR_V_VSine_10_Mid+RR_V_VSine_10_Mid)/2,(LR_V_VSine_20+RR_V_VSine_20)/2,(LR_H_VSine_10+RR_H_VSine_10)/2
		FROM #myTrackPoints INNER JOIN #myTable ON #myTrackPoints.Chainage=FLOOR(#myTable.Chainage)
		WHERE #myTrackPoints.Chainage=FLOOR(#myTable.Chainage) AND #myTable.Rail = ''L''
		ORDER BY #myTrackPoints.Chainage;'

		exec (@InsertValuesQuery);

		----------------------------------------------------------------------------------------------------------------------

		DROP TABLE #myTable
		DROP TABLE #myTrackPoints

		SET @NextRailCalcTime=DateADD(hh,@Interval,@NextRailCalcTime)
	END

	select @CountColumn = min( Row_ID ) from RailCalcTimes where Row_ID > @CountColumn
END

SET @SelectTableQuery='SELECT * FROM ' + @DynamicTableName
SET @DropTableQuery='DROP TABLE ' + @DynamicTableName
exec (@SelectTableQuery);
exec (@DropTableQuery);


