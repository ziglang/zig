/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT

#include <time.h>

// These are required to provide the unrepfixed data symbols "timezone"
// and "tzname"; we can't remap "timezone" via a define due to clashes
// with e.g. "struct timezone".
typedef void __cdecl (*_tzset_func)(void);
extern _tzset_func __MINGW_IMP_SYMBOL(_tzset);

// Default initial values until _tzset has been called; these are the same
// as the initial values in msvcrt/ucrtbase.
static char initial_tzname0[] = "PST";
static char initial_tzname1[] = "PDT";
static char *initial_tznames[] = { initial_tzname0, initial_tzname1 };
static long initial_timezone = 28800;
static int initial_daylight = 1;
char** __MINGW_IMP_SYMBOL(tzname) = initial_tznames;
long * __MINGW_IMP_SYMBOL(timezone) = &initial_timezone;
int * __MINGW_IMP_SYMBOL(daylight) = &initial_daylight;

void __cdecl _tzset(void)
{
  __MINGW_IMP_SYMBOL(_tzset)();
  // Redirect the __imp_ pointers to the actual data provided by the UCRT.
  // From this point, the exposed values should stay in sync.
  __MINGW_IMP_SYMBOL(tzname) = _tzname;
  __MINGW_IMP_SYMBOL(timezone) = __timezone();
  __MINGW_IMP_SYMBOL(daylight) = __daylight();
}

void __cdecl tzset(void)
{
  _tzset();
}

// Dummy/unused __imp_ wrappers, to make GNU ld not autoexport these symbols.
void __cdecl (*__MINGW_IMP_SYMBOL(tzset))(void) = tzset;
