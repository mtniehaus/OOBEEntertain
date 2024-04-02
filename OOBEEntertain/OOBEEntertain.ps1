<#PSScriptInfo

.VERSION 1.0

.GUID 31c7dfa4-b9ac-438d-a417-9763e56b6d10

.AUTHOR Michael Niehaus

.COMPANYNAME 

.COPYRIGHT

.TAGS OOBE Prompt

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 1.0:  Original published version.

#>

<#
.SYNOPSIS
Prompt the user for information.
.DESCRIPTION
This is a super-simple script, feel free to enhance it as needed.  It is designed to be run by ServiceUI, started by
a Win32 app.  It can then show a UI that will appear in OOBE.
.EXAMPLE
.\OOBEEntertain.ps1
#>

[CmdletBinding()]
Param(
)

Process {

    function CreateProcessAsDefaultUser {

        Add-Type @"
        using System;
        using System.Runtime.InteropServices;
    
        public struct PROCESS_INFORMATION
        {
            public IntPtr hProcess;
            public IntPtr hThread;
            public uint dwProcessId;
            public uint dwThreadId;
        }
    
        public struct SECURITY_ATTRIBUTES
        {
            public int nLength;
            public IntPtr lpSecurityDescriptor;
            public bool bInheritHandle;
        }
    
        public struct STARTUPINFO
        {
            public int cb;
            public string lpReserved;
            public string lpDesktop;
            public string lpTitle;
            public uint dwX;
            public uint dwY;
            public uint dwXSize;
            public uint dwYSize;
            public uint dwXCountChars;
            public uint dwYCountChars;
            public uint dwFillAttribute;
            public uint dwFlags;
            public ushort wShowWindow;
            public ushort cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }
    
        public class Win32API
        {
            [DllImport("userenv.dll", SetLastError = true)]
            public static extern bool CreateEnvironmentBlock(out IntPtr lpEnvironment, IntPtr hToken, bool bInherit);
            [DllImport("userenv.dll", SetLastError = true)]
            public static extern bool DestroyEnvironmentBlock(IntPtr lpEnvironment);
    
            [DllImport("wtsapi32.dll", SetLastError = true)]
            public static extern bool WTSQueryUserToken(UInt32 sessionId, out IntPtr TokenHandle);
    
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern bool CreateProcessAsUser(
                IntPtr hToken,
                string lpApplicationName,
                string lpCommandLine,
                ref SECURITY_ATTRIBUTES lpProcessAttributes,
                ref SECURITY_ATTRIBUTES lpThreadAttributes,
                bool bInheritHandles,
                uint dwCreationFlags,
                IntPtr lpEnvironment,
                string lpCurrentDirectory,
                ref STARTUPINFO lpStartupInfo,
                out PROCESS_INFORMATION lpProcessInformation);
        }
"@
    
        $sessionId = 1
        $TokenHandle = [IntPtr]::Zero
        $success = [Win32API]::WTSQueryUserToken($sessionId, [ref] $TokenHandle)
        if (!$success)
        {
            $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            $errorMessage = [System.ComponentModel.Win32Exception]::new($errorCode).Message
            Write-Host "WTSQueryUserToken failed: $errorMessage"
            return
        }
        $si = New-Object System.Diagnostics.ProcessStartInfo
        $si.FileName = "$($env:WINDIR)\system32\cmd.exe"
        $si.Arguments = " /c msedge.exe --kiosk https://pacman.js.org/ --edge-kiosk-type=fullscreen --no-first-run"
        $si.WorkingDirectory = "C:\Program Files (x86)\Microsoft\Edge\Application"
            
        $sa = New-Object SECURITY_ATTRIBUTES
        $sa.nLength = [System.Runtime.InteropServices.Marshal]::SizeOf($sa)
            
        $processInfo = New-Object PROCESS_INFORMATION
        
        $saProcess = New-Object SECURITY_ATTRIBUTES
        $saProcess.nLength = [System.Runtime.InteropServices.Marshal]::SizeOf($saProcess)
    
        $saThread = New-Object SECURITY_ATTRIBUTES
        $saThread.nLength = [System.Runtime.InteropServices.Marshal]::SizeOf($saThread)
    
        $siStartup = New-Object STARTUPINFO
        $siStartup.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($siStartup)
    
        $env = [IntPtr]::Zero
        [Win32API]::CreateEnvironmentBlock([ref ]$env, [IntPtr]::Zero, $False)
    
        $createProcessResult = [Win32API]::CreateProcessAsUser(
            $TokenHandle,
            $si.FileName,
            $si.Arguments,
            [ref] $saProcess,
            [ref] $saThread,
            $false,
            1024,
            $env,
            $si.WorkingDirectory,
            [ref] $siStartup,
            [ref] $processInfo)
    
        if (!$createProcessResult)
        {
            $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            $errorMessage = [System.ComponentModel.Win32Exception]::new($errorCode).Message
        
            Write-Host "CreateProcessAsUser failed: $errorMessage"
            return
        }
    
        Write-Host "Process ID: $($processInfo.dwProcessId)"
        
        [Win32API]::DestroyEnvironmentBlock($env)

        return $processInfo.dwProcessId
    }

    # Start logging
    Start-Transcript "$($env:ProgramData)\OOBEEntertain\OOBEEntertain.log"

    # Run ShiftF10.exe so that we can be in the foreground
    & .\ShiftF10.exe | Out-Null

    # Wait around for ESP to finish
    $processID = $null
    while ($true) {
        # Start Edge in kiosk browser mode, running as defaultUser0
        if ($null -eq $processID) {
            if (Test-Path "C:\Program FIles (x86)\Microsoft\Edge\Application\msedge_proxy.exe") {
                Write-Host "Attempting to start msedge.exe"
                $processID = CreateProcessAsDefaultUser
            } else {
                Write-Host "File msedge.exe does not exist"
            }
        }

        # Check if ESP is done
        $props = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Autopilot\EnrollmentStatusTracking\Device\Setup"
        if (($null -ne $props.HasProvisioningCompleted) -and ($props.HasProvisioningCompleted -ne 0)) {
            Write-Host "ESP status = $v, exiting"
            break
        }

        # Sleep and try again
        Write-Host "Still in ESP"
        Start-Sleep -Seconds 3
    }

    # Stop the main Edge process
    Stop-Process -Id $processID

}