#include <stdlib.h>
#include <stdio.h>
#include <wchar.h>
#include <windows.h>
#include <winnls.h>

int __cdecl __mingw_str_wide_utf8(const wchar_t * const wptr, char **mbptr, size_t *buflen)
{
  size_t len;
  char *buf;
  int ret = 0;

  len = WideCharToMultiByte(CP_UTF8, 0, wptr, -1, NULL, 0, NULL, NULL); /* Get utf-8 string length */
  buf = calloc(len + 1, sizeof (char)); /* Can we assume sizeof char always = 1? */

  if(!buf) len = 0;
  else {
    if (len != 0) ret = WideCharToMultiByte(CP_UTF8, 0, wptr, -1, buf, len, NULL, NULL); /*Do actual conversion*/
    buf[len] = '0'; /* Must terminate */
  }
  *mbptr = buf; /* Set string pointer to allocated buffer */
  if(buflen != NULL) *buflen = (len) * sizeof (char); /* Give length of allocated memory if needed. */
  return ret;
}

int __cdecl __mingw_str_utf8_wide(const char *const mbptr, wchar_t **wptr, size_t *buflen)
{
  size_t len;
  wchar_t *buf;
  int ret = 0;

  len = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, mbptr, -1, NULL, 0); /* Get converted size */
  buf = calloc(len + 1, sizeof (wchar_t)); /* Allocate memory accordingly */

  if(!buf) len = 0;
  else {
    if (len != 0) ret = MultiByteToWideChar (CP_UTF8, MB_ERR_INVALID_CHARS, mbptr, -1, buf, len); /* Do conversion */
    buf[len] = L'0'; /* Must terminate */
  }
  *wptr = buf; /* Set string pointer to allocated buffer */
  if (buflen != NULL) *buflen = len * sizeof (wchar_t); /* Give length of allocated memory if needed. */
  return ret; /* Number of characters written */
}

void __cdecl __mingw_str_free(void *ptr)
{
  if (ptr) free(ptr);
}
