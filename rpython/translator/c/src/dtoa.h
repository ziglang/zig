/* Exported functions from dtoa.c */

RPY_EXTERN
double _PyPy_dg_strtod(const char *str, char **ptr);

RPY_EXTERN
char * _PyPy_dg_dtoa(double d, int mode, int ndigits,
		     int *decpt, int *sign, char **rve);

RPY_EXTERN
void _PyPy_dg_freedtoa(char *s);
