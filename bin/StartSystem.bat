:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Program	: StartSystem.bat
:: Title	: SAP System Startup
::
:: Argument	: 1. SAP SystemID
:: ReturnCode	: 0=Success, 1=Error
:: Purpose	: Execute SAP System Startup.
::
:: Version	: v01
:: Author	: Naruhiro Ikeya
:: CreationDate	: 10/08/2023
::
:: Copyright (c) 2023 BeeX Inc. All rights reserved.
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
@ECHO OFF

:::::::::::::::::::::::::::::::::::::
::       SAP Instance Setting       ::
:::::::::::::::::::::::::::::::::::::
SET __SID__=%1
FOR %%i IN (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO CALL SET __SID__=%%__SID__:%%i=%%i%%
SET PATH=%PATH%;E:\usr\sap\%__SID__%\SYS\exe\uc\NTAMD64

IF "%__SID__%" neq "CPD" (
  ECHO invalid parameter %0 ^<SAP SID^>
  EXIT /B 1
)

::::::::::::::::::::::::::::::::::
::      Create Timestamp       ::
::::::::::::::::::::::::::::::::::
SET __TODAY__=%DATE:/=%
SET __TODAY__=%__TODAY__:~8%%__TODAY__:~4,4%
SET __TIME__=%TIME::=%
SET __TIME__=%__TIME__:.=%
SET __NOW__=%__TODAY__%%__TIME__: =0%

:::::::::::::::::::::::::::::::::::::::::::::::
::       LogFile Setting & housekeeping      ::
:::::::::::::::::::::::::::::::::::::::::::::::
FOR /F "usebackq" %%L IN (`powershell -inputformat none -command "Split-Path %~dp0 -Parent | Join-Path -ChildPath log"`) DO SET __LOGPATH__=%%L
IF NOT EXIST %__LOGPATH__% MKDIR %__LOGPATH__% 

SET __LOGFILE__=%__LOGPATH__%\%__SID__%_SAP_START_%__NOW__%.log
FORFILES /P %__LOGPATH__% /M %__SID__%_SAP_START_*.log /D -180 /C "CMD /C IF @isdir==FALSE DEL /Q @path" > NUL 2>&1

::::::::::::::::::::::::::::::::::::::::::::::
::       XML Configuration file Setting       ::
::::::::::::::::::::::::::::::::::::::::::::::
FOR /F "usebackq" %%L IN (`powershell -inputformat none -command "Split-Path %~dp0 -Parent | Join-Path -ChildPath conf"`) DO SET __XMLPATH__=%%L
SET __XMLFILE__=%__XMLPATH__%\StartSAPSystemConfig_%__SID__%.xml
IF NOT EXIST %__XMLFILE__% (
  CALL :__ECHO__ %__XMLFILE__% File not found.
  EXIT /B 1
)

:::::::::::::::::::::::::::::::
::       Call  PowerShell       ::
:::::::::::::::::::::::::::::::
CALL :__ECHO__ %__SID__% Instance Start.
powershell -inputformat none -NoProfile -command "%~dp0StartInstance.ps1 %__SID__% %__XMLFILE__%;exit $LASTEXITCODE" >>"%__LOGFILE__%"
IF ERRORLEVEL 1 (
  CALL :__ECHO__ %__SID__% Instance Start Error.
  EXIT /B 1
)
CALL :__ECHO__ %__SID__% Instance Start Success.


:::::::::::::::::::::::::::::::::::::
:: ------ Function section ------ ::
:::::::::::::::::::::::::::::::::::::
:__QUIT__
EXIT /B 0

:__ECHO__
ECHO [%DATE% %TIME%] %*
ECHO [%DATE% %TIME%] %* >>"%__LOGFILE__%"
EXIT /B 0
