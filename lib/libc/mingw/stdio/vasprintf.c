#define _GNU_SOURCE
#define __CRT__NO_INLINE

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

int vasprintf(char ** __restrict__ ret,
                      const char * __restrict__ format,
                      va_list ap) {
  int len;
  /* Get Length */
  len = _vscprintf(format,ap);
  if (len < 0) return -1;
  /* +1 for \0 terminator. */
  *ret = malloc(len + 1);
  /* Check malloc fail*/
  if (!*ret) return -1;
  /* Write String */
  _vsnprintf(*ret,len+1,format,ap);
  /* Terminate explicitly */
  (*ret)[len] = '\0';
  return len;
}

