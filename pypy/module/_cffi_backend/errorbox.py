# for Windows only
import sys
from rpython.rlib import jit
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo


MESSAGEBOX = sys.platform == "win32"

MODULE = r"""
#include <Windows.h>
#pragma comment(lib, "user32.lib")

static void *volatile _cffi_bootstrap_text;

RPY_EXTERN int _cffi_errorbox1(void)
{
    return InterlockedCompareExchangePointer(&_cffi_bootstrap_text,
                                             (void *)1, NULL) == NULL;
}

static DWORD WINAPI _cffi_bootstrap_dialog(LPVOID ignored)
{
    Sleep(666);    /* may be interrupted if the whole process is closing */
    MessageBoxW(NULL, (wchar_t *)_cffi_bootstrap_text,
                L"PyPy: Python-CFFI error",
                MB_OK | MB_ICONERROR);
    _cffi_bootstrap_text = NULL;
    return 0;
}

RPY_EXTERN void _cffi_errorbox(wchar_t *text)
{
    /* Show a dialog box, but in a background thread, and
       never show multiple dialog boxes at once. */
    HANDLE h;

    _cffi_bootstrap_text = text;
     h = CreateThread(NULL, 0, _cffi_bootstrap_dialog,
                      NULL, 0, NULL);
     if (h != NULL)
         CloseHandle(h);
}
"""

if MESSAGEBOX:

    eci = ExternalCompilationInfo(
            separate_module_sources=[MODULE],
            post_include_bits=["#include <wchar.h>\n",
                               "RPY_EXTERN int _cffi_errorbox1(void);\n",
                               "RPY_EXTERN void _cffi_errorbox(wchar_t *);\n"])

    cffi_errorbox1 = rffi.llexternal("_cffi_errorbox1", [],
                                     rffi.INT, compilation_info=eci)
    cffi_errorbox = rffi.llexternal("_cffi_errorbox", [rffi.CWCHARP],
                                    lltype.Void, compilation_info=eci)

    class Message:
        def __init__(self, space):
            self.space = space
            self.text_p = lltype.nullptr(rffi.CWCHARP.TO)

        def start_error_capture(self):
            ok = cffi_errorbox1()
            if rffi.cast(lltype.Signed, ok) != 1:
                return None

            return self.space.appexec([], """():
                import sys
                class FileLike:
                    def write(self, x):
                        try:
                            of.write(x)
                        except:
                            pass
                        self.buf += x
                fl = FileLike()
                fl.buf = ''
                of = sys.stderr
                sys.stderr = fl
                def done():
                    sys.stderr = of
                    return fl.buf
                return done
            """)

        def stop_error_capture(self, w_done):
            if w_done is None:
                return

            w_text = self.space.call_function(w_done)
            p = rffi.utf82wcharp(self.space.utf8_w(w_text),
                                 self.space.len_w(w_text),
                                 track_allocation=False)
            if self.text_p:
                rffi.free_wcharp(self.text_p, track_allocation=False)
            self.text_p = p      # keepalive

            cffi_errorbox(p)


    @jit.dont_look_inside
    def start_error_capture(space):
        msg = space.fromcache(Message)
        return msg.start_error_capture()

    @jit.dont_look_inside
    def stop_error_capture(space, x):
        msg = space.fromcache(Message)
        msg.stop_error_capture(x)

else:
    def start_error_capture(space):
        return None
    def stop_error_capture(space, nothing):
        pass
