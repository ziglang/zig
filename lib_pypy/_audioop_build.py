from cffi import FFI

ffi = FFI()
ffi.cdef("""
typedef short PyInt16;

int ratecv(char* rv, char* cp, size_t len, int size,
           int nchannels, int inrate, int outrate,
           int* state_d, int* prev_i, int* cur_i,
           int weightA, int weightB);

void tostereo(char* rv, char* cp, size_t len, int size,
              double fac1, double fac2);
void add(char* rv, char* cp1, char* cp2, size_t len1, int size);

/* 2's complement (14-bit range) */
unsigned char
st_14linear2ulaw(PyInt16 pcm_val);
PyInt16 st_ulaw2linear16(unsigned char);

/* 2's complement (13-bit range) */
unsigned char
st_linear2alaw(PyInt16 pcm_val);
PyInt16 st_alaw2linear16(unsigned char);


void lin2adcpm(unsigned char* rv, unsigned char* cp, size_t len,
               size_t size, int* state);
void adcpm2lin(unsigned char* rv, unsigned char* cp, size_t len,
               size_t size, int* state);
""")

# This code is directly copied from CPython file: Modules/audioop.c
_AUDIOOP_C_MODULE = r"""
typedef short PyInt16;
typedef int Py_Int32;

/* Code shamelessly stolen from sox, 12.17.7, g711.c
** (c) Craig Reese, Joe Campbell and Jeff Poskanzer 1989 */

/* From g711.c:
 *
 * December 30, 1994:
 * Functions linear2alaw, linear2ulaw have been updated to correctly
 * convert unquantized 16 bit values.
 * Tables for direct u- to A-law and A- to u-law conversions have been
 * corrected.
 * Borge Lindberg, Center for PersonKommunikation, Aalborg University.
 * bli@cpk.auc.dk
 *
 */
#define BIAS 0x84   /* define the add-in bias for 16 bit samples */
#define CLIP 32635
#define SIGN_BIT        (0x80)          /* Sign bit for a A-law byte. */
#define QUANT_MASK      (0xf)           /* Quantization field mask. */
#define SEG_SHIFT       (4)             /* Left shift for segment number. */
#define SEG_MASK        (0x70)          /* Segment field mask. */

static PyInt16 seg_aend[8] = {0x1F, 0x3F, 0x7F, 0xFF,
                              0x1FF, 0x3FF, 0x7FF, 0xFFF};
static PyInt16 seg_uend[8] = {0x3F, 0x7F, 0xFF, 0x1FF,
                              0x3FF, 0x7FF, 0xFFF, 0x1FFF};

static PyInt16
search(PyInt16 val, PyInt16 *table, int size)
{
    int i;

    for (i = 0; i < size; i++) {
        if (val <= *table++)
            return (i);
    }
    return (size);
}
#define st_ulaw2linear16(uc) (_st_ulaw2linear16[uc])
#define st_alaw2linear16(uc) (_st_alaw2linear16[uc])

static PyInt16 _st_ulaw2linear16[256] = {
    -32124,  -31100,  -30076,  -29052,  -28028,  -27004,  -25980,
    -24956,  -23932,  -22908,  -21884,  -20860,  -19836,  -18812,
    -17788,  -16764,  -15996,  -15484,  -14972,  -14460,  -13948,
    -13436,  -12924,  -12412,  -11900,  -11388,  -10876,  -10364,
     -9852,   -9340,   -8828,   -8316,   -7932,   -7676,   -7420,
     -7164,   -6908,   -6652,   -6396,   -6140,   -5884,   -5628,
     -5372,   -5116,   -4860,   -4604,   -4348,   -4092,   -3900,
     -3772,   -3644,   -3516,   -3388,   -3260,   -3132,   -3004,
     -2876,   -2748,   -2620,   -2492,   -2364,   -2236,   -2108,
     -1980,   -1884,   -1820,   -1756,   -1692,   -1628,   -1564,
     -1500,   -1436,   -1372,   -1308,   -1244,   -1180,   -1116,
     -1052,    -988,    -924,    -876,    -844,    -812,    -780,
      -748,    -716,    -684,    -652,    -620,    -588,    -556,
      -524,    -492,    -460,    -428,    -396,    -372,    -356,
      -340,    -324,    -308,    -292,    -276,    -260,    -244,
      -228,    -212,    -196,    -180,    -164,    -148,    -132,
      -120,    -112,    -104,     -96,     -88,     -80,     -72,
       -64,     -56,     -48,     -40,     -32,     -24,     -16,
    -8,       0,   32124,   31100,   30076,   29052,   28028,
     27004,   25980,   24956,   23932,   22908,   21884,   20860,
     19836,   18812,   17788,   16764,   15996,   15484,   14972,
     14460,   13948,   13436,   12924,   12412,   11900,   11388,
     10876,   10364,    9852,    9340,    8828,    8316,    7932,
      7676,    7420,    7164,    6908,    6652,    6396,    6140,
      5884,    5628,    5372,    5116,    4860,    4604,    4348,
      4092,    3900,    3772,    3644,    3516,    3388,    3260,
      3132,    3004,    2876,    2748,    2620,    2492,    2364,
      2236,    2108,    1980,    1884,    1820,    1756,    1692,
      1628,    1564,    1500,    1436,    1372,    1308,    1244,
      1180,    1116,    1052,     988,     924,     876,     844,
       812,     780,     748,     716,     684,     652,     620,
       588,     556,     524,     492,     460,     428,     396,
       372,     356,     340,     324,     308,     292,     276,
       260,     244,     228,     212,     196,     180,     164,
       148,     132,     120,     112,     104,      96,      88,
    80,      72,      64,      56,      48,      40,      32,
    24,      16,       8,       0
};

/*
 * linear2ulaw() accepts a 14-bit signed integer and encodes it as u-law data
 * stored in a unsigned char.  This function should only be called with
 * the data shifted such that it only contains information in the lower
 * 14-bits.
 *
 * In order to simplify the encoding process, the original linear magnitude
 * is biased by adding 33 which shifts the encoding range from (0 - 8158) to
 * (33 - 8191). The result can be seen in the following encoding table:
 *
 *      Biased Linear Input Code        Compressed Code
 *      ------------------------        ---------------
 *      00000001wxyza                   000wxyz
 *      0000001wxyzab                   001wxyz
 *      000001wxyzabc                   010wxyz
 *      00001wxyzabcd                   011wxyz
 *      0001wxyzabcde                   100wxyz
 *      001wxyzabcdef                   101wxyz
 *      01wxyzabcdefg                   110wxyz
 *      1wxyzabcdefgh                   111wxyz
 *
 * Each biased linear code has a leading 1 which identifies the segment
 * number. The value of the segment number is equal to 7 minus the number
 * of leading 0's. The quantization interval is directly available as the
 * four bits wxyz.  * The trailing bits (a - h) are ignored.
 *
 * Ordinarily the complement of the resulting code word is used for
 * transmission, and so the code word is complemented before it is returned.
 *
 * For further information see John C. Bellamy's Digital Telephony, 1982,
 * John Wiley & Sons, pps 98-111 and 472-476.
 */
static unsigned char
st_14linear2ulaw(PyInt16 pcm_val)       /* 2's complement (14-bit range) */
{
    PyInt16         mask;
    PyInt16         seg;
    unsigned char   uval;

    /* The original sox code does this in the calling function, not here */
    pcm_val = pcm_val >> 2;

    /* u-law inverts all bits */
    /* Get the sign and the magnitude of the value. */
    if (pcm_val < 0) {
        pcm_val = -pcm_val;
        mask = 0x7F;
    } else {
        mask = 0xFF;
    }
    if ( pcm_val > CLIP ) pcm_val = CLIP;           /* clip the magnitude */
    pcm_val += (BIAS >> 2);

    /* Convert the scaled magnitude to segment number. */
    seg = search(pcm_val, seg_uend, 8);

    /*
     * Combine the sign, segment, quantization bits;
     * and complement the code word.
     */
    if (seg >= 8)           /* out of range, return maximum value. */
        return (unsigned char) (0x7F ^ mask);
    else {
        uval = (unsigned char) (seg << 4) | ((pcm_val >> (seg + 1)) & 0xF);
        return (uval ^ mask);
    }

}

static PyInt16 _st_alaw2linear16[256] = {
     -5504,   -5248,   -6016,   -5760,   -4480,   -4224,   -4992,
     -4736,   -7552,   -7296,   -8064,   -7808,   -6528,   -6272,
     -7040,   -6784,   -2752,   -2624,   -3008,   -2880,   -2240,
     -2112,   -2496,   -2368,   -3776,   -3648,   -4032,   -3904,
     -3264,   -3136,   -3520,   -3392,  -22016,  -20992,  -24064,
    -23040,  -17920,  -16896,  -19968,  -18944,  -30208,  -29184,
    -32256,  -31232,  -26112,  -25088,  -28160,  -27136,  -11008,
    -10496,  -12032,  -11520,   -8960,   -8448,   -9984,   -9472,
    -15104,  -14592,  -16128,  -15616,  -13056,  -12544,  -14080,
    -13568,    -344,    -328,    -376,    -360,    -280,    -264,
      -312,    -296,    -472,    -456,    -504,    -488,    -408,
      -392,    -440,    -424,     -88,     -72,    -120,    -104,
       -24,      -8,     -56,     -40,    -216,    -200,    -248,
      -232,    -152,    -136,    -184,    -168,   -1376,   -1312,
     -1504,   -1440,   -1120,   -1056,   -1248,   -1184,   -1888,
     -1824,   -2016,   -1952,   -1632,   -1568,   -1760,   -1696,
      -688,    -656,    -752,    -720,    -560,    -528,    -624,
      -592,    -944,    -912,   -1008,    -976,    -816,    -784,
      -880,    -848,    5504,    5248,    6016,    5760,    4480,
      4224,    4992,    4736,    7552,    7296,    8064,    7808,
      6528,    6272,    7040,    6784,    2752,    2624,    3008,
      2880,    2240,    2112,    2496,    2368,    3776,    3648,
      4032,    3904,    3264,    3136,    3520,    3392,   22016,
     20992,   24064,   23040,   17920,   16896,   19968,   18944,
     30208,   29184,   32256,   31232,   26112,   25088,   28160,
     27136,   11008,   10496,   12032,   11520,    8960,    8448,
      9984,    9472,   15104,   14592,   16128,   15616,   13056,
     12544,   14080,   13568,     344,     328,     376,     360,
       280,     264,     312,     296,     472,     456,     504,
       488,     408,     392,     440,     424,      88,      72,
       120,     104,      24,       8,      56,      40,     216,
       200,     248,     232,     152,     136,     184,     168,
      1376,    1312,    1504,    1440,    1120,    1056,    1248,
      1184,    1888,    1824,    2016,    1952,    1632,    1568,
      1760,    1696,     688,     656,     752,     720,     560,
       528,     624,     592,     944,     912,    1008,     976,
       816,     784,     880,     848
};

/*
 * linear2alaw() accepts an 13-bit signed integer and encodes it as A-law data
 * stored in a unsigned char.  This function should only be called with
 * the data shifted such that it only contains information in the lower
 * 13-bits.
 *
 *              Linear Input Code       Compressed Code
 *      ------------------------        ---------------
 *      0000000wxyza                    000wxyz
 *      0000001wxyza                    001wxyz
 *      000001wxyzab                    010wxyz
 *      00001wxyzabc                    011wxyz
 *      0001wxyzabcd                    100wxyz
 *      001wxyzabcde                    101wxyz
 *      01wxyzabcdef                    110wxyz
 *      1wxyzabcdefg                    111wxyz
 *
 * For further information see John C. Bellamy's Digital Telephony, 1982,
 * John Wiley & Sons, pps 98-111 and 472-476.
 */
static unsigned char
st_linear2alaw(PyInt16 pcm_val) /* 2's complement (13-bit range) */
{
    PyInt16         mask;
    short           seg;
    unsigned char   aval;

    /* The original sox code does this in the calling function, not here */
    pcm_val = pcm_val >> 3;

    /* A-law using even bit inversion */
    if (pcm_val >= 0) {
        mask = 0xD5;            /* sign (7th) bit = 1 */
    } else {
        mask = 0x55;            /* sign bit = 0 */
        pcm_val = -pcm_val - 1;
    }

    /* Convert the scaled magnitude to segment number. */
    seg = search(pcm_val, seg_aend, 8);

    /* Combine the sign, segment, and quantization bits. */

    if (seg >= 8)           /* out of range, return maximum value. */
        return (unsigned char) (0x7F ^ mask);
    else {
        aval = (unsigned char) seg << SEG_SHIFT;
        if (seg < 2)
            aval |= (pcm_val >> 1) & QUANT_MASK;
        else
            aval |= (pcm_val >> seg) & QUANT_MASK;
        return (aval ^ mask);
    }
}
/* End of code taken from sox */

/* Intel ADPCM step variation table */
static int indexTable[16] = {
    -1, -1, -1, -1, 2, 4, 6, 8,
    -1, -1, -1, -1, 2, 4, 6, 8,
};

static int stepsizeTable[89] = {
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
    19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
    50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
    130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
    337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
    876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
    5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
    15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
};

#define CHARP(cp, i) ((signed char *)(cp+i))
#define SHORTP(cp, i) ((short *)(cp+i))
#define LONGP(cp, i) ((Py_Int32 *)(cp+i))

#if WORDS_BIGENDIAN
#define GETINT24(cp, i)  (                              \
        ((unsigned char *)(cp) + (i))[2] +              \
        (((unsigned char *)(cp) + (i))[1] << 8) +       \
        (((signed char *)(cp) + (i))[0] << 16) )
#else
#define GETINT24(cp, i)  (                              \
        ((unsigned char *)(cp) + (i))[0] +              \
        (((unsigned char *)(cp) + (i))[1] << 8) +       \
        (((signed char *)(cp) + (i))[2] << 16) )
#endif

#if WORDS_BIGENDIAN
#define SETINT24(cp, i, val)  do {                              \
        ((unsigned char *)(cp) + (i))[2] = (int)(val);          \
        ((unsigned char *)(cp) + (i))[1] = (int)(val) >> 8;     \
        ((signed char *)(cp) + (i))[0] = (int)(val) >> 16;      \
    } while (0)
#else
#define SETINT24(cp, i, val)  do {                              \
        ((unsigned char *)(cp) + (i))[0] = (int)(val);          \
        ((unsigned char *)(cp) + (i))[1] = (int)(val) >> 8;     \
        ((signed char *)(cp) + (i))[2] = (int)(val) >> 16;      \
    } while (0)
#endif
"""

C_SOURCE = _AUDIOOP_C_MODULE + r"""
#include <math.h>

static const int maxvals[] = {0, 0x7F, 0x7FFF, 0x7FFFFF, 0x7FFFFFFF};
/* -1 trick is needed on Windows to support -0x80000000 without a warning */
static const int minvals[] = {0, -0x80, -0x8000, -0x800000, -0x7FFFFFFF-1};

static int
fbound(double val, double minval, double maxval)
{
    if (val > maxval) {
        val = maxval;
    }
    else if (val < minval + 1.0) {
        val = minval;
    }

    /* Round towards minus infinity (-inf) */
    val = floor(val);

    /* Cast double to integer: round towards zero */
    return (int)val;
}

static int
gcd(int a, int b)
{
    while (b > 0) {
        int tmp = a % b;
        a = b;
        b = tmp;
    }
    return a;
}

static
int ratecv(char* rv, char* cp, size_t len, int size,
           int nchannels, int inrate, int outrate,
           int* state_d, int* prev_i, int* cur_i,
           int weightA, int weightB)
{
    char *ncp = rv;
    int d, chan;

    /* divide inrate and outrate by their greatest common divisor */
    d = gcd(inrate, outrate);
    inrate /= d;
    outrate /= d;
    /* divide weightA and weightB by their greatest common divisor */
    d = gcd(weightA, weightB);
    weightA /= d;
    weightA /= d;

    d = *state_d;

    for (;;) {
        while (d < 0) {
            if (len == 0) {
                *state_d = d;
                return ncp - rv;
            }
            for (chan = 0; chan < nchannels; chan++) {
                prev_i[chan] = cur_i[chan];
                if (size == 1)
                    cur_i[chan] = ((int)*CHARP(cp, 0)) << 24;
                else if (size == 2)
                    cur_i[chan] = ((int)*SHORTP(cp, 0)) << 16;
                else if (size == 3)
                    cur_i[chan] = ((int)GETINT24(cp, 0)) << 8;
                else if (size == 4)
                    cur_i[chan] = (int)*LONGP(cp, 0);
                cp += size;
                /* implements a simple digital filter */
                cur_i[chan] = (int)(
                    ((double)weightA * (double)cur_i[chan] +
                     (double)weightB * (double)prev_i[chan]) /
                    ((double)weightA + (double)weightB));
            }
            len--;
            d += outrate;
        }
        while (d >= 0) {
            for (chan = 0; chan < nchannels; chan++) {
                int cur_o;
                cur_o = (int)(((double)prev_i[chan] * (double)d +
                         (double)cur_i[chan] * (double)(outrate - d)) /
                    (double)outrate);
                if (size == 1)
                    *CHARP(ncp, 0) = (signed char)(cur_o >> 24);
                else if (size == 2)
                    *SHORTP(ncp, 0) = (short)(cur_o >> 16);
                else if (size == 3)
                    SETINT24(ncp, 0, cur_o >> 8);
                else if (size == 4)
                    *LONGP(ncp, 0) = (Py_Int32)(cur_o);
                ncp += size;
            }
            d -= inrate;
        }
    }
}

static
void tostereo(char* rv, char* cp, size_t len, int size,
              double fac1, double fac2)
{
    int val1, val2, val = 0;
    double fval, maxval, minval;
    char *ncp = rv;
    int i;

    maxval = (double) maxvals[size];
    minval = (double) minvals[size];

    for ( i=0; i < len; i += size ) {
        if ( size == 1 )      val = (int)*CHARP(cp, i);
        else if ( size == 2 ) val = (int)*SHORTP(cp, i);
        else if ( size == 3 ) val = (int)GETINT24(cp, i);
        else if ( size == 4 ) val = (int)*LONGP(cp, i);

        fval = (double)val * fac1;
        val1 = fbound(fval, minval, maxval);

        fval = (double)val * fac2;
        val2 = fbound(fval, minval, maxval);

        if ( size == 1 )      *CHARP(ncp, i*2) = (signed char)val1;
        else if ( size == 2 ) *SHORTP(ncp, i*2) = (short)val1;
        else if ( size == 3 ) SETINT24(ncp, i*2, val1);
        else if ( size == 4 ) *LONGP(ncp, i*2) = (Py_Int32)val1;

        if ( size == 1 )      *CHARP(ncp, i*2+1) = (signed char)val2;
        else if ( size == 2 ) *SHORTP(ncp, i*2+2) = (short)val2;
        else if ( size == 3 ) SETINT24(ncp, i*2+3, val2);
        else if ( size == 4 ) *LONGP(ncp, i*2+4) = (Py_Int32)val2;
    }
}

static
void add(char* rv, char* cp1, char* cp2, size_t len1, int size)
{
    int i;
    int val1 = 0, val2 = 0, minval, maxval, newval;
    char* ncp = rv;

    maxval = maxvals[size];
    minval = minvals[size];

    for ( i=0; i < len1; i += size ) {
        if ( size == 1 )      val1 = (int)*CHARP(cp1, i);
        else if ( size == 2 ) val1 = (int)*SHORTP(cp1, i);
        else if ( size == 3 ) val1 = (int)GETINT24(cp1, i);
        else if ( size == 4 ) val1 = (int)*LONGP(cp1, i);

        if ( size == 1 )      val2 = (int)*CHARP(cp2, i);
        else if ( size == 2 ) val2 = (int)*SHORTP(cp2, i);
        else if ( size == 3 ) val2 = (int)GETINT24(cp2, i);
        else if ( size == 4 ) val2 = (int)*LONGP(cp2, i);

        if (size < 4) {
            newval = val1 + val2;
            /* truncate in case of overflow */
            if (newval > maxval)
                newval = maxval;
            else if (newval < minval)
                newval = minval;
        }
        else {
            double fval = (double)val1 + (double)val2;
            /* truncate in case of overflow */
            newval = fbound(fval, minval, maxval);
        }

        if ( size == 1 )      *CHARP(ncp, i) = (signed char)newval;
        else if ( size == 2 ) *SHORTP(ncp, i) = (short)newval;
        else if ( size == 3 ) SETINT24(ncp, i, newval);
        else if ( size == 4 ) *LONGP(ncp, i) = (Py_Int32)newval;
    }
}

static
void lin2adcpm(unsigned char* ncp, unsigned char* cp, size_t len,
               size_t size, int* state)
{
    int step, outputbuffer = 0, bufferstep;
    int val = 0;
    int diff, vpdiff, sign, delta;
    size_t i;
    int valpred = state[0];
    int index = state[1];

    step = stepsizeTable[index];
    bufferstep = 1;

    for ( i=0; i < len; i += size ) {
        if ( size == 1 )      val = ((int)*CHARP(cp, i)) << 8;
        else if ( size == 2 ) val = (int)*SHORTP(cp, i);
        else if ( size == 3 ) val = ((int)GETINT24(cp, i)) >> 8;
        else if ( size == 4 ) val = ((int)*LONGP(cp, i)) >> 16;

        /* Step 1 - compute difference with previous value */
        diff = val - valpred;
        sign = (diff < 0) ? 8 : 0;
        if ( sign ) diff = (-diff);

        /* Step 2 - Divide and clamp */
        /* Note:
        ** This code *approximately* computes:
        **    delta = diff*4/step;
        **    vpdiff = (delta+0.5)*step/4;
        ** but in shift step bits are dropped. The net result of this
        ** is that even if you have fast mul/div hardware you cannot
        ** put it to good use since the fixup would be too expensive.
        */
        delta = 0;
        vpdiff = (step >> 3);

        if ( diff >= step ) {
            delta = 4;
            diff -= step;
            vpdiff += step;
        }
        step >>= 1;
        if ( diff >= step  ) {
            delta |= 2;
            diff -= step;
            vpdiff += step;
        }
        step >>= 1;
        if ( diff >= step ) {
            delta |= 1;
            vpdiff += step;
        }

        /* Step 3 - Update previous value */
        if ( sign )
            valpred -= vpdiff;
        else
            valpred += vpdiff;

        /* Step 4 - Clamp previous value to 16 bits */
        if ( valpred > 32767 )
            valpred = 32767;
        else if ( valpred < -32768 )
            valpred = -32768;

        /* Step 5 - Assemble value, update index and step values */
        delta |= sign;

        index += indexTable[delta];
        if ( index < 0 ) index = 0;
        if ( index > 88 ) index = 88;
        step = stepsizeTable[index];

        /* Step 6 - Output value */
        if ( bufferstep ) {
            outputbuffer = (delta << 4) & 0xf0;
        } else {
            *ncp++ = (delta & 0x0f) | outputbuffer;
        }
        bufferstep = !bufferstep;
    }
    state[0] = valpred;
    state[1] = index;
}


static
void adcpm2lin(unsigned char* ncp, unsigned char* cp, size_t len,
               size_t size, int* state)
{
    int step, inputbuffer = 0, bufferstep;
    int val = 0;
    int diff, vpdiff, sign, delta;
    size_t i;
    int valpred = state[0];
    int index = state[1];

    step = stepsizeTable[index];
    bufferstep = 0;

    for ( i=0; i < len*size*2; i += size ) {
        /* Step 1 - get the delta value and compute next index */
        if ( bufferstep ) {
            delta = inputbuffer & 0xf;
        } else {
            inputbuffer = *cp++;
            delta = (inputbuffer >> 4) & 0xf;
        }

        bufferstep = !bufferstep;

        /* Step 2 - Find new index value (for later) */
        index += indexTable[delta];
        if ( index < 0 ) index = 0;
        if ( index > 88 ) index = 88;

        /* Step 3 - Separate sign and magnitude */
        sign = delta & 8;
        delta = delta & 7;

        /* Step 4 - Compute difference and new predicted value */
        /*
        ** Computes 'vpdiff = (delta+0.5)*step/4', but see comment
        ** in adpcm_coder.
        */
        vpdiff = step >> 3;
        if ( delta & 4 ) vpdiff += step;
        if ( delta & 2 ) vpdiff += step>>1;
        if ( delta & 1 ) vpdiff += step>>2;

        if ( sign )
            valpred -= vpdiff;
        else
            valpred += vpdiff;

        /* Step 5 - clamp output value */
        if ( valpred > 32767 )
            valpred = 32767;
        else if ( valpred < -32768 )
            valpred = -32768;

        /* Step 6 - Update step value */
        step = stepsizeTable[index];

        /* Step 6 - Output value */
        if ( size == 1 ) *CHARP(ncp, i) = (signed char)(valpred >> 8);
        else if ( size == 2 ) *SHORTP(ncp, i) = (short)(valpred);
        else if ( size == 3 ) SETINT24(ncp, i, valpred << 8);
        else if ( size == 4 ) *LONGP(ncp, i) = (Py_Int32)(valpred<<16);
    }
    state[0] = valpred;
    state[1] = index;
}
"""

ffi.set_source("_audioop_cffi", C_SOURCE)

if __name__ == "__main__":
    import sys
    print('using python from', sys.executable)
    ffi.compile(verbose=2)
