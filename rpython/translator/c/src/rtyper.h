/************************************************************/
/***  C header subsection: tools for RTyper-aware code    ***/

/* Note that RPython strings are not 0-terminated!  For debugging,
   use PyString_FromRPyString or RPyString_AsCharP */
#define RPyString_Size(rps)		((rps)->rs_chars.length)
#define _RPyString_AsString(rps)        ((rps)->rs_chars.items)

#define RPyUnicode_Size(rpu)		((rpu)->ru_chars.length)
#define _RPyUnicode_AsUnicode(rpu)	((rpu)->ru_chars.items)

RPY_EXTERN char *RPyString_AsCharP(RPyString *rps);
RPY_EXTERN void RPyString_FreeCache(void);
