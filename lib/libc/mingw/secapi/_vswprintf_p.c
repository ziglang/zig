#include <sec_api/stdio_s.h>

int __cdecl _vswprintf_p(wchar_t *_DstBuf, size_t _MaxCount, const wchar_t *_Format, va_list _ArgList)
{
    return _vswprintf_p_l(_DstBuf, _MaxCount, _Format, NULL, _ArgList);
}

int __cdecl (*__MINGW_IMP_SYMBOL(_vswprintf_p))(wchar_t*,size_t,const wchar_t*,va_list) = _vswprintf_p;
