#include "Python.h"

#if defined(Py_ISDIGIT) || defined(Py_ISALPHA)
#error remove these definitions
#endif
#define Py_ISDIGIT isdigit
#define Py_ISALPHA isalpha

static void
makefmt(char *fmt, int longflag, int longlongflag, int size_tflag,
        int zeropad, int width, int precision, char c)
{
    *fmt++ = '%';
    if (width) {
        if (zeropad)
            *fmt++ = '0';
        fmt += sprintf(fmt, "%d", width);
    }
    if (precision)
        fmt += sprintf(fmt, ".%d", precision);
    if (longflag)
        *fmt++ = 'l';
    else if (longlongflag) {
        /* longlongflag should only ever be nonzero on machines with
           HAVE_LONG_LONG defined */
#ifdef HAVE_LONG_LONG
        char *f = PY_FORMAT_LONG_LONG;
        while (*f)
            *fmt++ = *f++;
#else
        /* we shouldn't ever get here */
        assert(0);
        *fmt++ = 'l';
#endif
    }
    else if (size_tflag) {
        char *f = PY_FORMAT_SIZE_T;
        while (*f)
            *fmt++ = *f++;
    }
    *fmt++ = c;
    *fmt = '\0';
}

#define appendstring(string) {for (copy = string;*copy;) *s++ = *copy++;}

/* size of fixed-size buffer for formatting single arguments */
#define ITEM_BUFFER_LEN 21
/* maximum number of characters required for output of %ld.  21 characters
   allows for 64-bit integers (in decimal) and an optional sign. */
#define MAX_LONG_CHARS 21
/* maximum number of characters required for output of %lld.
   We need at most ceil(log10(256)*SIZEOF_LONG_LONG) digits,
   plus 1 for the sign.  53/22 is an upper bound for log10(256). */
#define MAX_LONG_LONG_CHARS (2 + (SIZEOF_LONG_LONG*53-1) / 22)

#ifdef HAVE_WCHAR_H

PyObject *
PyUnicode_FromWideChar(const wchar_t *w, Py_ssize_t size)
{
    /*
    if (w == NULL) {
        if (size == 0)
            _Py_RETURN_UNICODE_EMPTY();
        PyErr_BadInternalCall();
        return NULL;
    }
    */

    if (size == -1) {
        size = wcslen(w);
    }

    return PyUnicode_FromUnicode(w, size);
}

#endif /* HAVE_WCHAR_H */

PyObject *
PyUnicode_FromFormatV(const char *format, va_list vargs)
{
    va_list count;
    Py_ssize_t callcount = 0;
    PyObject **callresults = NULL;
    PyObject **callresult = NULL;
    Py_ssize_t n = 0;
    int zeropad;
    const char* f;
    Py_UNICODE *s;
    PyObject *string;
    /* used by sprintf */
    char buffer[ITEM_BUFFER_LEN+1];
    /* use abuffer instead of buffer, if we need more space
     * (which can happen if there's a format specifier with width). */
    char *abuffer = NULL;
    char *realbuffer;
    Py_ssize_t abuffersize = 0;
    char fmt[61]; /* should be enough for %0width.precisionlld */
    const char *copy;

    Py_VA_COPY(count, vargs);
    /* step 1: count the number of %S/%R/%A/%s format specifications
     * (we call PyObject_Str()/PyObject_Repr()/PyObject_ASCII()/
     * PyUnicode_DecodeUTF8() for these objects once during step 3 and put the
     * result in an array) */
    for (f = format; *f; f++) {
         if (*f == '%') {
             f++;
             if (f[0]=='%') {
                 continue;
             }
             while (Py_ISDIGIT((unsigned)f[0]) || f[0] == '.') f++;
             if (f[0] == 'S' || f[0] == 'R' || f[0] == 'A' || f[0] == 'V' || f[0] == 's') {
                 callcount++;
             }
         }
         else if (128 <= (unsigned char)*f) {
             PyErr_Format(PyExc_ValueError,
                "PyUnicode_FromFormatV() expects an ASCII-encoded format "
                "string, got a non-ASCII byte: 0x%02x",
                (unsigned char)*f);
             return NULL;
         }
    }
    /* step 2: allocate memory for the results of
     * PyObject_Str()/PyObject_Repr()/PyUnicode_DecodeUTF8() calls */
    if (callcount) {
        callresults = PyObject_Malloc(sizeof(PyObject *)*callcount);
        if (!callresults) {
            PyErr_NoMemory();
            return NULL;
        }
        callresult = callresults;
    }
    /* step 3: figure out how large a buffer we need */
    for (f = format; *f; f++) {
        if (*f == '%') {
#ifdef HAVE_LONG_LONG
            int longlongflag = 0;
#endif
            int width = 0;
            const char* p = f;
            while (Py_ISDIGIT((unsigned)*f))
                width = (width*10) + *f++ - '0';
            while (*++f && *f != '%' && !Py_ISALPHA((unsigned)*f))
                ;

            /* skip the 'l' or 'z' in {%ld, %zd, %lu, %zu} since
             * they don't affect the amount of space we reserve.
             */
            if (*f == 'l') {
                if (f[1] == 'd' || f[1] == 'u') {
                    ++f;
                }
#ifdef HAVE_LONG_LONG
                else if (f[1] == 'l' &&
                         (f[2] == 'd' || f[2] == 'u')) {
                    longlongflag = 1;
                    f += 2;
                }
#endif
            }
            else if (*f == 'z' && (f[1] == 'd' || f[1] == 'u')) {
                ++f;
            }

            switch (*f) {
            case 'c':
            {
#ifndef Py_UNICODE_WIDE
                int ordinal = va_arg(count, int);
                if (ordinal > 0xffff)
                    n += 2;
                else
                    n++;
#else
                (void)va_arg(count, int);
                n++;
#endif
                break;
            }
            case '%':
                n++;
                break;
            case 'd': case 'u': case 'i': case 'x':
                (void) va_arg(count, int);
#ifdef HAVE_LONG_LONG
                if (longlongflag) {
                    if (width < MAX_LONG_LONG_CHARS)
                        width = MAX_LONG_LONG_CHARS;
                }
                else
#endif
                    /* MAX_LONG_CHARS is enough to hold a 64-bit integer,
                       including sign.  Decimal takes the most space.  This
                       isn't enough for octal.  If a width is specified we
                       need more (which we allocate later). */
                    if (width < MAX_LONG_CHARS)
                        width = MAX_LONG_CHARS;
                n += width;
                /* XXX should allow for large precision here too. */
                if (abuffersize < width)
                    abuffersize = width;
                break;
            case 's':
            {
                /* UTF-8 */
                const char *s = va_arg(count, const char*);
                PyObject *str = PyUnicode_DecodeUTF8(s, strlen(s), "replace");
                if (!str)
                    goto fail;
                n += PyUnicode_GET_SIZE(str);
                /* Remember the str and switch to the next slot */
                *callresult++ = str;
                break;
            }
            case 'U':
            {
                PyObject *obj = va_arg(count, PyObject *);
                assert(obj && PyUnicode_Check(obj));
                n += PyUnicode_GET_SIZE(obj);
                break;
            }
            case 'V':
            {
                PyObject *obj = va_arg(count, PyObject *);
                const char *str = va_arg(count, const char *);
                PyObject *str_obj;
                assert(obj || str);
                assert(!obj || PyUnicode_Check(obj));
                if (obj) {
                    n += PyUnicode_GET_SIZE(obj);
                    *callresult++ = NULL;
                }
                else {
                    str_obj = PyUnicode_DecodeUTF8(str, strlen(str), "replace");
                    if (!str_obj)
                        goto fail;
                    n += PyUnicode_GET_SIZE(str_obj);
                    *callresult++ = str_obj;
                }
                break;
            }
            case 'S':
            {
                PyObject *obj = va_arg(count, PyObject *);
                PyObject *str;
                assert(obj);
                str = PyObject_Str(obj);
                if (!str)
                    goto fail;
                n += PyUnicode_GET_SIZE(str);
                /* Remember the str and switch to the next slot */
                *callresult++ = str;
                break;
            }
            case 'R':
            {
                PyObject *obj = va_arg(count, PyObject *);
                PyObject *repr;
                assert(obj);
                repr = PyObject_Repr(obj);
                if (!repr)
                    goto fail;
                n += PyUnicode_GET_SIZE(repr);
                /* Remember the repr and switch to the next slot */
                *callresult++ = repr;
                break;
            }
            case 'A':
            {
                PyObject *obj = va_arg(count, PyObject *);
                PyObject *ascii;
                assert(obj);
                ascii = PyObject_ASCII(obj);
                if (!ascii)
                    goto fail;
                n += PyUnicode_GET_SIZE(ascii);
                /* Remember the repr and switch to the next slot */
                *callresult++ = ascii;
                break;
            }
            case 'p':
                (void) va_arg(count, int);
                /* maximum 64-bit pointer representation:
                 * 0xffffffffffffffff
                 * so 19 characters is enough.
                 * XXX I count 18 -- what's the extra for?
                 */
                n += 19;
                break;
            default:
                /* if we stumble upon an unknown
                   formatting code, copy the rest of
                   the format string to the output
                   string. (we cannot just skip the
                   code, since there's no way to know
                   what's in the argument list) */
                n += strlen(p);
                goto expand;
            }
        } else
            n++;
    }
  expand:
    if (abuffersize > ITEM_BUFFER_LEN) {
        /* add 1 for sprintf's trailing null byte */
        abuffer = PyObject_Malloc(abuffersize + 1);
        if (!abuffer) {
            PyErr_NoMemory();
            goto fail;
        }
        realbuffer = abuffer;
    }
    else
        realbuffer = buffer;
    /* step 4: fill the buffer */
    /* Since we've analyzed how much space we need for the worst case,
       we don't have to resize the string.
       There can be no errors beyond this point. */
    string = PyUnicode_FromUnicode(NULL, n);
    if (!string)
        goto fail;

    s = PyUnicode_AS_UNICODE(string);
    callresult = callresults;

    for (f = format; *f; f++) {
        if (*f == '%') {
            const char* p = f++;
            int longflag = 0;
            int longlongflag = 0;
            int size_tflag = 0;
            int width = 0;
            int precision = 0;
            zeropad = (*f == '0');
            /* parse the width.precision part */
            while (Py_ISDIGIT((unsigned)*f))
                width = (width*10) + *f++ - '0';
            if (*f == '.') {
                f++;
                while (Py_ISDIGIT((unsigned)*f))
                    precision = (precision*10) + *f++ - '0';
            }
            /* Handle %ld, %lu, %lld and %llu. */
            if (*f == 'l') {
                if (f[1] == 'd' || f[1] == 'u') {
                    longflag = 1;
                    ++f;
                }
#ifdef HAVE_LONG_LONG
                else if (f[1] == 'l' &&
                         (f[2] == 'd' || f[2] == 'u')) {
                    longlongflag = 1;
                    f += 2;
                }
#endif
            }
            /* handle the size_t flag. */
            if (*f == 'z' && (f[1] == 'd' || f[1] == 'u')) {
                size_tflag = 1;
                ++f;
            }

            switch (*f) {
            case 'c':
            {
                int ordinal = va_arg(vargs, int);
#ifndef Py_UNICODE_WIDE
                if (ordinal > 0xffff) {
                    ordinal -= 0x10000;
                    *s++ = 0xD800 | (ordinal >> 10);
                    *s++ = 0xDC00 | (ordinal & 0x3FF);
                } else
#endif
                *s++ = ordinal;
                break;
            }
            case 'd':
                makefmt(fmt, longflag, longlongflag, size_tflag, zeropad,
                        width, precision, 'd');
                if (longflag)
                    sprintf(realbuffer, fmt, va_arg(vargs, long));
#ifdef HAVE_LONG_LONG
                else if (longlongflag)
                    sprintf(realbuffer, fmt, va_arg(vargs, PY_LONG_LONG));
#endif
                else if (size_tflag)
                    sprintf(realbuffer, fmt, va_arg(vargs, Py_ssize_t));
                else
                    sprintf(realbuffer, fmt, va_arg(vargs, int));
                appendstring(realbuffer);
                break;
            case 'u':
                makefmt(fmt, longflag, longlongflag, size_tflag, zeropad,
                        width, precision, 'u');
                if (longflag)
                    sprintf(realbuffer, fmt, va_arg(vargs, unsigned long));
#ifdef HAVE_LONG_LONG
                else if (longlongflag)
                    sprintf(realbuffer, fmt, va_arg(vargs,
                                                    unsigned PY_LONG_LONG));
#endif
                else if (size_tflag)
                    sprintf(realbuffer, fmt, va_arg(vargs, size_t));
                else
                    sprintf(realbuffer, fmt, va_arg(vargs, unsigned int));
                appendstring(realbuffer);
                break;
            case 'i':
                makefmt(fmt, 0, 0, 0, zeropad, width, precision, 'i');
                sprintf(realbuffer, fmt, va_arg(vargs, int));
                appendstring(realbuffer);
                break;
            case 'x':
                makefmt(fmt, 0, 0, 0, zeropad, width, precision, 'x');
                sprintf(realbuffer, fmt, va_arg(vargs, int));
                appendstring(realbuffer);
                break;
            case 's':
            {
                /* unused, since we already have the result */
                (void) va_arg(vargs, char *);
                Py_UNICODE_COPY(s, PyUnicode_AS_UNICODE(*callresult),
                                PyUnicode_GET_SIZE(*callresult));
                s += PyUnicode_GET_SIZE(*callresult);
                /* We're done with the unicode()/repr() => forget it */
                Py_DECREF(*callresult);
                /* switch to next unicode()/repr() result */
                ++callresult;
                break;
            }
            case 'U':
            {
                PyObject *obj = va_arg(vargs, PyObject *);
                Py_ssize_t size = PyUnicode_GET_SIZE(obj);
                Py_UNICODE_COPY(s, PyUnicode_AS_UNICODE(obj), size);
                s += size;
                break;
            }
            case 'V':
            {
                PyObject *obj = va_arg(vargs, PyObject *);
                va_arg(vargs, const char *);
                if (obj) {
                    Py_ssize_t size = PyUnicode_GET_SIZE(obj);
                    Py_UNICODE_COPY(s, PyUnicode_AS_UNICODE(obj), size);
                    s += size;
                } else {
                    Py_UNICODE_COPY(s, PyUnicode_AS_UNICODE(*callresult),
                                    PyUnicode_GET_SIZE(*callresult));
                    s += PyUnicode_GET_SIZE(*callresult);
                    Py_DECREF(*callresult);
                }
                ++callresult;
                break;
            }
            case 'S':
            case 'R':
            case 'A':
            {
                Py_UNICODE *ucopy;
                Py_ssize_t usize;
                Py_ssize_t upos;
                /* unused, since we already have the result */
                (void) va_arg(vargs, PyObject *);
                ucopy = PyUnicode_AS_UNICODE(*callresult);
                usize = PyUnicode_GET_SIZE(*callresult);
                for (upos = 0; upos<usize;)
                    *s++ = ucopy[upos++];
                /* We're done with the unicode()/repr() => forget it */
                Py_DECREF(*callresult);
                /* switch to next unicode()/repr() result */
                ++callresult;
                break;
            }
            case 'p':
                sprintf(buffer, "%p", va_arg(vargs, void*));
                /* %p is ill-defined:  ensure leading 0x. */
                if (buffer[1] == 'X')
                    buffer[1] = 'x';
                else if (buffer[1] != 'x') {
                    memmove(buffer+2, buffer, strlen(buffer)+1);
                    buffer[0] = '0';
                    buffer[1] = 'x';
                }
                appendstring(buffer);
                break;
            case '%':
                *s++ = '%';
                break;
            default:
                appendstring(p);
                goto end;
            }
        }
        else
            *s++ = *f;
    }

  end:
    if (callresults)
        PyObject_Free(callresults);
    if (abuffer)
        PyObject_Free(abuffer);
    PyUnicode_Resize(&string, s - PyUnicode_AS_UNICODE(string));
    return string;
  fail:
    if (callresults) {
        PyObject **callresult2 = callresults;
        while (callresult2 < callresult) {
            Py_XDECREF(*callresult2);
            ++callresult2;
        }
        PyObject_Free(callresults);
    }
    if (abuffer)
        PyObject_Free(abuffer);
    return NULL;
}

#undef appendstring

PyObject *
PyUnicode_FromFormat(const char *format, ...)
{
    PyObject* ret;
    va_list vargs;

#ifdef HAVE_STDARG_PROTOTYPES
    va_start(vargs, format);
#else
    va_start(vargs);
#endif
    ret = PyUnicode_FromFormatV(format, vargs);
    va_end(vargs);
    return ret;
}

wchar_t*
PyUnicode_AsWideCharString(PyObject *unicode,
                           Py_ssize_t *size)
{
    wchar_t* buffer;
    Py_ssize_t buflen;

    if (unicode == NULL) {
        PyErr_BadInternalCall();
        return NULL;
    }

    buflen = PyUnicode_GET_SIZE(unicode) + 1;
    if (PY_SSIZE_T_MAX / sizeof(wchar_t) < buflen) {
        PyErr_NoMemory();
        return NULL;
    }

    /* PyPy shortcut: Unicode is already an array of wchar_t */
    buffer = PyMem_MALLOC(buflen * sizeof(wchar_t));
    if (buffer == NULL) {
        PyErr_NoMemory();
        return NULL;
    }

    if (PyUnicode_AsWideChar(unicode, buffer, buflen) < 0)
	return NULL;
    if (size != NULL)
        *size = buflen - 1;
    return buffer;
}

Py_ssize_t
PyUnicode_GetSize(PyObject *unicode)
{
    if (!PyUnicode_Check(unicode)) {
        PyErr_BadArgument();
        goto onError;
    }
    return PyUnicode_GET_SIZE(unicode);

  onError:
    return -1;
}

Py_ssize_t
PyUnicode_GetLength(PyObject *unicode)
{
    if (!PyUnicode_Check(unicode)) {
        PyErr_BadArgument();
        return -1;
    }
    if (PyUnicode_READY(unicode) == -1)
        return -1;
    return PyUnicode_GET_LENGTH(unicode);
}
