#ifndef Py_STRTOD_H
#define Py_STRTOD_H

#ifdef __cplusplus
extern "C" {
#endif

/* PyOS_double_to_string's "flags" parameter can be set to 0 or more of: */
#define Py_DTSF_SIGN      0x01 /* always add the sign */
#define Py_DTSF_ADD_DOT_0 0x02 /* if the result is an integer add ".0" */
#define Py_DTSF_ALT       0x04 /* "alternate" formatting. it's format_code
                                  specific */

/* PyOS_double_to_string's "type", if non-NULL, will be set to one of: */
#define Py_DTST_FINITE 0
#define Py_DTST_INFINITE 1
#define Py_DTST_NAN 2

#ifdef __cplusplus
}
#endif

#endif /* !Py_STRTOD_H */
