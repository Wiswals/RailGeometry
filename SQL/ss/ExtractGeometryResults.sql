IF OBJECT_ID ('tempdb..#Temp_Cant') IS NOT NULL Begin DROP TABLE #Temp_Cant; End
IF OBJECT_ID ('tempdb..#Temp_TwistShort') IS NOT NULL Begin DROP TABLE #Temp_TwistShort; End
IF OBJECT_ID ('tempdb..#Temp_TwistLong') IS NOT NULL Begin DROP TABLE #Temp_TwistLong; End
IF OBJECT_ID ('tempdb..#Temp_LineLong') IS NOT NULL Begin DROP TABLE #Temp_LineLong; End
IF OBJECT_ID ('tempdb..#Temp_TopShort') IS NOT NULL Begin DROP TABLE #Temp_TopShort; End

USE [TrackGeometry]

SET DATEFORMAT dmy 
SET ANSI_WARNINGS OFF 
DECLARE @StartTime as Datetime = DATEADD(hour,-200, GETDATE()) 
DECLARE @ParentFilter as nvarchar(32) = ''

SELECT		Geometry_Instrument + '-CNT' AS 'Instrument ID', 
			'Cant' As Parameter, 
			(CONVERT(varchar, Calculation_Epoch, 103) + ' ' + CONVERT(varchar,Calculation_Epoch, 24)) as Epoch, 
			Rail_Cant As Value, CAST(Calculation_ID as varchar) + '_' + CAST(Geometry_Instrument as varchar) + '-CNT' as Duplication_ID
INTO		#Temp_Cant
FROM		ReportingData
WHERE		(Calculation_Epoch > @StartTime) AND 
			(Parent_Instrument LIKE '%%%' + @ParentFilter + '%%%')

SELECT		Geometry_Instrument + '-TWS' AS 'Instrument ID', 
			'Twist_Short_2.4' As Parameter, 
			(CONVERT(varchar, Calculation_Epoch, 103) + ' ' + CONVERT(varchar,Calculation_Epoch, 24)) as Epoch, 
			Twist_Short As Value, CAST(Calculation_ID as varchar) + '_' + CAST(Geometry_Instrument as varchar) + '-TWS' as Duplication_ID
INTO		#Temp_TwistShort
FROM		ReportingData
WHERE		(Calculation_Epoch > @StartTime) AND 
			(Parent_Instrument LIKE '%%%' + @ParentFilter + '%%%')

SELECT		Geometry_Instrument + '-TWL' AS 'Instrument ID', 
			'Twist_Long_14.4' As Parameter, 
			(CONVERT(varchar, Calculation_Epoch, 103) + ' ' + CONVERT(varchar,Calculation_Epoch, 24)) as Epoch, 
			Twist_Long As Value, CAST(Calculation_ID as varchar) + '_' + CAST(Geometry_Instrument as varchar) + '-TWL' as Duplication_ID
INTO		#Temp_TwistLong
FROM		ReportingData
WHERE		(Calculation_Epoch > @StartTime) AND 
			(Parent_Instrument LIKE '%%%' + @ParentFilter + '%%%')

SELECT		Geometry_Instrument + '-LNE' AS 'Instrument ID', 
			'Line_9.6' As Parameter, 
			(CONVERT(varchar, Calculation_Epoch, 103) + ' ' + CONVERT(varchar,Calculation_Epoch, 24)) as Epoch, 
			CL_Line_Long As Value, CAST(Calculation_ID as varchar) + '_' + CAST(Geometry_Instrument as varchar) + '-LNE' as Duplication_ID
INTO		#Temp_LineLong
FROM		ReportingData
WHERE		(Calculation_Epoch > @StartTime) AND 
			(Parent_Instrument LIKE '%%%' + @ParentFilter + '%%%')

SELECT		Geometry_Instrument + '-TOP' AS 'Instrument ID', 
			'Top_4.8' As Parameter, 
			(CONVERT(varchar, Calculation_Epoch, 103) + ' ' + CONVERT(varchar,Calculation_Epoch, 24)) as Epoch, 
			CL_Top_Short As Value, CAST(Calculation_ID as varchar) + '_' + CAST(Geometry_Instrument as varchar) + '-TOP' as Duplication_ID
INTO		#Temp_TopShort
FROM		ReportingData
WHERE		(Calculation_Epoch > @StartTime) AND 
			(Parent_Instrument LIKE '%%%' + @ParentFilter + '%%%')

SELECT DISTINCT [Instrument ID], Parameter, Epoch, Value FROM #Temp_Cant
WHERE Value IS NOT NULL
UNION
SELECT DISTINCT [Instrument ID], Parameter, Epoch, Value FROM #Temp_TwistShort
WHERE Value IS NOT NULL
UNION
SELECT DISTINCT [Instrument ID], Parameter, Epoch, Value FROM #Temp_TwistLong
WHERE Value IS NOT NULL
UNION
SELECT DISTINCT [Instrument ID], Parameter, Epoch, Value FROM #Temp_LineLong
WHERE Value IS NOT NULL
UNION
SELECT DISTINCT [Instrument ID], Parameter, Epoch, Value FROM #Temp_TopShort
WHERE Value IS NOT NULL
ORDER BY [Instrument ID]