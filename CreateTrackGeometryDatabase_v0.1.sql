DECLARE @DatabaseName varchar(100) = 'TrackGeometry' 

DECLARE @Script_Create_db varchar(200)
DECLARE @Script_Create_Table varchar(Max)
DECLARE @Script_Execute varchar(Max)

SET @Script_Create_db = 'CREATE DATABASE {dbName}'
SET @Script_Execute = REPLACE(@Script_Create_db, '{dbName}', @DatabaseName)
EXECUTE(@Script_Execute)

SET @Script_Create_Table = 
	'USE [{dbName}];					
	CREATE TABLE	TrackListing		([ID] int IDENTITY(1,1) PRIMARY KEY, [Track_Name] varchar(255), [Track_Code] varchar(127), [Track_Details] varchar (max), 
										[Calculation_Status] bit, [Calculation_Time] datetime)'
SET @Script_Execute = REPLACE(@Script_Create_Table, '{dbName}', @DatabaseName)
Print @Script_Execute


SET @Script_Create_Table = 
	'USE [{dbName}];	
	CREATE TABLE	GeometryHistory		([Track_CL_Chainage] varchar(100), [Track_Code] varchar(100) NULL, [DataWindow_Start] datetime, [DataWindow_End] datetime,
										[Rail_Cant] decimal (20,6), [Rail_Gauge] decimal (20,6), [Twist_Short] decimal (20,6), [Twist_Long] decimal (20,6),
										[LR_ID] varchar(100), [LR_Easting] decimal (20,6), [LR_Northing] decimal (20,6), [LR_Height] decimal (20,6), 
										[LR_Radius] decimal (20,6), [LR_Top_Short] decimal (20,6), [LR_Top_Long] decimal (20,6), [LR_Line_Short] decimal (20,6),
										[LR_Line_Long] decimal (20,6), [RR_ID] varchar(100), [RR_Easting] decimal (20,6), [RR_Northing] decimal (20,6), 
										[RR_Height] decimal (20,6), [RR_Radius] decimal (20,6), [RR_Top_Short] decimal (20,6), [RR_Top_Long] decimal (20,6),
										[RR_Line_Short] decimal (20,6), [RR_Line_Long] decimal (20,6), [CL_ID] varchar(100), [CL_Easting] decimal (20,6),
										[CL_Northing] decimal (20,6), [CL_Height] decimal (20,6), [CL_Radius] decimal (20,6), [CL_Top_Short] decimal (20,6),
										[CL_Top_Long] decimal (20,6), [CL_Line_Short] decimal (20,6), [CL_Line_Long] decimal (20,6));'
SET @Script_Execute = REPLACE(@Script_Create_Table, '{dbName}', @DatabaseName)
Print @Script_Execute


SET @Script_Create_Table = 
	'USE [{dbName}];	
	CREATE TABLE	PrismHistory		([Point_Name] nvarchar(100) NULL, [Point_Epoch] dateTime NULL, [Point_Group] nvarchar(100) NULL, 
										[Point_ExpTime_DD] decimal(20,6) NULL, [Point_ExpTime_DHM] varchar (100) NULL, [Point_Easting] float NULL,
										[Point_Northing] float NULL, [Point_Height] float NULL, [Point_EOffset] float NULL, [Point_NOffset] float NULL,
										[Point_HOffset] float NULL,	[Track_Chainage] float NULL, [Track_RailSide] nvarchar(1) NULL,	[Track_Code] nvarchar(100) NULL,
										[Track_Easting] float NULL,	[Track_Northing] float NULL, [Track_Height] float NULL)'
SET @Script_Execute = REPLACE(@Script_Create_Table, '{dbName}', @DatabaseName)
Print @Script_Execute