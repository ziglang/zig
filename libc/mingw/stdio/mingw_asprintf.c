#define _GNU_SOURCE
#define __CRT__NO_INLINE

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

int __mingw_asprintf(char ** __restrict__ ret,
                     const char * __restrict__ format,
                     ...) {
  va_list ap;
  int len;
  va_start(ap,format);
  /* Get Length */
  len = __mingw_vsnprintf(NULL,0,format,ap);
  if (len < 0) goto _end;
  /* +1 for \0 terminator. */
  *ret = malloc(len + 1);
  /* Check malloc fail*/
  if (!*ret) {
    len = -1;
    goto _end;
  }
  /* Write String */
  __mingw_vsnprintf(*ret,len+1,format,ap);
  /* Terminate explicitly */
  (*ret)[len] = '\0';
  _end:
  va_end(ap);
  return len;
}

