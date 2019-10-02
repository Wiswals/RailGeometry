@echo off

SET Directory=%~dp0
SET Log_File="%Directory%ATG_LogFile.txt"
SET Config_File=%Directory%ATG_Configure.ini

@echo.>>%Log_File%
@echo =============================================================================================================================================================>>%Log_File%
@echo %date% %time% - Automated Track Geometry initiated.>>%Log_File%
@echo %date% %time% - Automated Track Geometry initiated.

rem Check the licence for this software is valid.
set Licence=30/10/2021

SETLOCAL EnableDelayedExpansion

    for /f "skip=1 tokens=1-6 delims= " %%a in ('wmic path Win32_LocalTime Get Day^,Hour^,Minute^,Month^,Second^,Year /Format:table') do (
        IF NOT "%%~f"=="" (
            set /a Today=10000 * %%f + 100 * %%d + %%a
            set Today=!Today:~-2,2!/!Today:~-4,2!/!Today:~-6,2!))

set "Licence=%Licence:~-2%%Licence:~3,2%%Licence:~0,2%"
set "Today=%Today:~-2%%Today:~3,2%%Today:~0,2%"

if %Today% GTR %Licence% (
    @echo.>>%Log_File%
    @echo %date% %time% - Error, software licence has expired, please contact lwalsh@landsurveys.net.au to renew.>>%Log_File%
    @echo =============================================================================================================================================================>>%Log_File%
    set /p Error=Press ENTER to exit...
	Exit)


rem Get configuration settings from the .ini file
@echo %date% %time% - Extracting user values from the configuration file...>>%Log_File%
@echo %date% %time% - Extracting user values from the configuration file.

if exist %Config_File% ( goto File_read ) else ( goto File_err_handler )

:File_err_handler
	@echo %date% %time% - Error, the configuration file %Config_File% could not be found.>>%Log_File%
	@echo %date% %time% - Batch file terminated.>>%Log_File%
    @echo =============================================================================================================================================================>>%Log_File%
	Exit

:File_read 
    FOR /f "tokens=1,2 delims==, eol=#" %%a IN (%Config_File%) DO (
    IF %%a==::ServerName SET ServerName=%%b
    IF %%a==::DatabaseName SET DatabaseName=%%b
    IF %%a==::CalculationFrequency SET CalculationFrequency=%%b
    IF %%a==::DataExtractionWindow SET DataExtractionWindow=%%b
    IF %%a==::OverdueDataWarning SET OverdueDataWarning=%%b
    IF %%a==::SendOverdueEmail SET SendOverdueEmail=%%b
    IF %%a==::EmailProfile SET EmailProfile=%%b
    IF %%a==::EmailRecipients SET EmailRecipients=%%b
    IF %%a==::ChainageStep SET ChainageStep=%%b
    IF %%a==::PrismSpacingLimit SET PrismSpacingLimit=%%b
    IF %%a==::ShortTwistStep SET ShortTwistStep=%%b
    IF %%a==::LongTwistStep SET LongTwistStep=%%b
    IF %%a==::ShortLineChord SET ShortLineChord=%%b
    IF %%a==::LongLineChord SET LongLineChord=%%b
    IF %%a==::ShortTopChord SET ShortTopChord=%%b
    IF %%a==::LongTopChord SET LongTopChord=%%b
    IF %%a==::LeftRailIndicator SET LeftRailIndicator=%%b
    IF %%a==::RightRailIndicator SET RightRailIndicator=%%b)

    IF "%ServerName%" == "" (@echo - Warning: Server Name not set, will use default value.)>>%Log_File%
    IF "%DatabaseName%" == "" (@echo - Warning: Database Name not set, will use default value.)>>%Log_File%
    IF "%CalculationFrequency%" == "" (@echo - Warning: Calculation Frequency not set, will use default value.)>>%Log_File%
    IF "%DataExtractionWindow%" == "" (@echo - Warning: Data Extraction Window not set, will use default value.)>>%Log_File%
    IF "%OverdueDataWarning%" == "" (@echo - Warning: Overdue Data Warning not set, will use default value.)>>%Log_File%
    IF "%SendOverdueEmail%" == "" (@echo - Warning: Send Overdue Email Alert not set, will use default value.)>>%Log_File%
    IF "%EmailProfile%" == "" (@echo - Warning: Email Profile not set, will use default value.)>>%Log_File%
    IF "%EmailRecipients%" == "" (@echo - Warning: Email Recipients List not set, will use default value.)>>%Log_File%
    IF "%ChainageStep%" == "" (@echo - Warning: Track Chainage Interpolation Step not set, will use default value.)>>%Log_File%
    IF "%PrismSpacingLimit%" == "" (@echo - Warning: Prism Spacing Limit not set, will use default value.)>>%Log_File%
    IF "%ShortTwistStep%" == "" (@echo - Warning: Short Twist Step Length not set, will use default value.)>>%Log_File%
    IF "%LongTwistStep%" == "" (@echo - Warning: Long Twist Step Length not set, will use default value.)>>%Log_File%
    IF "%ShortLineChord%" == "" (@echo - Warning: Short Line Chord Length not set, will use default value.)>>%Log_File%
    IF "%LongLineChord%" == "" (@echo - Warning: Long Line Chord Length not set, will use default value.)>>%Log_File%
    IF "%ShortTopChord%" == "" (@echo - Warning: Short Top Chord Length not set, will use default value.)>>%Log_File%
    IF "%LongTopChord%" == "" (@echo - Warning: Long Top Chord Length not set, will use default value.)>>%Log_File%
    IF "%LeftRailIndicator%" == "" (@echo - Warning: Left Rail Naming Indicator not set, will use default value.)>>%Log_File%
    IF "%RightRailIndicator%" == "" (@echo - Warning: Right Rail Naming Indicator not set, will use default value.)>>%Log_File%
    @echo.>>%Log_File%

rem Test the connection to the specified server
@echo %date% %time% - Testing server connection to %ServerName%...>>%Log_File%
sqlcmd -S "%ServerName%" -E -Q " "

if ERRORLEVEL 1 goto Connection_err_handler
		        goto Connection_made

	:Connection_err_handler
	@echo %date% %time% - SQLCMD returned %errorlevel% to the command shell.... Error could not connect to specified server.>>%Log_File%
	@echo %date% %time% - Batch file terminated.>>%Log_File%
    @echo =============================================================================================================================================================>>%Log_File%
	Exit
	
	:Connection_made
	@echo %date% %time% - Server connected.>>%Log_File%
    @echo %date% %time% - Server connected.

rem Test the connection to the specified database
@echo %date% %time% - Testing database connection to %DatabaseName%...>>%Log_File%
set Query="SET NOCOUNT ON; SELECT CASE WHEN COUNT(name) = 0 Then 'Doesnt Exsist' else 'Database Exsits' end AS DatabaseCheck FROM sys.databases WHERE name LIKE '%DatabaseName%'"

sqlcmd -S "%ServerName%" -E -Q %Query% -h -1 -o "%Directory%temp.txt"
set /P DatabaseResult= < "%Directory%temp.txt"
del "%Directory%temp.txt"

IF "%DatabaseResult%"=="Doesnt Exsist  " (
	@echo %date% %time% - Error, database not recognised or unable to connect, please try again.>>%Log_File%
    @echo =============================================================================================================================================================>>%Log_File%
	Exit )
	
@echo %date% %time% - Database connected.>>%Log_File%
@echo %date% %time% - Database connected.
@echo.>>%Log_File%

@echo %date% %time% - Running track initalisation script...>>%Log_File%
@echo %date% %time% - Running track initalisation script.
rem Run the inalisation script - %b2eincfile1%
sqlcmd -S "%ServerName%" -E -d "%DatabaseName%" -i "C:\Users\LewisW\Dropbox\Programming\GitHub\RailGeometry\InitialiseTrackGeometry_v0.1.sql" -h -1 >>%Log_File%
@echo.>>%Log_File%

@echo %date% %time% - Running track geometry calculation script...>>%Log_File%
@echo %date% %time% - Running track geometry calculation script.
rem Run the automated track geometry script
sqlcmd -S "%ServerName%" -E -d "%DatabaseName%" -i "C:\Users\LewisW\Dropbox\Programming\GitHub\RailGeometry\CalculateTrackGeometry_v0.1.sql" -v CalculationFrequency="%CalculationFrequency%" DataExtractionWindow="%DataExtractionWindow%" OverdueDataWarning="%OverdueDataWarning%" SendOverdueEmail="%SendOverdueEmail%" PrismSpacingLimit="%PrismSpacingLimit%" ChainageStep="%ChainageStep%" ShortTwistStep="%ShortTwistStep%" LongTwistStep="%LongTwistStep%" ShortLineChord="%ShortLineChord%" LongLineChord="%LongLineChord%" ShortTopChord="%ShortTopChord%" LongTopChord="%LongTopChord%" LeftRailIndicator="%LeftRailIndicator%" RightRailIndicator="%RightRailIndicator%" EmailProfile="%EmailProfile%" EmailRecipients="%EmailRecipients%" -h -1 >>%Log_File%
@echo.>>%Log_File%

@echo %date% %time% - Automated Track Geometry completed.>>%Log_File%
@echo %date% %time% - Automated Track Geometry completed.
@echo =============================================================================================================================================================>>%Log_File%
set /p Exit=Press ENTER to exit...