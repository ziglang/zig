/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <windows.h>

extern HINSTANCE __mingw_winmain_hInstance;
extern LPSTR __mingw_winmain_lpCmdLine;
extern DWORD __mingw_winmain_nShowCmd;

/*ARGSUSED*/
int main (int     __UNUSED_PARAM(flags),
	  char ** __UNUSED_PARAM(cmdline),
	  char ** __UNUSED_PARAM(inst))
{
  return (int) WinMain (__mingw_winmain_hInstance, NULL,
			__mingw_winmain_lpCmdLine, __mingw_winmain_nShowCmd);
}
