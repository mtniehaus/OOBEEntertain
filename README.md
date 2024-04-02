# OOBEEntertain

This set of scripts is designed to launch an Edge kiosk browser window in OOBE over the top of the
normal ESP window.  It will display whatever web page has been configured in the script.  You can
Alt-Tab if needed to get back to the normal ESP page; the browser window should close automatically
when ESP completes.

This is designed to be started from a Win32 app.  This is fairly messy because the Win32 app runs 
as LocalSystem in session 0, which can't interact with the user, so you have to use ServiceUI.exe or
equivalent to re-launch in session 1.  Then you need to be able to get past the Z-ordering limitations
in OOBE, which the ShiftF10 executable takes care of.  But then there's another complication: Edge 
won't run as LocalSystem (not really a great idea to run as LocalSyste anyway), so it has to 
impersonate the local defaultUser0 account.