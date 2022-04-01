/* From CPython 3.2.3's fileutils.c, and _Py_normalize_encoding from
   unicodeobject.c
*/
/*
#include "Python.h"
*/
#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>
#ifdef _MSC_VER
#define MS_WINDOWS
#endif
#define PyMem_Malloc malloc
#define PyMem_Free free
/* C99 but recent Windows has it */
#define HAVE_MBRTOWC 1

#ifdef MS_WINDOWS
#  include <windows.h>
#else
#include <locale.h>
#define HAVE_LANGINFO_H
#endif

#ifdef HAVE_LANGINFO_H
#include <locale.h>
#include <langinfo.h>
#endif
#include "locale_codec.h"

#if 0 && defined(__APPLE__)
extern wchar_t* _Py_DecodeUTF8_surrogateescape(const char *s, Py_ssize_t size);
#endif

#if !defined(__APPLE__) && !defined(MS_WINDOWS)
extern int _pypy_normalize_encoding(const char *, char *, size_t);

/* Workaround FreeBSD and OpenIndiana locale encoding issue with the C locale.
   On these operating systems, nl_langinfo(CODESET) announces an alias of the
   ASCII encoding, whereas mbstowcs() and wcstombs() functions use the
   ISO-8859-1 encoding. The problem is that os.fsencode() and os.fsdecode() use
   locale.getpreferredencoding() codec. For example, if command line arguments
   are decoded by mbstowcs() and encoded back by os.fsencode(), we get a
   UnicodeEncodeError instead of retrieving the original byte string.

   The workaround is enabled if setlocale(LC_CTYPE, NULL) returns "C",
   nl_langinfo(CODESET) announces "ascii" (or an alias to ASCII), and at least
   one byte in range 0x80-0xff can be decoded from the locale encoding. The
   workaround is also enabled on error, for example if getting the locale
   failed.

   Values of locale_is_ascii:

       1: the workaround is used: _Py_wchar2char() uses
          encode_ascii_surrogateescape() and _Py_char2wchar() uses
          decode_ascii_surrogateescape()
       0: the workaround is not used: _Py_wchar2char() uses wcstombs() and
          _Py_char2wchar() uses mbstowcs()
      -1: unknown, need to call check_force_ascii() to get the value
*/
static int force_ascii = -1;

static int
_pypy_check_force_ascii(void)
{
    char *loc;
#if defined(HAVE_LANGINFO_H) && defined(CODESET)
    char *codeset, **alias;
    char encoding[100];
    int is_ascii;
    unsigned int i;
    char* ascii_aliases[] = {
        "ascii",
        "646",
        "ansi-x3.4-1968",
        "ansi-x3-4-1968",
        "ansi-x3.4-1986",
        "cp367",
        "csascii",
        "ibm367",
        "iso646-us",
        "iso-646.irv-1991",
        "iso-ir-6",
        "us",
        "us-ascii",
        NULL
    };
#endif

    setlocale(LC_CTYPE, "");
    loc = setlocale(LC_CTYPE, NULL);
    if (loc == NULL)
        goto error;
    if (strcmp(loc, "C") != 0) {
        /* the LC_CTYPE locale is different than C */
        return 0;
    }

#if defined(HAVE_LANGINFO_H) && defined(CODESET)
    codeset = nl_langinfo(CODESET);
    if (!codeset || codeset[0] == '\0') {
        /* CODESET is not set or empty */
        goto error;
    }
    if (!_pypy_normalize_encoding(codeset, encoding, sizeof(encoding)))
        goto error;

    is_ascii = 0;
    for (alias=ascii_aliases; *alias != NULL; alias++) {
        if (strcmp(encoding, *alias) == 0) {
            is_ascii = 1;
            break;
        }
    }
    if (!is_ascii) {
        /* nl_langinfo(CODESET) is not "ascii" or an alias of ASCII */
        return 0;
    }

    for (i=0x80; i<0xff; i++) {
        unsigned char ch;
        wchar_t wch;
        size_t res;

        ch = (unsigned char)i;
        res = mbstowcs(&wch, (char*)&ch, 1);
        if (res != (size_t)-1) {
            /* decoding a non-ASCII character from the locale encoding succeed:
               the locale encoding is not ASCII, force ASCII */
            return 1;
        }
    }
    /* None of the bytes in the range 0x80-0xff can be decoded from the locale
       encoding: the locale encoding is really ASCII */
    return 0;
#else
    /* nl_langinfo(CODESET) is not available: always force ASCII */
    return 1;
#endif

error:
    /* if an error occured, force the ASCII encoding */
    return 1;
}

static char*
_pypy_encode_ascii_surrogateescape(const wchar_t *text, size_t *error_pos)
{
    char *result = NULL, *out;
    size_t len, i;
    wchar_t ch;

    if (error_pos != NULL)
        *error_pos = (size_t)-1;

    len = wcslen(text);

    result = PyMem_Malloc(len + 1);  /* +1 for NUL byte */
    if (result == NULL)
        return NULL;

    out = result;
    for (i=0; i<len; i++) {
        ch = text[i];

        if (ch <= 0x7f) {
            /* ASCII character */
            *out++ = (char)ch;
        }
        else if (0xdc80 <= ch && ch <= 0xdcff) {
            /* UTF-8b surrogate */
            *out++ = (char)(ch - 0xdc00);
        }
        else {
            if (error_pos != NULL)
                *error_pos = i;
            PyMem_Free(result);
            return NULL;
        }
    }
    *out = '\0';
    return result;
}
#endif   /* !defined(__APPLE__) && !defined(MS_WINDOWS) */

#if !defined(__APPLE__) && (!defined(MS_WINDOWS) || !defined(HAVE_MBRTOWC))
static wchar_t*
_pypy_decode_ascii_surrogateescape(const char *arg, size_t *size)
{
    wchar_t *res;
    unsigned char *in;
    wchar_t *out;

    res = PyMem_Malloc((strlen(arg)+1)*sizeof(wchar_t));
    if (!res)
        return NULL;

    in = (unsigned char*)arg;
    out = res;
    while(*in)
        if(*in < 128)
            *out++ = *in++;
        else
            *out++ = 0xdc00 + *in++;
    *out = 0;
    if (size != NULL)
        *size = out - res;
    return res;
}
#endif


/* Decode a byte string from the locale encoding with the
   surrogateescape error handler (undecodable bytes are decoded as characters
   in range U+DC80..U+DCFF). If a byte sequence can be decoded as a surrogate
   character, escape the bytes using the surrogateescape error handler instead
   of decoding them.

   Use _Py_wchar2char() to encode the character string back to a byte string.

   Return a pointer to a newly allocated wide character string (use
   PyMem_Free() to free the memory) and write the number of written wide
   characters excluding the null character into *size if size is not NULL, or
   NULL on error (conversion or memory allocation error).

   Conversion errors should never happen, unless there is a bug in the C
   library. */
wchar_t*
pypy_char2wchar(const char* arg, size_t *size)
{
    wchar_t *res;
    size_t argsize;
    size_t count;
    unsigned char *in;
    wchar_t *out;
#ifdef HAVE_MBRTOWC
    mbstate_t mbs;
#endif

#if !defined(__APPLE__) && !defined(MS_WINDOWS)
/*#ifndef MS_WINDOWS*/
    if (force_ascii == -1)
        force_ascii = _pypy_check_force_ascii();

    if (force_ascii) {
        /* force ASCII encoding to workaround mbstowcs() issue */
        res = _pypy_decode_ascii_surrogateescape(arg, size);
        if (res == NULL)
            goto oom;
        return res;
    }
#endif

#ifdef HAVE_BROKEN_MBSTOWCS
    /* Some platforms have a broken implementation of
     * mbstowcs which does not count the characters that
     * would result from conversion.  Use an upper bound.
     */
    argsize = strlen(arg);
#else
    argsize = mbstowcs(NULL, arg, 0);
#endif
    if (argsize != (size_t)-1) {
        res = (wchar_t *)PyMem_Malloc((argsize+1)*sizeof(wchar_t));
        if (!res)
            goto oom;
        count = mbstowcs(res, arg, argsize+1);
        if (count != (size_t)-1) {
            wchar_t *tmp;
            /* Only use the result if it contains no
               surrogate characters. */
            for (tmp = res; *tmp != 0 &&
                         (*tmp < 0xd800 || *tmp > 0xdfff); tmp++)
                ;
            if (*tmp == 0) {
                if (size != NULL)
                    *size = count;
                return res;
            }
        }
        PyMem_Free(res);
    }
    /* Conversion failed. Fall back to escaping with surrogateescape. */
#ifdef HAVE_MBRTOWC
    /* Try conversion with mbrtwoc (C99), and escape non-decodable bytes. */

    /* Overallocate; as multi-byte characters are in the argument, the
       actual output could use less memory. */
    argsize = strlen(arg) + 1;
    res = (wchar_t*)PyMem_Malloc(argsize*sizeof(wchar_t));
    if (!res)
        goto oom;
    in = (unsigned char*)arg;
    out = res;
    memset(&mbs, 0, sizeof mbs);
    while (argsize) {
        size_t converted = mbrtowc(out, (char *)in, argsize, &mbs);
        if (converted == 0) {
            /* Reached end of string; null char stored. */
            break;
        }
        if (converted == (size_t)-2) {
            /* Incomplete character. This should never happen,
               since we provide everything that we have -
               unless there is a bug in the C library, or I
               misunderstood how mbrtowc works. */
            fprintf(stderr, "unexpected mbrtowc result -2\n");
            PyMem_Free(res);
            return NULL;
        }
        if (converted == (size_t)-1) {
            /* Conversion error. Escape as UTF-8b, and start over
               in the initial shift state. */
            *out++ = 0xdc00 + *in++;
            argsize--;
            memset(&mbs, 0, sizeof mbs);
            continue;
        }
        if ((*out >= 0xd800 && *out <= 0xdfff) || *out > 0x10ffff) {
            /* bpo-35883: glibc mbstowcs() can return values above 0x10ffff */
            /* Surrogate character.  Escape the original
               byte sequence with surrogateescape. */
            argsize -= converted;
            while (converted--)
                *out++ = 0xdc00 + *in++;
            continue;
        }
        /* successfully converted some bytes */
        in += converted;
        argsize -= converted;
        out++;
    }
    if (size != NULL)
        *size = out - res;
#else   /* HAVE_MBRTOWC */
    /* Cannot use C locale for escaping; manually escape as if charset
       is ASCII (i.e. escape all bytes > 128. This will still roundtrip
       correctly in the locale's charset, which must be an ASCII superset. */
    res = _pypy_decode_ascii_surrogateescape(arg, size);
    if (res == NULL)
        goto oom;
#endif   /* HAVE_MBRTOWC */
    return res;
oom:
    fprintf(stderr, "out of memory\n");
    return NULL;
}

/* Decode a byte string from the locale encoding with the
   strict error handler: in other words fail to decode.

   Use pypy_wchar2char_strict() to encode the character string back to a byte
   string.

   Return a pointer to a newly allocated wide character string (use
   PyMem_Free() to free the memory) and write the number of written wide
   characters excluding the null character into *size if size is not NULL, or
   NULL on error (conversion or memory allocation error).

*/
wchar_t*
pypy_char2wchar_strict(const char* arg, size_t *size)
{
    wchar_t *res;
    size_t argsize;
    size_t count;
    unsigned char *in;
    wchar_t *out;
#ifdef HAVE_MBRTOWC
    mbstate_t mbs;
#endif

#if !defined(__APPLE__) && !defined(MS_WINDOWS)
/*#ifndef MS_WINDOWS*/
    if (force_ascii == -1)
        force_ascii = _pypy_check_force_ascii();

    if (force_ascii) {
        /* force ASCII encoding to workaround mbstowcs() issue */
        res = _pypy_decode_ascii_surrogateescape(arg, size);
        if (res == NULL)
            goto oom;
        return res;
    }
#endif

#ifdef HAVE_BROKEN_MBSTOWCS
    /* Some platforms have a broken implementation of
     * mbstowcs which does not count the characters that
     * would result from conversion.  Use an upper bound.
     */
    argsize = strlen(arg);
#else
    argsize = mbstowcs(NULL, arg, 0);
#endif
    if (argsize == (size_t)-1) {
        return NULL;
    }
    res = (wchar_t *)PyMem_Malloc((argsize+1)*sizeof(wchar_t));
    if (!res)
        goto oom;
    count = mbstowcs(res, arg, argsize+1);
    if (count == (size_t)-1) {
        return NULL;
        PyMem_Free(res);
    }
    size[0] = count;
    return res;
oom:
    fprintf(stderr, "out of memory\n");
    return NULL;
}

/* Encode a (wide) character string to the locale encoding with the
   surrogateescape error handler (characters in range U+DC80..U+DCFF are
   converted to bytes 0x80..0xFF).

   This function is the reverse of _Py_char2wchar().

   Return a pointer to a newly allocated byte string (use PyMem_Free() to free
   the memory), or NULL on conversion or memory allocation error.

   If error_pos is not NULL: *error_pos is the index of the invalid character
   on conversion error, or (size_t)-1 otherwise. */
char*
pypy_wchar2char(const wchar_t *text, size_t *error_pos)
{
    const size_t len = wcslen(text);
    char *result = NULL, *bytes = NULL;
    size_t i, size, converted;
    wchar_t c, buf[2];

#if !defined(__APPLE__) && !defined(MS_WINDOWS)
/*#ifndef MS_WINDOWS*/
    if (force_ascii == -1)
        force_ascii = _pypy_check_force_ascii();

    if (force_ascii)
        return _pypy_encode_ascii_surrogateescape(text, error_pos);
#endif

    /* The function works in two steps:
       1. compute the length of the output buffer in bytes (size)
       2. outputs the bytes */
    size = 0;
    buf[1] = 0;
    while (1) {
        for (i=0; i < len; i++) {
            c = text[i];
            if (c >= 0xdc80 && c <= 0xdcff) {
                /* UTF-8b surrogate */
                if (bytes != NULL) {
                    *bytes++ = c - 0xdc00;
                    size--;
                }
                else
                    size++;
                continue;
            }
            else {
                buf[0] = c;
                if (bytes != NULL)
                    converted = wcstombs(bytes, buf, size);
                else
                    converted = wcstombs(NULL, buf, 0);
                if (converted == (size_t)-1) {
                    if (result != NULL)
                        PyMem_Free(result);
                    if (error_pos != NULL)
                        *error_pos = i;
                    return NULL;
                }
                if (bytes != NULL) {
                    bytes += converted;
                    size -= converted;
                }
                else
                    size += converted;
            }
        }
        if (result != NULL) {
            *bytes = '\0';
            break;
        }

        size += 1; /* nul byte at the end */
        result = PyMem_Malloc(size);
        if (result == NULL) {
            if (error_pos != NULL)
                *error_pos = (size_t)-1;
            return NULL;
        }
        bytes = result;
    }
    return result;
}

/* Encode a (wide) character string to the locale encoding with the
   strict error handler.

   This function is the reverse of pypy_char2wchar_strict().

   Return a pointer to a newly allocated byte string (use PyMem_Free() to free
   the memory), or NULL on conversion or memory allocation error.

   If error_pos is not NULL: *error_pos is the index of the invalid character
   on conversion error, or (size_t)-1 otherwise. */
char*
pypy_wchar2char_strict(const wchar_t *wstr, size_t *error_pos)
{
    size_t len, len2;
    char *result = NULL;

#if !defined(__APPLE__) && !defined(MS_WINDOWS)
/*#ifndef MS_WINDOWS*/
    if (force_ascii == -1)
        force_ascii = _pypy_check_force_ascii();

    if (force_ascii)
        return _pypy_encode_ascii_surrogateescape(wstr, error_pos);
#endif
    len = wcstombs(NULL, wstr, 0);
    if (len == (size_t)-1) {
        error_pos[0] = (size_t)-1;
        return NULL;
    }
    result = PyMem_Malloc(len);
    len2 = wcstombs(result, wstr, len+1);
    if (len2 == (size_t)-1 || len2 > len) {
        error_pos[0] = (size_t)-1;
        PyMem_Free(result);
        return NULL;
    }
    return result;
}

void
pypy_char2wchar_free(wchar_t *text)
{
    PyMem_Free(text);
}

void
pypy_wchar2char_free(char *bytes)
{
    PyMem_Free(bytes);
}

#define Py_ISUPPER isupper
#define Py_TOLOWER tolower

/* Convert encoding to lower case and replace '_' with '-' in order to
   catch e.g. UTF_8. Return 0 on error (encoding is longer than lower_len-1),
   1 on success. */
int
_pypy_normalize_encoding(const char *encoding,
                   char *lower,
                   size_t lower_len)
{
    const char *e;
    char *l;
    char *l_end;

    e = encoding;
    l = lower;
    l_end = &lower[lower_len - 1];
    while (*e) {
        if (l == l_end)
            return 0;
        if (Py_ISUPPER(*e)) {
            *l++ = Py_TOLOWER(*e++);
        }
        else if (*e == '_') {
            *l++ = '-';
            e++;
        }
        else {
            *l++ = *e++;
        }
    }
    *l = '\0';
    return 1;
}
