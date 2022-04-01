#include "singleheader.h"
#include "src/exception.h"

#if defined(PYPY_CPYTHON_EXTENSION)
   PyObject *RPythonError;
#endif 

/******************************************************************/
#ifdef HAVE_RTYPER               /* RPython version of exceptions */
/******************************************************************/

void RPyDebugReturnShowException(const char *msg, const char *filename,
                                 long lineno, const char *functionname)
{
#ifdef DO_LOG_EXC
  fprintf(stderr, "%s %.*s: %s:%ld %s\n", msg,
          (int)(RPyFetchExceptionType()->ov_name->rs_chars.length),
          RPyFetchExceptionType()->ov_name->rs_chars.items,
          filename, lineno, functionname);
#endif
}

/* Hint: functions and macros not defined here, like RPyRaiseException,
   come from exctransformer via the table in extfunc.py. */

#define RPyFetchException(etypevar, evaluevar, type_of_evaluevar) do {  \
		etypevar = RPyFetchExceptionType();			\
		evaluevar = (type_of_evaluevar)RPyFetchExceptionValue(); \
		RPyClearException();					\
	} while (0)

/* implementations */

void _RPyRaiseSimpleException(RPYTHON_EXCEPTION rexc)
{
	RPyRaiseException(RPYTHON_TYPE_OF_EXC_INST(rexc), rexc);
}


/******************************************************************/
#endif                                             /* HAVE_RTYPER */
/******************************************************************/
