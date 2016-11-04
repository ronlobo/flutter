@ECHO off
REM Copyright 2015 The Chromium Authors. All rights reserved.
REM Use of this source code is governed by a BSD-style license that can be
REM found in the LICENSE file.

SETLOCAL ENABLEDELAYEDEXPANSION
FOR %%i IN ("%~dp0..") DO SET "flutter_root=%%~fi" REM Get the parent directory
SET flutter_tools_dir=%flutter_root%\packages\flutter_tools
SET flutter_dir=%flutter_root%\packages\flutter
SET snapshot_path=%flutter_root%\bin\cache\flutter_tools.snapshot
SET stamp_path=%flutter_root%\bin\cache\flutter_tools.stamp
SET script_path=%flutter_tools_dir%\bin\flutter_tools.dart
REM TODO: Don't require dart to be on the user's path
SET dart=dart

REM Set current working directory to the flutter directory
PUSHD %flutter_root%
REM IF doesn't have an "or". Instead, just use GOTO
FOR /f %%r IN ('git rev-parse HEAD') DO SET revision=%%r
IF NOT EXIST %snapshot_path% GOTO do_snapshot
IF NOT EXIST %stamp_path% GOTO do_snapshot
FOR /f "delims=" %%x in (%stamp_path%) do set stamp_value=%%x
IF "!stamp_value!" NEQ "!revision!" GOTO do_snapshot

REM Getting modified timestamps in a batch file is ... troublesome
REM More info: http://stackoverflow.com/questions/1687014/how-do-i-compare-timestamps-of-files-in-a-dos-batch-script
FOR %%f IN (%flutter_tools_dir%\pubspec.yaml) DO SET yamlt=%%~tf
FOR %%a IN (%flutter_tools_dir%\pubspec.lock) DO SET lockt=%%~ta
IF !lockt! LSS !yamlt! GOTO do_snapshot

GOTO :after_snapshot

:do_snapshot
CD "%flutter_tools_dir%"
ECHO Updating flutter tool...
CALL pub.bat get
CD "%flutter_dir%"
REM Allows us to check if sky_engine's REVISION is correct
CALL pub.bat get
CD "%flutter_root%"
CALL %dart% --snapshot="%snapshot_path%" --packages="%flutter_tools_dir%\.packages" "%script_path%"
<nul SET /p=%revision%> "%stamp_path%"

:after_snapshot

REM Go back to last working directory
POPD
CALL %dart% "%snapshot_path%" %*

IF /I "%ERRORLEVEL%" EQU "253" (
   CALL %dart% --snapshot="%snapshot_path%" --packages="%flutter_tools_dir%\.packages" "%script_path%"
   CALL %dart% "%snapshot_path%" %*
)
