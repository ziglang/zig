#include <stdlib.h>
#include <wchar.h>
#include "src/precommondefs.h"

RPY_EXTERN wchar_t* pypy_char2wchar(const char* arg, size_t *size);
RPY_EXTERN wchar_t* pypy_char2wchar_strict(const char* arg, size_t *size);
RPY_EXTERN void pypy_char2wchar_free(wchar_t *text);
RPY_EXTERN char* pypy_wchar2char(const wchar_t *text, size_t *error_pos);
RPY_EXTERN char* pypy_wchar2char_strict(const wchar_t *text, size_t *error_pos);
RPY_EXTERN void pypy_wchar2char_free(char *bytes);
