@Echo OFF
title Loading...
wpeinit
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File ".\BitLockerUtility.ps1"
