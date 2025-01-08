/*
  Screen saver library by Anders Norlander <anorland@hem2.passagen.se>

  This library is (hopefully) compatible with Microsoft's
  screen saver library.

  This is public domain software.

 */
#include <windows.h>
#include <scrnsave.h>
#include <regstr.h>

/* screen saver window class */
#define CLASS_SCRNSAVE TEXT("WindowsScreenSaverClass")

/* globals */
HWND		hMainWindow = NULL;
BOOL		fChildPreview = FALSE;
HINSTANCE	hMainInstance;
TCHAR		szName[TITLEBARNAMELEN];
TCHAR		szAppName[APPNAMEBUFFERLEN];
TCHAR		szIniFile[MAXFILELEN];
TCHAR		szScreenSaver[22];
TCHAR		szHelpFile[MAXFILELEN];
TCHAR		szNoHelpMemory[BUFFLEN];
UINT		MyHelpMessage;

/* local house keeping */
static HINSTANCE hPwdLib = NULL;
static POINT pt_orig;
static BOOL checking_pwd = FALSE;
static BOOL closing = FALSE;
static BOOL w95 = FALSE;

typedef void (*PVFV)(void);
typedef BOOL (WINAPI *VERIFYPWDPROC)(HWND);
typedef DWORD (WINAPI *CHPWDPROC)(LPCTSTR, HWND, DWORD, PVOID);
static VERIFYPWDPROC VerifyScreenSavePwd = NULL;

/* function names */
#define szVerifyPassword "VerifyScreenSavePwd"

#ifdef UNICODE
#define szPwdChangePassword "PwdChangePasswordW"
#else
#define szPwdChangePassword "PwdChangePasswordA"
#endif

static void TerminateScreenSaver(HWND hWnd);
static BOOL RegisterClasses(void);
static LRESULT WINAPI SysScreenSaverProc(HWND,UINT,WPARAM,LPARAM);
static int LaunchScreenSaver(HWND hParent);
static void LaunchConfig(void);

static int ISSPACE(char c)
{
  return (c == ' ' || c == '\t');
}

static ULONG_PTR parse_ulptr(const char *s)
{
  ULONG_PTR res, n;
  const char *p;
  for (p = s; *p; p++)
    if (*p < '0' || *p > '9')
      break;
  p--;
  res = 0;
  for (n = 1; p >= s; p--, n *= 10)
    res += (*p - '0') * n;
  return res;
}

/* screen saver entry point */
int APIENTRY WinMain(HINSTANCE hInst, HINSTANCE hPrevInst,
                     LPSTR CmdLine, int nCmdShow)
{
  LPSTR p;
  OSVERSIONINFO vi;

  UNREFERENCED_PARAMETER(hPrevInst);
  UNREFERENCED_PARAMETER(nCmdShow);

  /* initialize */
  hMainInstance = hInst;

  vi.dwOSVersionInfoSize = sizeof(vi);
  GetVersionEx(&vi);
  /* check if we are going to check for passwords */
  if (vi.dwPlatformId == VER_PLATFORM_WIN32_WINDOWS)
    {
      HKEY hKey;
      /* we are using windows 95 */
      w95 = TRUE;
      if (RegOpenKey(HKEY_CURRENT_USER, REGSTR_PATH_SCREENSAVE ,&hKey) ==
          ERROR_SUCCESS)
        {
          DWORD check_pwd;
          DWORD size = sizeof(DWORD);
          DWORD type;
          LONG res;
          res = RegQueryValueEx(hKey, REGSTR_VALUE_USESCRPASSWORD,
                                NULL, &type, (PBYTE) &check_pwd, &size);
          if (check_pwd && res == ERROR_SUCCESS)
            {
              hPwdLib = LoadLibrary(TEXT("PASSWORD.CPL"));
              if (hPwdLib)
                VerifyScreenSavePwd = (VERIFYPWDPROC)(PVFV) GetProcAddress(hPwdLib, szVerifyPassword);
            }
          RegCloseKey(hKey);
        }
    }

  /* parse arguments */
  for (p = CmdLine; *p; p++)
    {
      switch (*p)
        {
        case 'S':
        case 's':
          /* start screen saver */
          return LaunchScreenSaver(NULL);

        case 'P':
        case 'p':
          {
            /* start screen saver in preview window */
            HWND hParent;
            fChildPreview = TRUE;
            while (ISSPACE(*++p));
            hParent = (HWND) parse_ulptr(p);
            if (hParent && IsWindow(hParent))
              return LaunchScreenSaver(hParent);
          }
          return 0;

        case 'C':
        case 'c':
          /* display configure dialog */
          LaunchConfig();
          return 0;

        case 'A':
        case 'a':
          {
            /* change screen saver password */
            HWND hParent;
            while (ISSPACE(*++p));
            hParent = (HWND) parse_ulptr(p);
            if (!hParent || !IsWindow(hParent))
              hParent = GetForegroundWindow();
            ScreenSaverChangePassword(hParent);
          }
          return 0;

        case '-':
        case '/':
        case ' ':
        default:
	  break;
        }
    }
  LaunchConfig();
  return 0;
}

static void LaunchConfig(void)
{
  /* FIXME: should this be called */
  RegisterDialogClasses(hMainInstance);
  /* display configure dialog */
  DialogBox(hMainInstance, MAKEINTRESOURCE(DLG_SCRNSAVECONFIGURE),
            GetForegroundWindow(), (DLGPROC)(PVFV) ScreenSaverConfigureDialog);
}


static int LaunchScreenSaver(HWND hParent)
{
  BOOL foo;
  UINT style;
  RECT rc;
  MSG msg;

  /* don't allow other tasks to get into the foreground */
  if (w95 && !fChildPreview)
    SystemParametersInfo(SPI_SCREENSAVERRUNNING, TRUE, &foo, 0);

  msg.wParam = 0;

  /* register classes, both user defined and classes used by screen saver
     library */
  if (!RegisterClasses())
    {
      MessageBox(NULL, TEXT("RegisterClasses() failed"), NULL, MB_ICONHAND);
      goto restore;
    }

  /* a slightly different approach needs to be used when displaying
     in a preview window */
  if (hParent)
    {
      style = WS_CHILD;
      GetClientRect(hParent, &rc);
    }
  else
    {
      style = WS_POPUP;
      rc.left = GetSystemMetrics(SM_XVIRTUALSCREEN);
      rc.top = GetSystemMetrics(SM_YVIRTUALSCREEN);
      rc.right = GetSystemMetrics(SM_CXVIRTUALSCREEN);
      rc.bottom = GetSystemMetrics(SM_CYVIRTUALSCREEN);
      style |= WS_VISIBLE;
    }

  /* create main screen saver window */
  hMainWindow = CreateWindowEx(hParent ? 0 : WS_EX_TOPMOST, CLASS_SCRNSAVE,
                               TEXT("SCREENSAVER"), style,
                               rc.left, rc.top, rc.right, rc.bottom, hParent, NULL,
                               hMainInstance, NULL);

  /* display window and start pumping messages */
  if (hMainWindow)
    {
      UpdateWindow(hMainWindow);
      ShowWindow(hMainWindow, SW_SHOW);

      while (GetMessage(&msg, NULL, 0, 0) == TRUE)
        {
          TranslateMessage(&msg);
          DispatchMessage(&msg);
        }
    }

restore:
  /* restore system */
  if (w95 && !fChildPreview)
    SystemParametersInfo(SPI_SCREENSAVERRUNNING, FALSE, &foo, 0);
  FreeLibrary(hPwdLib);
  return msg.wParam;
}

/* this function takes care of *must* do tasks, like terminating
   screen saver */
static LRESULT WINAPI SysScreenSaverProc(HWND hWnd, UINT msg,
                                  WPARAM wParam, LPARAM lParam)
{
  switch (msg)
    {
    case WM_CREATE:
      if (!fChildPreview)
        SetCursor(NULL);
      /* mouse is not supposed to move from this position */
      GetCursorPos(&pt_orig);
      break;
    case WM_DESTROY:
      PostQuitMessage(0);
      break;
    case WM_TIMER:
      if (closing)
        return 0;
      break;
    case WM_PAINT:
      if (closing)
        return DefWindowProc(hWnd, msg, wParam, lParam);
      break;
    case WM_SYSCOMMAND:
      if (!fChildPreview)
        switch (wParam)
          {
          case SC_CLOSE:
          case SC_SCREENSAVE:
          case SC_NEXTWINDOW:
          case SC_PREVWINDOW:
            return FALSE;
          }
      break;
    case WM_MOUSEMOVE:
    case WM_LBUTTONDOWN:
    case WM_RBUTTONDOWN:
    case WM_MBUTTONDOWN:
    case WM_KEYDOWN:
    case WM_SYSKEYDOWN:
    case WM_NCACTIVATE:
    case WM_ACTIVATE:
    case WM_ACTIVATEAPP:
      if (closing)
        return DefWindowProc(hWnd, msg, wParam, lParam);
      break;
    }
  return ScreenSaverProc(hWnd, msg, wParam, lParam);
}

LRESULT WINAPI DefScreenSaverProc(HWND hWnd, UINT msg,
                               WPARAM wParam, LPARAM lParam)
{
  /* don't do any special processing when in preview mode */
  if (fChildPreview || closing)
    return DefWindowProc(hWnd, msg, wParam, lParam);

  switch (msg)
    {
    case WM_CLOSE:
      TerminateScreenSaver(hWnd);
      /* do NOT pass this to DefWindowProc; it will terminate even if
         an invalid password was given.
       */
      return 0;
    case SCRM_VERIFYPW:
      /* verify password or return TRUE if password checking is turned off */
      if (VerifyScreenSavePwd)
        return VerifyScreenSavePwd(hWnd);
      else
        return TRUE;
    case WM_SETCURSOR:
      if (checking_pwd)
        break;
      SetCursor(NULL);
      return TRUE;
    case WM_NCACTIVATE:
    case WM_ACTIVATE:
    case WM_ACTIVATEAPP:
      /* if wParam is FALSE then I am losing focus */
      if (wParam == FALSE && !checking_pwd)
        PostMessage(hWnd, WM_CLOSE, 0, 0);
      break;
    case WM_MOUSEMOVE:
      {
        POINT pt;
        GetCursorPos(&pt);
        if (pt.x == pt_orig.x && pt.y == pt_orig.y)
          break;
        /* mouse moved */
      }
      /* fallthrough */
    case WM_LBUTTONDOWN:
    case WM_RBUTTONDOWN:
    case WM_MBUTTONDOWN:
    case WM_KEYDOWN:
    case WM_SYSKEYDOWN:
      /* try to terminate screen saver */
      if (!checking_pwd)
        PostMessage(hWnd, WM_CLOSE, 0, 0);
      break;
    }
  return DefWindowProc(hWnd, msg, wParam, lParam);
}

static void TerminateScreenSaver(HWND hWnd)
{
  /* don't allow recursion */
  if (checking_pwd || closing)
    return;

  /* verify password */
  if (VerifyScreenSavePwd)
    {
      checking_pwd = TRUE;
      closing = SendMessage(hWnd, SCRM_VERIFYPW, 0, 0);
      checking_pwd = FALSE;
    }
  else
    closing = TRUE;

  /* are we closing? */
  if (closing)
    {
      DestroyWindow(hWnd);
    }
  else
    GetCursorPos(&pt_orig); /* if not: get new mouse position */
}

/*
  Register screen saver window class and call user
  supplied hook.
 */
static BOOL RegisterClasses(void)
{
  WNDCLASS cls;

  cls.hCursor = NULL;
  cls.hIcon = LoadIcon(hMainInstance, MAKEINTATOM(ID_APP));
  cls.lpszMenuName = NULL;
  cls.lpszClassName = CLASS_SCRNSAVE;
  cls.hbrBackground = GetStockObject(BLACK_BRUSH);
  cls.hInstance = hMainInstance;
  cls.style = CS_VREDRAW | CS_HREDRAW | CS_SAVEBITS | CS_PARENTDC;
  cls.lpfnWndProc = SysScreenSaverProc;
  cls.cbWndExtra = 0;
  cls.cbClsExtra = 0;

  if (!RegisterClass(&cls))
    return FALSE;

  return RegisterDialogClasses(hMainInstance);
}

void WINAPI ScreenSaverChangePassword(HWND hParent)
{
  /* load Master Password Router (MPR) */
  HINSTANCE hMpr = LoadLibrary(TEXT("MPR.DLL"));

  if (hMpr)
    {
      CHPWDPROC ChangePassword;
      ChangePassword = (CHPWDPROC)(PVFV) GetProcAddress(hMpr, szPwdChangePassword);

      /* change password for screen saver provider */
      if (ChangePassword)
        ChangePassword(TEXT("SCRSAVE"), hParent, 0, NULL);

      FreeLibrary(hMpr);
    }
}
