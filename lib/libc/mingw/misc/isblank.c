#define __NO_CTYPE_LINES
#include <ctype.h>

int __cdecl isblank (int _C)
{
  return (_isctype(_C, _BLANK) || _C == '\t');
}
