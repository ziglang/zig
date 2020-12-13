// Code ported from musl libc 8f12c4e110acb3bbbdc8abfb3a552c3ced718039
// and then modified to use softfloat and to assume f128 for everything

#include "parse_f128.h"
#include "softfloat.h"
#include "zigendian.h"
#include <stddef.h>
#include <sys/types.h>
#include <errno.h>
#include <limits.h>
#include <string.h>
#include <math.h>

#define shcnt(f) ((f)->shcnt + ((f)->rpos - (f)->buf))
#define shlim(f, lim) __shlim((f), (lim))
#define shgetc(f) (((f)->rpos != (f)->shend) ? *(f)->rpos++ : __shgetc(f))
#define shunget(f) ((f)->shlim>=0 ? (void)(f)->rpos-- : (void)0)

#define sh_fromstring(f, s) \
    ((f)->buf = (f)->rpos = (void *)(s), (f)->rend = (void*)-1)

#define LD_B1B_DIG 4
#define LD_B1B_MAX 10384593, 717069655, 257060992, 658440191
#define KMAX 2048

#define MASK (KMAX-1)

#define CONCAT2(x,y) x ## y
#define CONCAT(x,y) CONCAT2(x,y)

#define F_PERM 1
#define F_NORD 4
#define F_NOWR 8
#define F_EOF 16
#define F_ERR 32
#define F_SVB 64
#define F_APP 128

#define EOF (-1)

#define LDBL_MANT_DIG 113
#define LDBL_MIN_EXP (-16381)
#define LDBL_MAX_EXP 16384

#define LDBL_DIG 33
#define LDBL_MIN_10_EXP (-4931)
#define LDBL_MAX_10_EXP 4932

#define DECIMAL_DIG 36

#if defined(ZIG_BYTE_ORDER) && ZIG_BYTE_ORDER == ZIG_LITTLE_ENDIAN
union ldshape {
    float128_t f;
    struct {
        uint64_t lo;
        uint32_t mid;
        uint16_t top;
        uint16_t se;
    } i;
    struct {
        uint64_t lo;
        uint64_t hi;
    } i2;
};
#elif defined(ZIG_BYTE_ORDER) && ZIG_BYTE_ORDER == ZIG_BIG_ENDIAN
union ldshape {
    float128_t f;
    struct {
        uint16_t se;
        uint16_t top;
        uint32_t mid;
        uint64_t lo;
    } i;
    struct {
        uint64_t hi;
        uint64_t lo;
    } i2;
};
#else
#error Unsupported endian
#endif

struct MuslFILE {
    unsigned flags;
    unsigned char *rpos, *rend;
    int (*close)(struct MuslFILE *);
    unsigned char *wend, *wpos;
    unsigned char *mustbezero_1;
    unsigned char *wbase;
    size_t (*read)(struct MuslFILE *, unsigned char *, size_t);
    size_t (*write)(struct MuslFILE *, const unsigned char *, size_t);
    off_t (*seek)(struct MuslFILE *, off_t, int);
    unsigned char *buf;
    size_t buf_size;
    struct MuslFILE *prev, *next;
    int fd;
    int pipe_pid;
    long lockcount;
    int mode;
    volatile int lock;
    int lbf;
    void *cookie;
    off_t off;
    char *getln_buf;
    void *mustbezero_2;
    unsigned char *shend;
    off_t shlim, shcnt;
    struct MuslFILE *prev_locked, *next_locked;
    struct __locale_struct *locale;
};

static void __shlim(struct MuslFILE *f, off_t lim)
{
    f->shlim = lim;
    f->shcnt = f->buf - f->rpos;
    /* If lim is nonzero, rend must be a valid pointer. */
    if (lim && f->rend - f->rpos > lim)
        f->shend = f->rpos + lim;
    else
        f->shend = f->rend;
}

static int __toread(struct MuslFILE *f)
{
    f->mode |= f->mode-1;
    if (f->wpos != f->wbase) f->write(f, 0, 0);
    f->wpos = f->wbase = f->wend = 0;
    if (f->flags & F_NORD) {
        f->flags |= F_ERR;
        return EOF;
    }
    f->rpos = f->rend = f->buf + f->buf_size;
    return (f->flags & F_EOF) ? EOF : 0;
}

static int __uflow(struct MuslFILE *f)
{
    unsigned char c;
    if (!__toread(f) && f->read(f, &c, 1)==1) return c;
    return EOF;
}

static int __shgetc(struct MuslFILE *f)
{
    int c;
    off_t cnt = shcnt(f);
    if ((f->shlim && cnt >= f->shlim) || (c=__uflow(f)) < 0) {
        f->shcnt = f->buf - f->rpos + cnt;
        f->shend = f->rpos;
        f->shlim = -1;
        return EOF;
    }
    cnt++;
    if (f->shlim && f->rend - f->rpos > f->shlim - cnt)
        f->shend = f->rpos + (f->shlim - cnt);
    else
        f->shend = f->rend;
    f->shcnt = f->buf - f->rpos + cnt;
    if (f->rpos[-1] != c) f->rpos[-1] = c;
    return c;
}

static long long scanexp(struct MuslFILE *f, int pok)
{
    int c;
    int x;
    long long y;
    int neg = 0;

    c = shgetc(f);
    if (c=='+' || c=='-') {
        neg = (c=='-');
        c = shgetc(f);
        if (c-'0'>=10U && pok) shunget(f);
    }
    if (c-'0'>=10U && c!='_') {
        shunget(f);
        return LLONG_MIN;
    }
    for (x=0; ; c = shgetc(f)) {
        if (c=='_') {
            continue;
        } else if (c-'0'<10U && x<INT_MAX/10) {
            x = 10*x + c-'0';
        } else {
            break;
        }
    }
    for (y=x; ; c = shgetc(f)) {
        if (c=='_') {
            continue;
        } else if (c-'0'<10U && y<LLONG_MAX/100) {
            y = 10*y + c-'0';
        } else {
            break;
        }
    }
    for (; c-'0'<10U || c=='_'; c = shgetc(f));
    shunget(f);
    return neg ? -y : y;
}

static float128_t copysignf128(float128_t x, float128_t y)
{
    union ldshape ux = {x}, uy = {y};
    ux.i.se &= 0x7fff;
    ux.i.se |= uy.i.se & 0x8000;
    return ux.f;
}

static void mul_eq_f128_float(float128_t *x, float op_float) {
    //x *= 0x1p120f;
    float32_t op_f32;
    memcpy(&op_f32, &op_float, sizeof(float));
    float128_t op_f128;
    f32_to_f128M(op_f32, &op_f128);
    float128_t new_value;
    f128M_mul(x, &op_f128, &new_value);
    *x = new_value;
}

static float128_t dbl_to_f128(double x) {
    float64_t x_f64;
    memcpy(&x_f64, &x, sizeof(double));
    float128_t result;
    f64_to_f128M(x_f64, &result);
    return result;
}

static float128_t fmodf128(float128_t x, float128_t y)
{
    union ldshape ux = {x}, uy = {y};
    int ex = ux.i.se & 0x7fff;
    int ey = uy.i.se & 0x7fff;
    int sx = ux.i.se & 0x8000;

    float128_t zero;
    ui32_to_f128M(0, &zero);
    // if (y == 0 || isnan(y) || ex == 0x7fff)
    if (f128M_eq(&y, &zero) || f128M_isSignalingNaN(&y) || ex == 0x7fff) {
        //return (x*y)/(x*y);
        float128_t x_times_y;
        f128M_mul(&x, &y, &x_times_y);
        float128_t result;
        f128M_div(&x_times_y, &x_times_y, &result);
        return result;
    }
    ux.i.se = ex;
    uy.i.se = ey;
    //if (ux.f <= uy.f) {
    if (f128M_le(&ux.f, &uy.f)) {
        //if (ux.f == uy.f) {
        if (f128M_eq(&ux.f, &uy.f)) {
            //return 0*x;
            float128_t result;
            f128M_mul(&zero, &x, &result);
            return result;
        }
        return x;
    }

    /* normalize x and y */
    if (!ex) {
        //ux.f *= 0x1p120f;
        mul_eq_f128_float(&ux.f, 0x1p120f);

        ex = ux.i.se - 120;
    }
    if (!ey) {
        //uy.f *= 0x1p120f;
        mul_eq_f128_float(&uy.f, 0x1p120f);

        ey = uy.i.se - 120;
    }

    /* x mod y */
    uint64_t hi, lo, xhi, xlo, yhi, ylo;
    xhi = (ux.i2.hi & -1ULL>>16) | 1ULL<<48;
    yhi = (uy.i2.hi & -1ULL>>16) | 1ULL<<48;
    xlo = ux.i2.lo;
    ylo = uy.i2.lo;
    for (; ex > ey; ex--) {
        hi = xhi - yhi;
        lo = xlo - ylo;
        if (xlo < ylo)
            hi -= 1;
        if (hi >> 63 == 0) {
            if ((hi|lo) == 0) {
                //return 0*x;
                float128_t result;
                f128M_mul(&zero, &x, &result);
                return result;
            }
            xhi = 2*hi + (lo>>63);
            xlo = 2*lo;
        } else {
            xhi = 2*xhi + (xlo>>63);
            xlo = 2*xlo;
        }
    }
    hi = xhi - yhi;
    lo = xlo - ylo;
    if (xlo < ylo)
        hi -= 1;
    if (hi >> 63 == 0) {
        if ((hi|lo) == 0) {
            //return 0*x;
            float128_t result;
            f128M_mul(&zero, &x, &result);
            return result;
        }
        xhi = hi;
        xlo = lo;
    }
    for (; xhi >> 48 == 0; xhi = 2*xhi + (xlo>>63), xlo = 2*xlo, ex--);
    ux.i2.hi = xhi;
    ux.i2.lo = xlo;

    /* scale result */
    if (ex <= 0) {
        ux.i.se = (ex+120)|sx;
        //ux.f *= 0x1p-120f;
        mul_eq_f128_float(&ux.f, 0x1p-120f);
    } else
        ux.i.se = ex|sx;
    return ux.f;
}

static float128_t int_mul_f128_cast_u32(int sign, uint32_t x0) {
    float128_t x0_f128;
    ui32_to_f128M(x0, &x0_f128);
    float128_t sign_f128;
    i32_to_f128M(sign, &sign_f128);
    float128_t result;
    f128M_mul(&sign_f128, &x0_f128, &result);
    return result;
}

static float128_t triple_divide(int sign, uint32_t x0, int p10s) {
    float128_t part1 = int_mul_f128_cast_u32(sign, x0);
    float128_t p10s_f128;
    i32_to_f128M(p10s, &p10s_f128);
    float128_t result;
    f128M_div(&part1, &p10s_f128, &result);
    return result;
}

static float128_t triple_multiply(int sign, uint32_t x0, int p10s) {
    float128_t part1 = int_mul_f128_cast_u32(sign, x0);
    float128_t p10s_f128;
    i32_to_f128M(p10s, &p10s_f128);
    float128_t result;
    f128M_mul(&part1, &p10s_f128, &result);
    return result;
}

static void mul_eq_f128_int(float128_t *y, int sign) {
    float128_t sign_f128;
    i32_to_f128M(sign, &sign_f128);
    float128_t new_value;
    f128M_mul(y, &sign_f128, &new_value);
    *y = new_value;
}

static float128_t make_f128(uint64_t hi, uint64_t lo) {
    union ldshape ux;
    ux.i2.hi = hi;
    ux.i2.lo = lo;
    return ux.f;
}

static void mul_eq_f128_f128(float128_t *a, float128_t b) {
    float128_t new_value;
    f128M_mul(a, &b, &new_value);
    *a = new_value;
}

static void add_eq_f128_dbl(float128_t *a, double b) {
    float64_t b_f64;
    memcpy(&b_f64, &b, sizeof(double));

    float128_t b_f128;
    f64_to_f128M(b_f64, &b_f128);

    float128_t new_value;
    f128M_add(a, &b_f128, &new_value);
    *a = new_value;
}

static float128_t scalbnf128(float128_t x, int n)
{
    union ldshape u;

    if (n > 16383) {
        //x *= 0x1p16383q;
        mul_eq_f128_f128(&x, make_f128(0x7ffe000000000000, 0x0000000000000000));
        n -= 16383;
        if (n > 16383) {
            //x *= 0x1p16383q;
            mul_eq_f128_f128(&x, make_f128(0x7ffe000000000000, 0x0000000000000000));
            n -= 16383;
            if (n > 16383)
                n = 16383;
        }
    } else if (n < -16382) {
        //x *= 0x1p-16382q * 0x1p113q;
        {
            float128_t mul_result;
            float128_t a = make_f128(0x0001000000000000, 0x0000000000000000);
            float128_t b = make_f128(0x4070000000000000, 0x0000000000000000);
            f128M_mul(&a, &b, &mul_result);
            mul_eq_f128_f128(&x, mul_result);
        }
        n += 16382 - 113;
        if (n < -16382) {
            //x *= 0x1p-16382q * 0x1p113q;
            {
                float128_t mul_result;
                float128_t a = make_f128(0x0001000000000000, 0x0000000000000000);
                float128_t b = make_f128(0x4070000000000000, 0x0000000000000000);
                f128M_mul(&a, &b, &mul_result);
                mul_eq_f128_f128(&x, mul_result);
            }
            n += 16382 - 113;
            if (n < -16382)
                n = -16382;
        }
    }
    //u.f = 1.0;
    ui32_to_f128M(1, &u.f);
    u.i.se = 0x3fff + n;
    mul_eq_f128_f128(&x, u.f);
    return x;
}

static float128_t fabsf128(float128_t x)
{
    union ldshape u = {x};

    u.i.se &= 0x7fff;
    return u.f;
}

static float128_t decfloat(struct MuslFILE *f, int c, int bits, int emin, int sign, int pok)
{
    uint32_t x[KMAX];
    static const uint32_t th[] = { LD_B1B_MAX };
    int i, j, k, a, z;
    long long lrp=0, dc=0;
    long long e10=0;
    int lnz = 0;
    int gotdig = 0, gotrad = 0;
    int rp;
    int e2;
    int emax = -emin-bits+3;
    int denormal = 0;
    float128_t y;
    float128_t zero;
    ui32_to_f128M(0, &zero);
    float128_t frac=zero;
    float128_t bias=zero;
    static const int p10s[] = { 10, 100, 1000, 10000,
        100000, 1000000, 10000000, 100000000 };

    j=0;
    k=0;

    /* Don't let leading zeros/underscores consume buffer space */
    for (; ; c = shgetc(f)) {
        if (c=='_') {
            continue;
        } else if (c=='0') {
            gotdig=1;
        } else {
            break;
        }
    }

    if (c=='.') {
        gotrad = 1;
        for (c = shgetc(f); ; c = shgetc(f)) {
            if (c == '_') {
                continue;
            } else if (c=='0') {
                gotdig=1;
                lrp--;
            } else {
                break;
            }
        }
    }

    x[0] = 0;
    for (; c-'0'<10U || c=='.' || c=='_'; c = shgetc(f)) {
        if (c == '_') {
            continue;
        } else if (c == '.') {
            if (gotrad) break;
            gotrad = 1;
            lrp = dc;
        } else if (k < KMAX-3) {
            dc++;
            if (c!='0') lnz = dc;
            if (j) x[k] = x[k]*10 + c-'0';
            else x[k] = c-'0';
            if (++j==9) {
                k++;
                j=0;
            }
            gotdig=1;
        } else {
            dc++;
            if (c!='0') {
                lnz = (KMAX-4)*9;
                x[KMAX-4] |= 1;
            }
        }
    }
    if (!gotrad) lrp=dc;

    if (gotdig && (c|32)=='e') {
        e10 = scanexp(f, pok);
        if (e10 == LLONG_MIN) {
            if (pok) {
                shunget(f);
            } else {
                shlim(f, 0);
                return zero;
            }
            e10 = 0;
        }
        lrp += e10;
    } else if (c>=0) {
        shunget(f);
    }
    if (!gotdig) {
        errno = EINVAL;
        shlim(f, 0);
        return zero;
    }

    /* Handle zero specially to avoid nasty special cases later */
    if (!x[0]) {
        //return sign * 0.0;
        return dbl_to_f128(sign * 0.0);
    }

    /* Optimize small integers (w/no exponent) and over/under-flow */
    if (lrp==dc && dc<10 && (bits>30 || x[0]>>bits==0)) {
        //return sign * (float128_t)x[0];
        float128_t sign_f128;
        i32_to_f128M(sign, &sign_f128);
        float128_t x0_f128;
        ui32_to_f128M(x[0], &x0_f128);
        float128_t result;
        f128M_mul(&sign_f128, &x0_f128, &result);
        return result;
    }
    if (lrp > -emin/2) {
        errno = ERANGE;
        //return sign * LDBL_MAX * LDBL_MAX;
        return zero;
    }
    if (lrp < emin-2*LDBL_MANT_DIG) {
        errno = ERANGE;
        //return sign * LDBL_MIN * LDBL_MIN;
        return zero;
    }

    /* Align incomplete final B1B digit */
    if (j) {
        for (; j<9; j++) x[k]*=10;
        k++;
        j=0;
    }

    a = 0;
    z = k;
    e2 = 0;
    rp = lrp;

    /* Optimize small to mid-size integers (even in exp. notation) */
    if (lnz<9 && lnz<=rp && rp < 18) {
        if (rp == 9) {
            //return sign * (float128_t)(x[0]);
            return int_mul_f128_cast_u32(sign, x[0]);
        }
        if (rp < 9) {
            //return sign * (float128_t)(x[0]) / p10s[8-rp];
            return triple_divide(sign, x[0], p10s[8-rp]);
        }
        int bitlim = bits-3*(int)(rp-9);
        if (bitlim>30 || x[0]>>bitlim==0)
            //return sign * (float128_t)(x[0]) * p10s[rp-10];
            return triple_multiply(sign, x[0], p10s[rp-10]);
    }

    /* Drop trailing zeros */
    for (; !x[z-1]; z--);

    /* Align radix point to B1B digit boundary */
    if (rp % 9) {
        int rpm9 = rp>=0 ? rp%9 : rp%9+9;
        int p10 = p10s[8-rpm9];
        uint32_t carry = 0;
        for (k=a; k!=z; k++) {
            uint32_t tmp = x[k] % p10;
            x[k] = x[k]/p10 + carry;
            carry = 1000000000/p10 * tmp;
            if (k==a && !x[k]) {
                a = (a+1 & MASK);
                rp -= 9;
            }
        }
        if (carry) x[z++] = carry;
        rp += 9-rpm9;
    }

    /* Upscale until desired number of bits are left of radix point */
    while (rp < 9*LD_B1B_DIG || (rp == 9*LD_B1B_DIG && x[a]<th[0])) {
        uint32_t carry = 0;
        e2 -= 29;
        for (k=(z-1 & MASK); ; k=(k-1 & MASK)) {
            uint64_t tmp = ((uint64_t)x[k] << 29) + carry;
            if (tmp > 1000000000) {
                carry = tmp / 1000000000;
                x[k] = tmp % 1000000000;
            } else {
                carry = 0;
                x[k] = tmp;
            }
            if (k==(z-1 & MASK) && k!=a && !x[k]) z = k;
            if (k==a) break;
        }
        if (carry) {
            rp += 9;
            a = (a-1 & MASK);
            if (a == z) {
                z = (z-1 & MASK);
                x[z-1 & MASK] |= x[z];
            }
            x[a] = carry;
        }
    }

    /* Downscale until exactly number of bits are left of radix point */
    for (;;) {
        uint32_t carry = 0;
        int sh = 1;
        for (i=0; i<LD_B1B_DIG; i++) {
            k = (a+i & MASK);
            if (k == z || x[k] < th[i]) {
                i=LD_B1B_DIG;
                break;
            }
            if (x[a+i & MASK] > th[i]) break;
        }
        if (i==LD_B1B_DIG && rp==9*LD_B1B_DIG) break;
        /* FIXME: find a way to compute optimal sh */
        if (rp > 9+9*LD_B1B_DIG) sh = 9;
        e2 += sh;
        for (k=a; k!=z; k=(k+1 & MASK)) {
            uint32_t tmp = x[k] & (1<<sh)-1;
            x[k] = (x[k]>>sh) + carry;
            carry = (1000000000>>sh) * tmp;
            if (k==a && !x[k]) {
                a = (a+1 & MASK);
                i--;
                rp -= 9;
            }
        }
        if (carry) {
            if ((z+1 & MASK) != a) {
                x[z] = carry;
                z = (z+1 & MASK);
            } else x[z-1 & MASK] |= 1;
        }
    }

    /* Assemble desired bits into floating point variable */
    for (y=zero,i=0; i<LD_B1B_DIG; i++) {
        if ((a+i & MASK)==z) x[(z=(z+1 & MASK))-1] = 0;
        //y = 1000000000.0L * y + x[a+i & MASK];
        float128_t const_f128;
        ui64_to_f128M(1000000000, &const_f128);
        float128_t mul_y;
        f128M_mul(&const_f128, &y, &mul_y);
        float128_t x_f128;
        ui32_to_f128M(x[a+i & MASK], &x_f128);
        f128M_add(&mul_y, &x_f128, &y);
    }

    //y *= sign;
    mul_eq_f128_int(&y, sign);

    /* Limit precision for denormal results */
    if (bits > LDBL_MANT_DIG+e2-emin) {
        bits = LDBL_MANT_DIG+e2-emin;
        if (bits<0) bits=0;
        denormal = 1;
    }

    /* Calculate bias term to force rounding, move out lower bits */
    if (bits < LDBL_MANT_DIG) {
        bias = copysignf128(dbl_to_f128(scalbn(1, 2*LDBL_MANT_DIG-bits-1)), y);
        frac = fmodf128(y, dbl_to_f128(scalbn(1, LDBL_MANT_DIG-bits)));
        //y -= frac;
        {
            float128_t new_value;
            f128M_sub(&y, &frac, &new_value);
            y = new_value;
        }
        //y += bias;
        {
            float128_t new_value;
            f128M_add(&y, &frac, &new_value);
            y = new_value;
        }
    }

    /* Process tail of decimal input so it can affect rounding */
    if ((a+i & MASK) != z) {
        uint32_t t = x[a+i & MASK];
        if (t < 500000000 && (t || (a+i+1 & MASK) != z)) {
            //frac += 0.25*sign;
            add_eq_f128_dbl(&frac, 0.25*sign);
        } else if (t > 500000000) {
            //frac += 0.75*sign;
            add_eq_f128_dbl(&frac, 0.75*sign);
        } else if (t == 500000000) {
            if ((a+i+1 & MASK) == z) {
                //frac += 0.5*sign;
                add_eq_f128_dbl(&frac, 0.5*sign);
            } else {
                //frac += 0.75*sign;
                add_eq_f128_dbl(&frac, 0.75*sign);
            }
        }
        //if (LDBL_MANT_DIG-bits >= 2 && !fmodf128(frac, 1))
        if (LDBL_MANT_DIG-bits >= 2) {
            float128_t one;
            ui32_to_f128M(1, &one);
            float128_t mod_result = fmodf128(frac, one);
            if (f128M_eq(&mod_result, &zero)) {
                //frac++;
                add_eq_f128_dbl(&frac, 1.0);
            }
        }
    }

    //y += frac;
    {
        float128_t new_value;
        f128M_add(&y, &frac, &new_value);
        y = new_value;
    }
    //y -= bias;
    {
        float128_t new_value;
        f128M_sub(&y, &bias, &new_value);
        y = new_value;
    }

    if ((e2+LDBL_MANT_DIG & INT_MAX) > emax-5) {
        //if (fabsf128(y) >= 0x1p113)
        float128_t abs_y = fabsf128(y);
        float128_t mant_f128 = make_f128(0x4070000000000000, 0x0000000000000000);
        if (!f128M_lt(&abs_y, &mant_f128)) {
            if (denormal && bits==LDBL_MANT_DIG+e2-emin)
                denormal = 0;
            //y *= 0.5;
            {
                float128_t point_5 = dbl_to_f128(0.5);
                float128_t new_value;
                f128M_mul(&y, &point_5, &new_value);
                y = new_value;
            }

            e2++;
        }
        if (e2+LDBL_MANT_DIG>emax || (denormal && !f128M_eq(&frac, &zero)))
            errno = ERANGE;
    }

    return scalbnf128(y, e2);
}

static float128_t hexfloat(struct MuslFILE *f, int bits, int emin, int sign, int pok)
{
    float128_t zero;
    ui32_to_f128M(0, &zero);
    float128_t one;
    ui32_to_f128M(1, &one);
    float128_t sixteen;
    ui32_to_f128M(16, &sixteen);
    float128_t point_5 = dbl_to_f128(0.5);

    uint32_t x = 0;
    float128_t y = zero;
    float128_t scale = one;
    float128_t bias = zero;
    int gottail = 0, gotrad = 0, gotdig = 0;
    long long rp = 0;
    long long dc = 0;
    long long e2 = 0;
    int d;
    int c;

    c = shgetc(f);

    /* Skip leading zeros/underscores */
    for (; c=='0' || c=='_'; c = shgetc(f)) gotdig = 1;

    if (c=='.') {
        gotrad = 1;
        c = shgetc(f);
        /* Count zeros after the radix point before significand */
        for (rp=0; ; c = shgetc(f)) {
            if (c == '_') {
                continue;
            } else if (c == '0') {
                gotdig = 1;
                rp--;
            } else {
                break;
            }
        }
    }

    for (; c-'0'<10U || (c|32)-'a'<6U || c=='.' || c=='_'; c = shgetc(f)) {
        if (c=='_') {
            continue;
        } else if (c=='.') {
            if (gotrad) break;
            rp = dc;
            gotrad = 1;
        } else {
            gotdig = 1;
            if (c > '9') d = (c|32)+10-'a';
            else d = c-'0';
            if (dc<8) {
                x = x*16 + d;
            } else if (dc < LDBL_MANT_DIG/4+1) {
                //y += d*(scale/=16);
                {
                    float128_t divided;
                    f128M_div(&scale, &sixteen, &divided);
                    scale = divided;
                    float128_t d_f128;
                    i32_to_f128M(d, &d_f128);
                    float128_t add_op;
                    f128M_mul(&d_f128, &scale, &add_op);
                    float128_t new_y;
                    f128M_add(&y, &add_op, &new_y);
                    y = new_y;
                }
            } else if (d && !gottail) {
                //y += 0.5*scale;
                {
                    float128_t add_op;
                    f128M_mul(&point_5, &scale, &add_op);
                    float128_t new_y;
                    f128M_add(&y, &add_op, &new_y);
                    y = new_y;
                }
                gottail = 1;
            }
            dc++;
        }
    }
    if (!gotdig) {
        shunget(f);
        if (pok) {
            shunget(f);
            if (gotrad) shunget(f);
        } else {
            shlim(f, 0);
        }
        //return sign * 0.0;
        return dbl_to_f128(sign * 0.0);
    }
    if (!gotrad) rp = dc;
    while (dc<8) x *= 16, dc++;
    if ((c|32)=='p') {
        e2 = scanexp(f, pok);
        if (e2 == LLONG_MIN) {
            if (pok) {
                shunget(f);
            } else {
                shlim(f, 0);
                return zero;
            }
            e2 = 0;
        }
    } else {
        shunget(f);
    }
    e2 += 4*rp - 32;

    if (!x) {
        //return sign * 0.0;
        return dbl_to_f128(sign * 0.0);
    }
    if (e2 > -emin) {
        errno = ERANGE;
        //return sign * LDBL_MAX * LDBL_MAX;
        return zero;
    }
    if (e2 < emin-2*LDBL_MANT_DIG) {
        errno = ERANGE;
        //return sign * LDBL_MIN * LDBL_MIN;
        return zero;
    }

    while (x < 0x80000000) {
        //if (y>=0.5)
        if (!f128M_lt(&y, &point_5)) {
            x += x + 1;
            //y += y - 1;
            {
                float128_t minus_one;
                f128M_sub(&y, &one, &minus_one);
                float128_t new_y;
                f128M_add(&y, &minus_one, &new_y);
                y = new_y;
            }
        } else {
            x += x;
            //y += y;
            {
                float128_t new_y;
                f128M_add(&y, &y, &new_y);
                y = new_y;
            }
        }
        e2--;
    }

    if (bits > 32+e2-emin) {
        bits = 32+e2-emin;
        if (bits<0) bits=0;
    }

    if (bits < LDBL_MANT_DIG) {
        float128_t sign_f128;
        i32_to_f128M(sign, &sign_f128);
        bias = copysignf128(dbl_to_f128(scalbn(1, 32+LDBL_MANT_DIG-bits-1)), sign_f128);
    }

    //if (bits<32 && y && !(x&1)) x++, y=0;
    if (bits<32 && !f128M_eq(&y, &zero) && !(x&1)) x++, y=zero;

    //y = bias + sign*(float128_t)x + sign*y;
    {
        float128_t x_f128;
        ui32_to_f128M(x, &x_f128);
        float128_t sign_f128;
        i32_to_f128M(sign, &sign_f128);
        float128_t sign_mul_x;
        f128M_mul(&sign_f128, &x_f128, &sign_mul_x);
        float128_t sign_mul_y;
        f128M_mul(&sign_f128, &y, &sign_mul_y);
        float128_t bias_op;
        f128M_add(&bias, &sign_mul_x, &bias_op);
        float128_t new_y;
        f128M_add(&bias_op, &sign_mul_y, &new_y);
        y = new_y;
    }
    //y -= bias;
    {
        float128_t new_y;
        f128M_sub(&y, &bias, &new_y);
        y = new_y;
    }

    if (f128M_eq(&y, &zero)) errno = ERANGE;

    return scalbnf128(y, e2);
}

static int isspace(int c)
{
    return c == ' ' || (unsigned)c-'\t' < 5;
}

static inline float128_t makeInf128() {
    union ldshape ux;
    ux.i2.hi = 0x7fff000000000000UL;
    ux.i2.lo = 0x0UL;
    return ux.f;
}

static inline float128_t makeNaN128() {
    uint64_t rand = 0UL;
    union ldshape ux;
    ux.i2.hi = 0x7fff000000000000UL | (rand & 0xffffffffffffUL);
    ux.i2.lo = 0x0UL;
    return ux.f;
}

float128_t __floatscan(struct MuslFILE *f, int prec, int pok)
{
    int sign = 1;
    size_t i;
    int bits = LDBL_MANT_DIG;
    int emin = LDBL_MIN_EXP-bits;
    int c;

    while (isspace((c=shgetc(f))));

    if (c=='+' || c=='-') {
        sign -= 2*(c=='-');
        c = shgetc(f);
    }

    for (i=0; i<8 && (c|32)=="infinity"[i]; i++)
        if (i<7) c = shgetc(f);
    if (i==3 || i==8 || (i>3 && pok)) {
        if (i!=8) {
            shunget(f);
            if (pok) for (; i>3; i--) shunget(f);
        }
        //return sign * INFINITY;
        float128_t sign_f128;
        i32_to_f128M(sign, &sign_f128);
        float128_t infinity_f128 = makeInf128();
        float128_t result;
        f128M_mul(&sign_f128, &infinity_f128, &result);
        return result;
    }
    if (!i) for (i=0; i<3 && (c|32)=="nan"[i]; i++)
        if (i<2) c = shgetc(f);
    if (i==3) {
        if (shgetc(f) != '(') {
            shunget(f);
            return makeNaN128();
        }
        for (i=1; ; i++) {
            c = shgetc(f);
            if (c-'0'<10U || c-'A'<26U || c-'a'<26U || c=='_')
                continue;
            if (c==')') return makeNaN128();
            shunget(f);
            if (!pok) {
                errno = EINVAL;
                shlim(f, 0);
                float128_t zero;
                ui32_to_f128M(0, &zero);
                return zero;
            }
            while (i--) shunget(f);
            return makeNaN128();
        }
        return makeNaN128();
    }

    if (i) {
        shunget(f);
        errno = EINVAL;
        shlim(f, 0);
        float128_t zero;
        ui32_to_f128M(0, &zero);
        return zero;
    }

    if (c=='0') {
        c = shgetc(f);
        if ((c|32) == 'x')
            return hexfloat(f, bits, emin, sign, pok);
        shunget(f);
        c = '0';
    }

    return decfloat(f, c, bits, emin, sign, pok);
}

float128_t parse_f128(const char *s, char **p) {
    struct MuslFILE f;
    sh_fromstring(&f, s);
    shlim(&f, 0);
    float128_t y = __floatscan(&f, 2, 1);
    off_t cnt = shcnt(&f);
    if (p) *p = cnt ? (char *)s + cnt : (char *)s;
    return y;
}
