import os
import sys

from cffi import FFI


ffi = FFI()
ffi.cdef("""
typedef size_t mpd_size_t; /* unsigned size type */
typedef ssize_t mpd_ssize_t; /* signed size type */
typedef size_t mpd_uint_t;
#define MPD_SIZE_MAX ...
#define MPD_SSIZE_MIN ...
#define MPD_SSIZE_MAX ...

const char *mpd_version(void);
void mpd_free(void *ptr);

typedef struct mpd_context_t {
    mpd_ssize_t prec;   /* precision */
    mpd_ssize_t emax;   /* max positive exp */
    mpd_ssize_t emin;   /* min negative exp */
    uint32_t traps;     /* status events that should be trapped */
    uint32_t status;    /* status flags */
    uint32_t newtrap;   /* set by mpd_addstatus_raise() */
    int      round;     /* rounding mode */
    int      clamp;     /* clamp mode */
    int      allcr;     /* all functions correctly rounded */
} mpd_context_t;

enum {
    MPD_ROUND_UP,          /* round away from 0               */
    MPD_ROUND_DOWN,        /* round toward 0 (truncate)       */
    MPD_ROUND_CEILING,     /* round toward +infinity          */
    MPD_ROUND_FLOOR,       /* round toward -infinity          */
    MPD_ROUND_HALF_UP,     /* 0.5 is rounded up               */
    MPD_ROUND_HALF_DOWN,   /* 0.5 is rounded down             */
    MPD_ROUND_HALF_EVEN,   /* 0.5 is rounded to even          */
    MPD_ROUND_05UP,        /* round zero or five away from 0  */
    MPD_ROUND_TRUNC,       /* truncate, but set infinity      */
    MPD_ROUND_GUARD
};

#define MPD_Clamped             ...
#define MPD_Conversion_syntax   ...
#define MPD_Division_by_zero    ...
#define MPD_Division_impossible ...
#define MPD_Division_undefined  ...
#define MPD_Float_operation     ...
#define MPD_Fpu_error           ...
#define MPD_Inexact             ...
#define MPD_Invalid_context     ...
#define MPD_Invalid_operation   ...
#define MPD_Malloc_error        ...
#define MPD_Not_implemented     ...
#define MPD_Overflow            ...
#define MPD_Rounded             ...
#define MPD_Subnormal           ...
#define MPD_Underflow           ...
#define MPD_Max_status          ...
/* Conditions that result in an IEEE 754 exception */
#define MPD_IEEE_Invalid_operation ...
/* Errors that require the result of an operation to be set to NaN */
#define MPD_Errors              ...



void mpd_maxcontext(mpd_context_t *ctx);
int mpd_qsetprec(mpd_context_t *ctx, mpd_ssize_t prec);
int mpd_qsetemax(mpd_context_t *ctx, mpd_ssize_t emax);
int mpd_qsetemin(mpd_context_t *ctx, mpd_ssize_t emin);
int mpd_qsetround(mpd_context_t *ctx, int newround);
int mpd_qsettraps(mpd_context_t *ctx, uint32_t flags);
int mpd_qsetstatus(mpd_context_t *ctx, uint32_t flags);
int mpd_qsetclamp(mpd_context_t *ctx, int c);




typedef struct mpd_t {
    uint8_t flags;
    mpd_ssize_t exp;
    mpd_ssize_t digits;
    mpd_ssize_t len;
    mpd_ssize_t alloc;
    mpd_uint_t *data;
} mpd_t;

#define MPD_POS                 ...
#define MPD_NEG                 ...
#define MPD_INF                 ...
#define MPD_NAN                 ...
#define MPD_SNAN                ...
#define MPD_SPECIAL             ...
#define MPD_STATIC              ...
#define MPD_STATIC_DATA         ...
#define MPD_SHARED_DATA         ...
#define MPD_CONST_DATA          ...
#define MPD_DATAFLAGS           ...


mpd_t *mpd_qnew(void);
void mpd_del(mpd_t *dec);


/* Operations */
void mpd_qabs(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);
void mpd_qplus(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);
void mpd_qminus(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);
void mpd_qsqrt(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);
void mpd_qexp(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);
void mpd_qln(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);
void mpd_qlog10(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);
void mpd_qlogb(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);
void mpd_qinvert(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);

void mpd_qmax(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qmax_mag(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qmin(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qmin_mag(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);

void mpd_qadd(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qsub(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qmul(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qdiv(mpd_t *q, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qdivint(mpd_t *q, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qfma(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_t *c, const mpd_context_t *ctx, uint32_t *status);
void mpd_qrem(mpd_t *r, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qrem_near(mpd_t *r, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qpow(mpd_t *result, const mpd_t *base, const mpd_t *exp, const mpd_context_t *ctx, uint32_t *status);
void mpd_qpowmod(mpd_t *result, const mpd_t *base, const mpd_t *exp, const mpd_t *mod, const mpd_context_t *ctx, uint32_t *status);
int mpd_qcopy_sign(mpd_t *result, const mpd_t *a, const mpd_t *b, uint32_t *status);
int mpd_qcopy_abs(mpd_t *result, const mpd_t *a, uint32_t *status);
int mpd_qcopy_negate(mpd_t *result, const mpd_t *a, uint32_t *status);
void mpd_qdivmod(mpd_t *q, mpd_t *r, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qand(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qor(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qxor(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
int mpd_same_quantum(const mpd_t *a, const mpd_t *b);

void mpd_qround_to_intx(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);
void mpd_qround_to_int(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);
int mpd_qcopy(mpd_t *result, const mpd_t *a,  uint32_t *status);

int mpd_qcmp(const mpd_t *a, const mpd_t *b, uint32_t *status);
int mpd_qcompare(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
int mpd_qcompare_signal(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
int mpd_compare_total(mpd_t *result, const mpd_t *a, const mpd_t *b);
int mpd_compare_total_mag(mpd_t *result, const mpd_t *a, const mpd_t *b);
void mpd_qnext_toward(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qnext_minus(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);
void mpd_qnext_plus(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);
void mpd_qquantize(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);

void mpd_qrotate(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qscaleb(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qshift(mpd_t *result, const mpd_t *a, const mpd_t *b, const mpd_context_t *ctx, uint32_t *status);
void mpd_qreduce(mpd_t *result, const mpd_t *a, const mpd_context_t *ctx, uint32_t *status);

/* Get attributes */
uint8_t mpd_sign(const mpd_t *dec);
int mpd_isnegative(const mpd_t *dec);
int mpd_ispositive(const mpd_t *dec);
int mpd_iszero(const mpd_t *dec);
int mpd_isfinite(const mpd_t *dec);
int mpd_isinfinite(const mpd_t *dec);
int mpd_issigned(const mpd_t *dec);
int mpd_isnan(const mpd_t *dec);
int mpd_issnan(const mpd_t *dec);
int mpd_isspecial(const mpd_t *dec);
int mpd_isqnan(const mpd_t *dec);
int mpd_isnormal(const mpd_t *dec, const mpd_context_t *ctx);
int mpd_issubnormal(const mpd_t *dec, const mpd_context_t *ctx);
mpd_ssize_t mpd_adjexp(const mpd_t *dec);
mpd_ssize_t mpd_etiny(const mpd_context_t *ctx);
mpd_ssize_t mpd_etop(const mpd_context_t *ctx);

mpd_t *mpd_qncopy(const mpd_t *a);

/* Set attributes */
void mpd_set_sign(mpd_t *result, uint8_t sign);
void mpd_set_positive(mpd_t *result);
void mpd_clear_flags(mpd_t *result);
void mpd_seterror(mpd_t *result, uint32_t flags, uint32_t *status);
void mpd_setspecial(mpd_t *dec, uint8_t sign, uint8_t type);

/* I/O */
void mpd_qimport_u16(mpd_t *result, const uint16_t *srcdata, size_t srclen,
                     uint8_t srcsign, uint32_t srcbase,
                     const mpd_context_t *ctx, uint32_t *status);
size_t mpd_qexport_u16(uint16_t **rdata, size_t rlen, uint32_t base,
                       const mpd_t *src, uint32_t *status);
void mpd_qset_string(mpd_t *dec, const char *s, const mpd_context_t *ctx, uint32_t *status);
void mpd_qset_uint(mpd_t *result, mpd_uint_t a, const mpd_context_t *ctx, uint32_t *status);
void mpd_qset_ssize(mpd_t *result, mpd_ssize_t a, const mpd_context_t *ctx, uint32_t *status);
void mpd_qsset_ssize(mpd_t *result, mpd_ssize_t a, const mpd_context_t *ctx, uint32_t *status);
mpd_ssize_t mpd_qget_ssize(const mpd_t *dec, uint32_t *status);
int mpd_lsnprint_signals(char *dest, int nmemb, uint32_t flags, const char *signal_string[]);
#define MPD_MAX_SIGNAL_LIST ...
const char *dec_signal_string[];

void mpd_qfinalize(mpd_t *result, const mpd_context_t *ctx, uint32_t *status);
const char *mpd_class(const mpd_t *a, const mpd_context_t *ctx);

/* format specification */
typedef struct mpd_spec_t {
    mpd_ssize_t min_width; /* minimum field width */
    mpd_ssize_t prec;      /* fraction digits or significant digits */
    char type;             /* conversion specifier */
    char align;            /* alignment */
    char sign;             /* sign printing/alignment */
    char fill[5];          /* fill character */
    const char *dot;       /* decimal point */
    const char *sep;       /* thousands separator */
    const char *grouping;  /* grouping of digits */
} mpd_spec_t;

char *mpd_to_sci(const mpd_t *dec, int fmt);
char *mpd_to_eng(const mpd_t *dec, int fmt);
int mpd_parse_fmt_str(mpd_spec_t *spec, const char *fmt, int caps);
int mpd_validate_lconv(mpd_spec_t *spec);
char *mpd_qformat_spec(const mpd_t *dec, const mpd_spec_t *spec, const mpd_context_t *ctx, uint32_t *status);

""")

_libdir = os.path.join(os.path.dirname(__file__), '_libmpdec')
ffi.set_source('_decimal_cffi',
    """
#ifdef _MSC_VER
  #if defined(_WIN64)
    typedef __int64 LONG_PTR; 
  #else
    typedef long LONG_PTR;
  #endif
  typedef LONG_PTR ssize_t;
#else
  #define HAVE_STDINT_H
#endif
#include "mpdecimal.h"

#define MPD_Float_operation MPD_Not_implemented

const char *dec_signal_string[MPD_NUM_FLAGS] = {
    "Clamped",
    "InvalidOperation",
    "DivisionByZero",
    "InvalidOperation",
    "InvalidOperation",
    "InvalidOperation",
    "Inexact",
    "InvalidOperation",
    "InvalidOperation",
    "InvalidOperation",
    "FloatOperation",
    "Overflow",
    "Rounded",
    "Subnormal",
    "Underflow",
};
""",
    sources=[os.path.join(_libdir, 'mpdecimal.c'),
             os.path.join(_libdir, 'basearith.c'),
             os.path.join(_libdir, 'convolute.c'),
             os.path.join(_libdir, 'constants.c'),
             os.path.join(_libdir, 'context.c'),
             os.path.join(_libdir, 'io.c'),
             os.path.join(_libdir, 'fourstep.c'),
             os.path.join(_libdir, 'sixstep.c'),
             os.path.join(_libdir, 'transpose.c'),
             os.path.join(_libdir, 'difradix2.c'),
             os.path.join(_libdir, 'numbertheory.c'),
             os.path.join(_libdir, 'fnt.c'),
             os.path.join(_libdir, 'crt.c'),
             os.path.join(_libdir, 'memory.c'),
         ],
    include_dirs=[_libdir],
    extra_compile_args=[
        "-DANSI",
        "-DHAVE_INTTYPES_H",
        "-DCONFIG_64" if sys.maxsize > 1 << 32 else "-DCONFIG_32",
    ],
)


if __name__ == '__main__':
    ffi.compile()
