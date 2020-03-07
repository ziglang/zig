#include <sec_api/stdio_s.h>

int __cdecl _vscwprintf_p(const wchar_t *format, va_list arglist)
{
    return _vscwprintf_p_l(format, NULL, arglist);
}

int __cdecl (*__MINGW_IMP_SYMBOL(_vscwprintf_p))(const wchar_t *, va_list) = _vscwprintf_p;
