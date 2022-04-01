
/************************************************************/
/***  C header subsection: exceptions                     ***/

#ifdef HAVE_RTYPER // shrug, hopefully dies with PYPY_NOT_MAIN_FILE

/* just a renaming, unless DO_LOG_EXC is set */
#define RPyExceptionOccurred RPyExceptionOccurred1
#define RPY_DEBUG_RETURN()   /* nothing */


#ifdef DO_LOG_EXC
#undef RPyExceptionOccurred
#undef RPY_DEBUG_RETURN
#define RPyExceptionOccurred()  RPyDebugException("  noticing a")
#define RPY_DEBUG_RETURN()      RPyDebugException("leaving with")
#define RPyDebugException(msg)  (                                       \
  RPyExceptionOccurred1()                                               \
    ? (RPyDebugReturnShowException(msg, __FILE__, __LINE__, __FUNCTION__), 1) \
    : 0                                                                 \
  )
#endif
/* !DO_LOG_EXC: define the function anyway, so that we can shut
   off the prints of a debug_exc by remaking only testing_1.o */
RPY_EXTERN
void RPyDebugReturnShowException(const char *msg, const char *filename,
                                 long lineno, const char *functionname);

/* Hint: functions and macros not defined here, like RPyRaiseException,
   come from exctransformer via the table in extfunc.py. */

#define RPyFetchException(etypevar, evaluevar, type_of_evaluevar) do {  \
		etypevar = RPyFetchExceptionType();			\
		evaluevar = (type_of_evaluevar)RPyFetchExceptionValue(); \
		RPyClearException();					\
	} while (0)

/* prototypes */

RPY_EXTERN
void _RPyRaiseSimpleException(RPYTHON_EXCEPTION rexc);

#endif
