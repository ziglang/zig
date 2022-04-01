#include "singleheader.h"
#include "src/debug_traceback.h"
#include <stdio.h>
#include <stdlib.h>

int pypydtcount = 0;
struct pypydtentry_s pypy_debug_tracebacks[PYPY_DEBUG_TRACEBACK_DEPTH];

void pypy_debug_traceback_print(void)
{
  int i;
  int skipping;
  void *my_etype = RPyFetchExceptionType();
  struct pypydtpos_s *location;
  void *etype;
  int has_loc;

  /* This code parses the pypy_debug_tracebacks array.  See example
     at the start of the file. */
  fprintf(stderr, "RPython traceback:\n");
  skipping = 0;
  i = pypydtcount;
  while (1)
    {
      i = (i - 1) & (PYPY_DEBUG_TRACEBACK_DEPTH-1);
      if (i == pypydtcount)
        {
          fprintf(stderr, "  ...\n");
          break;
        }

      location = pypy_debug_tracebacks[i].location;
      etype    = pypy_debug_tracebacks[i].exctype;
      has_loc  = location != NULL && location != PYPYDTPOS_RERAISE;

      if (skipping && has_loc && etype == my_etype)
        skipping = 0;     /* found the matching "f:17, &KeyError */

      if (!skipping)
        {
          if (has_loc)
            fprintf(stderr, "  File \"%s\", line %d, in %s\n",
                    location->filename, location->lineno, location->funcname);
          else
            {
              /* line "NULL, &KeyError" or "RERAISE, &KeyError" */
              if (!my_etype)
                my_etype = etype;
              if (etype != my_etype)
                {
                  fprintf(stderr, "  Note: this traceback is "
                                  "incomplete or corrupted!\n");
                  break;
                }
              if (location == NULL)  /* found the place that raised the exc */
                break;
              skipping = 1;     /* RERAISE: skip until "f:17, &KeyError" */
            }
        }
    }
}

void pypy_debug_catch_fatal_exception(void)
{
  pypy_debug_traceback_print();
  fprintf(stderr, "Fatal RPython error: %.*s\n",
          (int)(RPyFetchExceptionType()->ov_name->rs_chars.length),
          RPyFetchExceptionType()->ov_name->rs_chars.items);
  abort();
}
