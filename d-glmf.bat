@echo off
rem ================================================================
rem  d-glmf.bat - switch Claude Code to the GLM flash config (glm-flash-settings)
rem  Runs from PATH or double-click; all logic lives in deploy.ps1.
rem  API key comes from the GLM_API_KEY environment variable.
rem  Note: also removes the vision sub-agent (flash runs multimodal
rem  on the main model; a leftover vision.md would mis-route).
rem ================================================================
setlocal
set "PSCMD=powershell"
where pwsh >nul 2>nul && set "PSCMD=pwsh"

"%PSCMD%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" -KeyEnvName GLM_API_KEY -ProfileLabel "GLM-5.3-Flash (glmf)" -AgentAction remove
set "EXITCODE=%ERRORLEVEL%"

rem Pause only when double-clicked (launched via explorer), not from a terminal
echo %cmdcmdline% | find /i "%~f0" >nul 2>nul && pause
exit /b %EXITCODE%
