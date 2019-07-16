/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _WS2DEF_
#define _WS2DEF_

#include <_mingw.h>
#include <winapifamily.h>

/* FIXME FIXME FIXME FIXME FIXME: Much more data need moving here.
 * This holds only SCOPE_LEVEL and SCOPE_ID so that compilations
 * do not fail.
 */

typedef enum _SCOPE_LEVEL {
  ScopeLevelInterface = 1,
  ScopeLevelLink      = 2,
  ScopeLevelSubnet    = 3,
  ScopeLevelAdmin     = 4,
  ScopeLevelSite      = 5,
  ScopeLevelOrganization = 8,
  ScopeLevelGlobal   = 14,
  ScopeLevelCount    = 16
} SCOPE_LEVEL;

typedef struct _SCOPE_ID {
  __C89_NAMELESS union {
    __C89_NAMELESS struct {
	ULONG	Zone : 28;
	ULONG	Level : 4;
    };
    ULONG Value;
  };
} SCOPE_ID, *PSCOPE_ID;

#endif /* _WS2DEF_ */
