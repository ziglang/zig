/**
 * Implementation of HPyArg_Parse and HPyArg_ParseKeywords.
 *
 * HPyArg_Parse parses positional arguments and replaces PyArg_ParseTuple.
 * HPyArg_ParseKeywords parses positional and keyword arguments and
 * replaces PyArg_ParseTupleAndKeywords.
 *
 * HPy intends to only support the simpler format string types (numbers, bools)
 * and handles. More complex types (e.g. buffers) should be retrieved as
 * handles and then processed further as needed.
 *
 * Supported Formatting Strings
 * ----------------------------
 *
 * Numbers
 * ~~~~~~~
 *
 * ``b (int) [unsigned char]``
 *     Convert a nonnegative Python integer to an unsigned tiny int, stored in a C unsigned char.
 *
 * ``B (int) [unsigned char]``
 *     Convert a Python integer to a tiny int without overflow checking, stored in a C unsigned char.
 *
 * ``h (int) [short int]``
 *     Convert a Python integer to a C short int.
 *
 * ``H (int) [unsigned short int]``
 *     Convert a Python integer to a C unsigned short int, without overflow checking.
 *
 * ``i (int) [int]``
 *     Convert a Python integer to a plain C int.
 *
 * ``I (int) [unsigned int]``
 *     Convert a Python integer to a C unsigned int, without overflow checking.
 *
 * ``l (int) [long int]``
 *     Convert a Python integer to a C long int.
 *
 * ``k (int) [unsigned long]``
 *     Convert a Python integer to a C unsigned long without overflow checking.
 *
 * ``L (int) [long long]``
 *     Convert a Python integer to a C long long.
 *
 * ``K (int) [unsigned long long]``
 *     Convert a Python integer to a C unsigned long long without overflow checking.
 *
 * ``n (int) [HPy_ssize_t]``
 *     Convert a Python integer to a C HPy_ssize_t.
 *
 * ``f (float) [float]``
 *     Convert a Python floating point number to a C float.
 *
 * ``d (float) [double]``
 *     Convert a Python floating point number to a C double.
 *
 * Strings and buffers
 * ~~~~~~~~~~~~~~~~~~~~~~~~
 *
 * These formats allow accessing an object as a contiguous chunk of memory.
 * You don't have to provide raw storage for the returned unicode or bytes
 * area.
 *
 * In general, when a format sets a pointer to a buffer, the pointer is valid
 * only until the corresponding HPy handle is closed.
 *
 * ``s (unicode) [const char*]``
 *
 * Convert a Unicode object to a C pointer to a character string.
 * A pointer to an existing string is stored in the character pointer
 * variable whose address you pass.  The C string is NUL-terminated.
 * The Python string must not contain embedded null code points; if it does,
 * a `ValueError` exception is raised. Unicode objects are converted
 * to C strings using 'utf-8' encoding. If this conversion fails,
 * a `UnicodeError` is raised.
 *
 * Note: This format does not accept bytes-like objects and is therefore
 * not suitable for filesystem paths.
 *
 * Handles (Python Objects)
 * ~~~~~~~~~~~~~~~~~~~~~~~~
 *
 * ``O (object) [HPy]``
 *     Store a handle pointing to a generic Python object.
 *
 *     When using O with HPyArg_ParseKeywords, an HPyTracker is created and
 *     returned via the parameter `ht`. If HPyArg_ParseKeywords returns
 *     successfully, you must call HPyTracker_Close on `ht` once the
 *     returned handles are no longer needed. This will close all the handles
 *     created during argument parsing. There is no need to call
 *     `HPyTracker_Close` on failure -- the argument parser does this for you.
 *
 * Miscellaneous
 * ~~~~~~~~~~~~~
 *
 * ``p (bool) [int]``
 *     Tests the value passed in for truth (a boolean predicate) and converts
 *     the result to its equivalent C true/false integer value. Sets the int to
 *     1 if the expression was true and 0 if it was false. This accepts any
 *     valid Python value. See
 *     `Truth Value Testing <https://docs.python.org/3/library/stdtypes.html#truth>`_
 *     for more information about how Python tests values for truth.
 *
 * Options
 * ~~~~~~~
 *
 * ``|``
 *     Indicates that the remaining arguments in the argument list are optional.
 *     The C variables corresponding to optional arguments should be initialized
 *     to their default value — when an optional argument is not specified, the
 *     contents of the corresponding C variable is not modified.
 *
 * ``$``
 *     HPyArg_ParseKeywords() only: Indicates that the remaining arguments in
 *     the argument list are keyword-only. Currently, all keyword-only arguments
 *     must also be optional arguments, so | must always be specified before $
 *     in the format string.
 *
 * ``:``
 *     The list of format units ends here; the string after the colon is used as
 *     the function name in error messages. : and ; are mutually exclusive and
 *     whichever occurs first takes precedence.
 *
 * ``;``
 *     The list of format units ends here; the string after the semicolon is
 *     used as the error message instead of the default error message. : and ;
 *     are mutually exclusive and whichever occurs first takes precedence.
 *
 * Argument Parsing API
 * --------------------
 *
 */

#include <limits.h>
#include <stdio.h>
#include "hpy.h"

#define _BREAK_IF_OPTIONAL(current_arg) if (HPy_IsNull(current_arg)) break;
#define _ERR_STRING_MAX_LENGTH 512


static const char *
parse_err_fmt(const char *fmt, const char **err_fmt)
{
    const char *fmt1 = fmt;

    for (; *fmt1 != 0; fmt1++) {
        if (*fmt1 == ':' || *fmt1 == ';') {
            *err_fmt = fmt1;
            break;
        }
    }
    return fmt1;
}


static void
set_error(HPyContext *ctx, HPy exc, const char *err_fmt, const char *msg) {
    char err_buf[_ERR_STRING_MAX_LENGTH];
    if (err_fmt == NULL) {
        snprintf(err_buf, _ERR_STRING_MAX_LENGTH, "function %.256s", msg);
    }
    else if (*err_fmt == ':') {
        snprintf(err_buf, _ERR_STRING_MAX_LENGTH, "%.200s() %.256s", err_fmt + 1, msg);
    }
    else {
        snprintf(err_buf, _ERR_STRING_MAX_LENGTH, "%s", err_fmt + 1);
    }
    HPyErr_SetString(ctx, exc, err_buf);
}


static int
parse_item(HPyContext *ctx, HPyTracker *ht, HPy current_arg, int current_arg_tmp, const char **fmt, va_list *vl, const char *err_fmt)
{
    switch (*(*fmt)++) {

    case 'b': { /* unsigned byte -- very short int */
        char *output = va_arg(*vl, char *);
        _BREAK_IF_OPTIONAL(current_arg);
        long value = HPyLong_AsLong(ctx, current_arg);
        if (value == -1 && HPyErr_Occurred(ctx))
            return 0;
        if (value < 0) {
            set_error(ctx, ctx->h_OverflowError, err_fmt,
                "unsigned byte integer is less than minimum");
            return 0;
        }
        if (value > UCHAR_MAX) {
            set_error(ctx, ctx->h_OverflowError, err_fmt,
                "unsigned byte integer is greater than maximum");
            return 0;
        }
        *output = (char) value;
        break;
    }

    case 'B': { /* byte sized bitfield - both signed and unsigned
                   values allowed */
        char *output = va_arg(*vl, char *);
        _BREAK_IF_OPTIONAL(current_arg);
        unsigned long value = HPyLong_AsUnsignedLongMask(ctx, current_arg);
        if (value == (unsigned long)-1 && HPyErr_Occurred(ctx))
            return 0;
        *output = (unsigned char) value;
        break;
    }

    case 'h': { /* signed short int */
        short *output = va_arg(*vl, short *);
        _BREAK_IF_OPTIONAL(current_arg);
        long value = HPyLong_AsLong(ctx, current_arg);
        if (value == -1 && HPyErr_Occurred(ctx))
            return 0;
        if (value < SHRT_MIN) {
            set_error(ctx, ctx->h_OverflowError, err_fmt,
                "signed short integer is less than minimum");
            return 0;
        }
        if (value > SHRT_MAX) {
            set_error(ctx, ctx->h_OverflowError, err_fmt,
                "signed short integer is greater than maximum");
            return 0;
        }
        *output = (short) value;
        break;
    }

    case 'H': { /* short int sized bitfield, both signed and
                   unsigned allowed */
        unsigned short *output = va_arg(*vl, unsigned short *);
        _BREAK_IF_OPTIONAL(current_arg);
        unsigned long value = HPyLong_AsUnsignedLongMask(ctx, current_arg);
        if (value == (unsigned long)-1 && HPyErr_Occurred(ctx))
            return 0;
        *output = (unsigned short) value;
        break;
    }

    case 'i': { /* signed int */
        int *output = va_arg(*vl, int *);
        _BREAK_IF_OPTIONAL(current_arg);
        long value = HPyLong_AsLong(ctx, current_arg);
        if (value == -1 && HPyErr_Occurred(ctx))
            return 0;
        if (value > INT_MAX) {
            set_error(ctx, ctx->h_OverflowError, err_fmt,
                "signed integer is greater than maximum");
            return 0;
        }
        if (value < INT_MIN) {
            set_error(ctx, ctx->h_OverflowError, err_fmt,
                "signed integer is less than minimum");
            return 0;
        }
        *output = (int)value;
        break;
    }

    case 'I': { /* int sized bitfield, both signed and
                   unsigned allowed */
        unsigned int *output = va_arg(*vl, unsigned int *);
        _BREAK_IF_OPTIONAL(current_arg);
        unsigned long value = HPyLong_AsUnsignedLongMask(ctx, current_arg);
        if (value == (unsigned long)-1 && HPyErr_Occurred(ctx))
            return 0;
        *output = (unsigned int) value;
        break;
    }

    case 'l': {
        long *output = va_arg(*vl, long *);
        _BREAK_IF_OPTIONAL(current_arg);
        long value = HPyLong_AsLong(ctx, current_arg);
        if (value == -1 && HPyErr_Occurred(ctx))
            return 0;
        *output = value;
        break;
    }

    case 'k': { /* long sized bitfield */
        unsigned long *output = va_arg(*vl, unsigned long *);
        _BREAK_IF_OPTIONAL(current_arg);
        unsigned long value = HPyLong_AsUnsignedLongMask(ctx, current_arg);
        if (value == (unsigned long)-1 && HPyErr_Occurred(ctx))
            return 0;
        *output = value;
        break;
    }

    case 'L': { /* long long */
        long long *output = va_arg(*vl, long long *);
        _BREAK_IF_OPTIONAL(current_arg);
        long long value = HPyLong_AsLongLong(ctx, current_arg);
        if (value == (long long)-1 && HPyErr_Occurred(ctx))
            return 0;
        *output = value;
        break;
    }

    case 'K': { /* long long sized bitfield */
        unsigned long long *output = va_arg(*vl, unsigned long long *);
        _BREAK_IF_OPTIONAL(current_arg);
        unsigned long long value = HPyLong_AsUnsignedLongLongMask(ctx, current_arg);
        if (value == (unsigned long long)-1 && HPyErr_Occurred(ctx))
            return 0;
        *output = value;
        break;
    }

    case 'n': { /* HPy_ssize_t */
        HPy_ssize_t *output = va_arg(*vl, HPy_ssize_t *);
        _BREAK_IF_OPTIONAL(current_arg);
        HPy_ssize_t value = HPyLong_AsSsize_t(ctx, current_arg);
        if (value == (HPy_ssize_t)-1 && HPyErr_Occurred(ctx))
            return 0;
        *output = value;
        break;
    }

    case 'f': { /* float */
        float *output = va_arg(*vl, float *);
        _BREAK_IF_OPTIONAL(current_arg);
        double value = HPyFloat_AsDouble(ctx, current_arg);
        if (value == -1.0 && HPyErr_Occurred(ctx))
            return 0;
        *output = (float) value;
        break;
    }

    case 'd': { /* double */
        double* output = va_arg(*vl, double *);
        _BREAK_IF_OPTIONAL(current_arg);
        double value = HPyFloat_AsDouble(ctx, current_arg);
        if (value == -1.0 && HPyErr_Occurred(ctx))
            return 0;
        *output = value;
        break;
    }

    case 'O': {
        HPy *output = va_arg(*vl, HPy *);
        _BREAK_IF_OPTIONAL(current_arg);
        if (current_arg_tmp) {
            *output = HPy_Dup(ctx, current_arg);
            HPyTracker_Add(ctx, *ht, *output);
        }
        else {
            *output = current_arg;
        }
        break;
    }

    case 'p': { /* boolean *p*redicate */
        int *output = va_arg(*vl, int *);
        int value = HPy_IsTrue(ctx, current_arg);
        if (value < 0)
            return 0;
        *output = (value > 0) ? 1 : 0;
        break;
    }

    case 's': {
        const char **output = va_arg(*vl, const char **);
        if (!HPyUnicode_Check(ctx, current_arg)) {
            set_error(ctx, ctx->h_TypeError, err_fmt, "a str is required");
            return 0;
        }
        HPy_ssize_t size;
        const char *data = HPyUnicode_AsUTF8AndSize(ctx, current_arg, &size);
        if (data == NULL) {
            set_error(ctx, ctx->h_SystemError, err_fmt, "unicode conversion error");
            return 0;
        }
        // loop bounded by size is more robust/paranoid than strlen
        HPy_ssize_t i;
        for (i = 0; i < size; ++i) {
            if (data[i] == '\0') {
                set_error(ctx, ctx->h_ValueError, err_fmt, "embedded null character");
                return 0;
            }
        }
        if (data[i] != '\0') {
            set_error(ctx, ctx->h_SystemError, err_fmt, "missing terminating null character");
            return 0;
        }
        *output = data;
        break;
    }

    default: {
        set_error(ctx, ctx->h_SystemError, err_fmt, "unknown arg format code");
        return 0;
    }

    } // switch

    return 1;
}


/**
 * Parse positional arguments.
 *
 * :param ctx:
 *     The execution context.
 * :param ht:
 *     An optional pointer to an HPyTracker. If the format string never
 *     results in new handles being created, `ht` may be `NULL`. Currently
 *     no formatting options to this function require an HPyTracker.
 * :param args:
 *     The array of positional arguments to parse.
 * :param nargs:
 *     The number of elements in args.
 * :param fmt:
 *     The format string to use to parse the arguments.
 * :param ...:
 *     A va_list of references to variables in which to store the parsed
 *     arguments. The number and types of the arguments should match the
 *     the format strint, `fmt`.
 *
 * :returns: 0 on failure, 1 on success.
 *
 * If a `NULL` pointer is passed to `ht` and an `HPyTracker` is required by
 * the format string, an exception will be raised.
 *
 * If a pointer is provided to `ht`, the `HPyTracker` will always be created
 * and must be closed with `HPyTracker_Close` if parsing succeeds (after all
 * handles returned are no longer needed). If parsing fails, this function
 * will close the `HPyTracker` automatically.
 *
 * Examples:
 *
 * Using `HPyArg_Parse` without an `HPyTracker`:
 *
 * .. code-block:: c
 *
 *     long a, b;
 *     if (!HPyArg_Parse(ctx, NULL, args, nargs, "ll", &a, &b))
 *         return HPy_NULL;
 *     ...
 *
 * Using `HPyArg_Parse` with an `HPyTracker`:
 *
 * .. code-block:: c
 *
 *     long a, b;
 *     HPyTracker ht;
 *     if (!HPyArg_Parse(ctx, &ht, args, nargs, "ll", &a, &b))
 *         return HPy_NULL;
 *     ...
 *     HPyTracker_Close(ctx, ht);
 *     ...
 *
 * .. note::
 *
 *    Currently `HPyArg_Parse` never requires the use of an `HPyTracker`.
 *    The option exists only to support releasing temporary storage used by
 *    future format string codes (e.g. for character strings).
 */
HPyAPI_HELPER int
HPyArg_Parse(HPyContext *ctx, HPyTracker *ht, HPy *args, HPy_ssize_t nargs, const char *fmt, ...)
{
    const char *fmt1 = fmt;
    const char *err_fmt = NULL;
    const char *fmt_end = NULL;

    int optional = 0;
    HPy_ssize_t i = 0;
    HPy current_arg;

    fmt_end = parse_err_fmt(fmt, &err_fmt);

    if (ht != NULL) {
        *ht = HPyTracker_New(ctx, 0);
        if (HPy_IsNull(*ht)) {
            return 0;
        }
    }

    va_list vl;
    va_start(vl, fmt);

    while (fmt1 != fmt_end) {
        if (*fmt1 == '|') {
            optional = 1;
            fmt1++;
            continue;
        }
        current_arg = HPy_NULL;
        if (i < nargs) {
            current_arg = args[i];
        }
        if (!HPy_IsNull(current_arg) || optional) {
            if (!parse_item(ctx, ht, current_arg, 0, &fmt1, &vl, err_fmt)) {
                goto error;
            }
        }
        else {
            set_error(ctx, ctx->h_TypeError, err_fmt,
                "required positional argument missing");
            goto error;
        }
        i++;
    }
    if (i < nargs) {
        set_error(ctx, ctx->h_TypeError, err_fmt,
            "mismatched args (too many arguments for fmt)");
        goto error;
    }

    va_end(vl);
    return 1;

    error:
        va_end(vl);
        if (ht != NULL) {
            HPyTracker_Close(ctx, *ht);
        }
        return 0;
}


/**
 * Parse positional and keyword arguments.
 *
 * :param ctx:
 *     The execution context.
 * :param ht:
 *     An optional pointer to an HPyTracker. If the format string never
 *     results in new handles being created, `ht` may be `NULL`. Currently
 *     only the `O` formatting option to this function requires an HPyTracker.
 * :param args:
 *     The array of positional arguments to parse.
 * :param nargs:
 *     The number of elements in args.
 * :param kw:
 *     A handle to the dictionary of keyword arguments.
 * :param fmt:
 *     The format string to use to parse the arguments.
 * :param keywords:
 *     An `NULL` terminated array of argument names. The number of names
 *     should match the format string provided. Positional only arguments
 *     should have the name `""` (i.e. the null-terminated empty string).
 *     Positional only arguments must preceded all other arguments.
 * :param ...:
 *     A va_list of references to variables in which to store the parsed
 *     arguments. The number and types of the arguments should match the
 *     the format strint, `fmt`.
 *
 * :returns: 0 on failure, 1 on success.
 *
 * If a `NULL` pointer is passed to `ht` and an `HPyTracker` is required by
 * the format string, an exception will be raised.
 *
 * If a pointer is provided to `ht`, the `HPyTracker` will always be created
 * and must be closed with `HPyTracker_Close` if parsing succeeds (after all
 * handles returned are no longer needed). If parsing fails, this function
 * will close the `HPyTracker` automatically.
 *
 * Examples:
 *
 * Using `HPyArg_ParseKeywords` without an `HPyTracker`:
 *
 * .. code-block:: c
 *
 *     long a, b;
 *     if (!HPyArg_ParseKeywords(ctx, NULL, args, nargs, kw, "ll", &a, &b))
 *         return HPy_NULL;
 *     ...
 *
 * Using `HPyArg_ParseKeywords` with an `HPyTracker`:
 *
 * .. code-block:: c
 *
 *     HPy a, b;
 *     HPyTracker ht;
 *     if (!HPyArg_ParseKeywords(ctx, &ht, args, nargs, kw, "OO", &a, &b))
 *         return HPy_NULL;
 *     ...
 *     HPyTracker_Close(ctx, ht);
 *     ...
 *
 * .. note::
 *
 *     Currently `HPyArg_ParseKeywords` only requires the use of an `HPyTracker`
 *     when the `O` format is used. In future other new format string codes
 *     (e.g. for character strings) may also require it.
 */
HPyAPI_HELPER int
HPyArg_ParseKeywords(HPyContext *ctx, HPyTracker *ht, HPy *args, HPy_ssize_t nargs, HPy kw,
                     const char *fmt, const char *keywords[], ...)
{
    const char *fmt1 = fmt;
    const char *err_fmt = NULL;
    const char *fmt_end = NULL;

    int optional = 0;
    int keyword_only = 0;
    HPy_ssize_t i = 0;
    HPy_ssize_t nkw = 0;
    HPy current_arg;
    int current_arg_needs_closing = 0;

    fmt_end = parse_err_fmt(fmt, &err_fmt);

    // first count positional only arguments
    while (keywords[nkw] != NULL && !*keywords[nkw]) {
        nkw++;
    }
    // then check and count the rest
    while (keywords[nkw] != NULL) {
        if (!*keywords[nkw]) {
            set_error(ctx, ctx->h_SystemError, err_fmt,
                "empty keyword parameter name");
            return 0;
        }
        nkw++;
    }

    if (ht != NULL) {
        *ht = HPyTracker_New(ctx, 0);
        if (HPy_IsNull(*ht)) {
            return 0;
        }
    }

    va_list vl;
    va_start(vl, keywords);

    while (fmt1 != fmt_end) {
        if (*fmt1 == '|') {
            optional = 1;
            fmt1++;
            continue;
        }
        if (*fmt1 == '$') {
            optional = 1;
            keyword_only = 1;
            fmt1++;
            continue;
        }
        if (*fmt1 == 'O' && ht == NULL) {
            set_error(ctx, ctx->h_SystemError, err_fmt,
                "HPyArg_ParseKeywords cannot use the format character 'O' unless"
                " an HPyTracker is provided. Please supply an HPyTracker.");
            goto error;
        }
        if (i >= nkw) {
            set_error(ctx, ctx->h_TypeError, err_fmt,
                "mismatched args (too few keywords for fmt)");
            goto error;
        }
        current_arg = HPy_NULL;
        if (i < nargs) {
            if (keyword_only) {
                set_error(ctx, ctx->h_TypeError, err_fmt,
                    "keyword only argument passed as positional argument");
                goto error;
            }
            current_arg = args[i];
        }
        else if (!HPy_IsNull(kw) && *keywords[i]) {
            current_arg = HPy_GetItem_s(ctx, kw, keywords[i]);
            // Track the handle or lear any KeyError that was raised. If an
            // error was raised current_arg will be HPy_NULL and will be
            // handled appropriately below depending on whether the current
            // argument is optional or not
            if (!HPy_IsNull(current_arg)) {
                current_arg_needs_closing = 1;
            }
            else {
                HPyErr_Clear(ctx);
            }
        }
        if (!HPy_IsNull(current_arg) || optional) {
            if (!parse_item(ctx, ht, current_arg, 1, &fmt1, &vl, err_fmt)) {
                goto error;
            }
        }
        else {
            set_error(ctx, ctx->h_TypeError, err_fmt,
                "no value for required argument");
            goto error;
        }
        if (current_arg_needs_closing) {
            HPy_Close(ctx, current_arg);
            current_arg_needs_closing = 0;
        }
        i++;
    }
    if (i != nkw) {
        set_error(ctx, ctx->h_TypeError, err_fmt,
            "mismatched args (too many keywords for fmt)");
        goto error;
    }

    va_end(vl);
    return 1;

    error:
        va_end(vl);
        if (ht != NULL) {
            HPyTracker_Close(ctx, *ht);
        }
        if (current_arg_needs_closing) {
            HPy_Close(ctx, current_arg);
        }
        return 0;
}
