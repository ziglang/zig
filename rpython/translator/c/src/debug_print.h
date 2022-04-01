/************************************************************/
/***  C header subsection: debug_print & related tools    ***/

#include <stdio.h>

/* values of the PYPYLOG environment variable:
   ("top-level" debug_prints means not between debug_start and debug_stop)

   (empty)         logging is turned off, apart from top-level debug_prints
                     that go to stderr
   fname or +fname logging for profiling: includes all debug_start/debug_stop
                     but not any nested debug_print, use +fname if there is a
                     colon : in fname
   :fname          full logging
   prefix:fname    conditional logging
   prefix1,prefix2:fname   conditional logging with multiple selections

   Conditional logging means that it only includes the debug_start/debug_stop
   sections whose name match 'prefix'.  Other sections are ignored, including
   all debug_prints that occur while this section is running and all nested
   subsections.

   Note that 'fname' can be '-' to send the logging data to stderr.
   If 'fname' includes the substring '%d' it is replaced with the
   current process id and you get the log for all subprocesses (and
   forks) in different files.  If 'fname' does not include '%d', it is
   removed from the environment and not passed to subprocesses.
*/

/* macros used by the generated code */
#define PYPY_HAVE_DEBUG_PRINTS    (pypy_have_debug_prints & 1 ? \
                                   (pypy_debug_ensure_opened(), 1) : 0)
#define PYPY_DEBUG_FILE           pypy_debug_file
#define PYPY_DEBUG_START(cat, ts) pypy_debug_start(cat, ts)
#define PYPY_DEBUG_STOP(cat, ts)  pypy_debug_stop(cat, ts)
#define OP_DEBUG_OFFSET(res)      res = pypy_debug_offset()
#define OP_DEBUG_FORKED(ofs, _)   pypy_debug_forked(ofs)
#define OP_HAVE_DEBUG_PRINTS(r)   r = (pypy_have_debug_prints & 1)

#ifdef RPY_REVERSE_DEBUGGER
RPY_EXTERN void rpy_reverse_db_teardown(void);
#  define OP_DEBUG_FLUSH() fflush(pypy_debug_file); rpy_reverse_db_teardown()
#else
#  define OP_DEBUG_FLUSH() fflush(pypy_debug_file)
#endif

/************************************************************/

/* prototypes (internal use only) */
RPY_EXTERN void pypy_debug_ensure_opened(void);
RPY_EXTERN long long pypy_debug_start(const char *category, Signed timestamp);
RPY_EXTERN long long pypy_debug_stop(const char *category, Signed timestamp);
RPY_EXTERN long pypy_debug_offset(void);
RPY_EXTERN void pypy_debug_forked(Signed original_offset);
RPY_EXTERN long pypy_have_debug_prints_for(const char *category_prefix);

RPY_EXTERN long pypy_have_debug_prints;
RPY_EXPORTED FILE *pypy_debug_file;

/* these should be in sync with the values defined in rlib/rtimer.py */
#define TIMESTAMP_UNIT_TSC 0
#define TIMESTAMP_UNIT_NS 1
#define TIMESTAMP_UNIT_QUERY_PERFORMANCE_COUNTER 2

#define OP_LL_READ_TIMESTAMP(val) READ_TIMESTAMP(val)

#include "src/asm.h"

/* asm_xxx.h may contain a specific implementation of READ_TIMESTAMP.
 * This is the default generic timestamp implementation.
 */
#ifndef READ_TIMESTAMP

#  ifdef _WIN32
#    define READ_TIMESTAMP(val) QueryPerformanceCounter((LARGE_INTEGER*)&(val))
#    define READ_TIMESTAMP_UNIT TIMESTAMP_UNIT_QUERY_PERFORMANCE_COUNTER
#  else

RPY_EXTERN long long pypy_read_timestamp(void);

#    define READ_TIMESTAMP(val)  (val) = pypy_read_timestamp()
#    define READ_TIMESTAMP_UNIT TIMESTAMP_UNIT_NS

#  endif
#endif

#define OP_LL_GET_TIMESTAMP_UNIT(res) res = READ_TIMESTAMP_UNIT
