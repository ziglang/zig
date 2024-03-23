/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <windows.h>
#include <tchar.h>
#include <corecrt_startup.h>

#ifndef _UNICODE
#include <mbctype.h>
#endif

#define SPACECHAR _T(' ')
#define DQUOTECHAR _T('\"')

extern IMAGE_DOS_HEADER __ImageBase;

int _tmain (int, _TCHAR **, _TCHAR **);
int _tmain (int      __UNUSED_PARAM(argc),
           _TCHAR ** __UNUSED_PARAM(argv),
           _TCHAR ** __UNUSED_PARAM(envp))
{
  HINSTANCE hInstance;
  _TCHAR *lpCmdLine;
  DWORD nShowCmd;

  hInstance = (HINSTANCE) &__ImageBase;

#ifdef _UNICODE
  lpCmdLine = _wcmdln;
#else
  lpCmdLine = _acmdln;
#endif
  if (lpCmdLine)
    {
      BOOL inDoubleQuote = FALSE;
      while (*lpCmdLine > SPACECHAR || (*lpCmdLine && inDoubleQuote))
        {
          if (*lpCmdLine == DQUOTECHAR)
            inDoubleQuote = !inDoubleQuote;
#ifndef _UNICODE
          if (_ismbblead (*lpCmdLine))
            {
              if (lpCmdLine[1])
                ++lpCmdLine;
            }
#endif
          ++lpCmdLine;
        }
      while (*lpCmdLine && (*lpCmdLine <= SPACECHAR))
        lpCmdLine++;
    }
  else
    lpCmdLine = _TEXT("");

  {
    STARTUPINFO StartupInfo;
    memset (&StartupInfo, 0, sizeof (STARTUPINFO));
    GetStartupInfo (&StartupInfo);
    if (StartupInfo.dwFlags & STARTF_USESHOWWINDOW)
      nShowCmd = StartupInfo.wShowWindow;
    else
      nShowCmd = SW_SHOWDEFAULT;
  }

  return _tWinMain (hInstance, NULL, lpCmdLine, nShowCmd);
}
