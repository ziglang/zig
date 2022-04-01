
/************************************************************/
 /***  C header subsection: operations between floats      ***/


/*** unary operations ***/

#define OP_FLOAT_IS_TRUE(x,r)   OP_FLOAT_NE(x,0.0,r)
#define OP_FLOAT_NEG(x,r)       r = -x
#define OP_FLOAT_ABS(x,r)       r = fabs(x)

/***  binary operations ***/

#define OP_FLOAT_EQ(x,y,r)	  r = (x == y)
#define OP_FLOAT_NE(x,y,r)	  r = (x != y)
#define OP_FLOAT_LE(x,y,r)	  r = (x <= y)
#define OP_FLOAT_GT(x,y,r)	  r = (x >  y)
#define OP_FLOAT_LT(x,y,r)	  r = (x <  y)
#define OP_FLOAT_GE(x,y,r)	  r = (x >= y)

#define OP_FLOAT_CMP(x,y,r) \
	r = ((x > y) - (x < y))

/* addition, subtraction */

#define OP_FLOAT_ADD(x,y,r)     r = x + y
#define OP_FLOAT_SUB(x,y,r)     r = x - y
#define OP_FLOAT_MUL(x,y,r)     r = x * y
#define OP_FLOAT_TRUEDIV(x,y,r) r = x / y

/*** conversions ***/

#define OP_CAST_FLOAT_TO_INT(x,r)    r = (Signed)(x)
#define OP_CAST_FLOAT_TO_UINT(x,r)   r = (Unsigned)(x)
#define OP_CAST_INT_TO_FLOAT(x,r)    r = (double)(x)
#define OP_CAST_UINT_TO_FLOAT(x,r)   r = (double)(x)
#define OP_CAST_LONGLONG_TO_FLOAT(x,r) r = rpy_cast_longlong_to_float(x)
#define OP_CAST_ULONGLONG_TO_FLOAT(x,r) r = rpy_cast_ulonglong_to_float(x)
#define OP_CAST_BOOL_TO_FLOAT(x,r)   r = (double)(x)

#ifdef _WIN32
/* The purpose of these two functions is to work around a MSVC bug.
   The expression '(double)131146795334735160LL' will lead to bogus
   rounding, but apparently everything is fine if we write instead
   rpy_cast_longlong_to_float(131146795334735160LL).  Tested with 
   MSVC 2008.  Note that even if the two functions contain just
   'return (double)x;' it seems to work on MSVC 2008, but I don't
   trust that there are no other corner cases.
   http://stackoverflow.com/questions/33829101/incorrect-double-to-long-conversion
*/
static _inline double rpy_cast_longlong_to_float(long long x)
{
    unsigned int lo = (unsigned int)x;
    double result = lo;
    result += ((int)(x >> 32)) * 4294967296.0;
    return result;
}
static _inline double rpy_cast_ulonglong_to_float(unsigned long long x)
{
    unsigned int lo = (unsigned int)x;
    double result = lo;
    result += ((unsigned int)(x >> 32)) * 4294967296.0;
    return result;
}
#else
#  define rpy_cast_longlong_to_float(x) ((double)(x))
#  define rpy_cast_ulonglong_to_float(x) ((double)(x))
#endif

#ifdef HAVE_LONG_LONG
#define OP_CAST_FLOAT_TO_LONGLONG(x,r) r = (long long)(x)
#define OP_CAST_FLOAT_TO_ULONGLONG(x,r) r = (unsigned long long)(x)
#define OP_CONVERT_FLOAT_BYTES_TO_LONGLONG(x,r) { double _f = x; memcpy(&r, &_f, sizeof(double)); }
#define OP_CONVERT_LONGLONG_BYTES_TO_FLOAT(x,r) { long long _f = x; memcpy(&r, &_f, sizeof(long long)); }
#endif

