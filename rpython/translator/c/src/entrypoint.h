#ifdef PYPY_STANDALONE

#ifndef STANDALONE_ENTRY_POINT
#  define STANDALONE_ENTRY_POINT   PYPY_STANDALONE
#endif

#ifndef PYPY_MAIN_FUNCTION
#define PYPY_MAIN_FUNCTION main
#endif

RPY_EXTERN void RPython_StartupCode(void);
RPY_EXPORTED int PYPY_MAIN_FUNCTION(int argc, char *argv[]);
#endif  /* PYPY_STANDALONE */
