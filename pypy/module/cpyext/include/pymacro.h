#ifndef Py_PYMACRO_H
#define Py_PYMACRO_H

/* Minimum value between x and y */
#define Py_MIN(x, y) (((x) > (y)) ? (y) : (x))

/* Maximum value between x and y */
#define Py_MAX(x, y) (((x) > (y)) ? (x) : (y))

/* Absolute value of the number x */
#define Py_ABS(x) ((x) < 0 ? -(x) : (x))

#define _Py_XSTRINGIFY(x) #x

/* Convert the argument to a string. For example, Py_STRINGIFY(123) is replaced
   with "123" by the preprocessor. Defines are also replaced by their value.
   For example Py_STRINGIFY(__LINE__) is replaced by the line number, not
   by "__LINE__". */
#define Py_STRINGIFY(x) _Py_XSTRINGIFY(x)

/* Get the size of a structure member in bytes */
#define Py_MEMBER_SIZE(type, member) sizeof(((type *)0)->member)

/* Argument must be a char or an int in [-128, 127] or [0, 255]. */
#define Py_CHARMASK(c) ((unsigned char)((c) & 0xff))

/* Assert a build-time dependency, as an expression.

   Your compile will fail if the condition isn't true, or can't be evaluated
   by the compiler. This can be used in an expression: its value is 0.

   Example:

   #define foo_to_char(foo)  \
       ((char *)(foo)        \
        + Py_BUILD_ASSERT_EXPR(offsetof(struct foo, string) == 0))

   Written by Rusty Russell, public domain, http://ccodearchive.net/ */
#define Py_BUILD_ASSERT_EXPR(cond) \
    (sizeof(char [1 - 2*!(cond)]) - 1)

#define Py_BUILD_ASSERT(cond)  do {         \
        (void)Py_BUILD_ASSERT_EXPR(cond);   \
    } while(0)

/* Get the number of elements in a visible array

   This does not work on pointers, or arrays declared as [], or function
   parameters. With correct compiler support, such usage will cause a build
   error (see Py_BUILD_ASSERT_EXPR).

   Written by Rusty Russell, public domain, http://ccodearchive.net/

   Requires at GCC 3.1+ */
#if (defined(__GNUC__) && !defined(__STRICT_ANSI__) && \
    (((__GNUC__ == 3) && (__GNU_MINOR__ >= 1)) || (__GNUC__ >= 4)))
/* Two gcc extensions.
   &a[0] degrades to a pointer: a different type from an array */
#define Py_ARRAY_LENGTH(array) \
    (sizeof(array) / sizeof((array)[0]) \
     + Py_BUILD_ASSERT_EXPR(!__builtin_types_compatible_p(typeof(array), \
                                                          typeof(&(array)[0]))))
#else
#define Py_ARRAY_LENGTH(array) \
    (sizeof(array) / sizeof((array)[0]))
#endif


/* Define macros for inline documentation. */
#define PyDoc_VAR(name) static char name[]
#define PyDoc_STRVAR(name,str) PyDoc_VAR(name) = PyDoc_STR(str)
#ifdef WITH_DOC_STRINGS
#define PyDoc_STR(str) str
#else
#define PyDoc_STR(str) ""
#endif

/* Below "a" is a power of 2. */
/* Round down size "n" to be a multiple of "a". */
#define _Py_SIZE_ROUND_DOWN(n, a) ((size_t)(n) & ~(size_t)((a) - 1))
/* Round up size "n" to be a multiple of "a". */
#define _Py_SIZE_ROUND_UP(n, a) (((size_t)(n) + \
        (size_t)((a) - 1)) & ~(size_t)((a) - 1))
/* Round pointer "p" down to the closest "a"-aligned address <= "p". */
#define _Py_ALIGN_DOWN(p, a) ((void *)((uintptr_t)(p) & ~(uintptr_t)((a) - 1)))
/* Round pointer "p" up to the closest "a"-aligned address >= "p". */
#define _Py_ALIGN_UP(p, a) ((void *)(((uintptr_t)(p) + \
        (uintptr_t)((a) - 1)) & ~(uintptr_t)((a) - 1)))
/* Check if pointer "p" is aligned to "a"-bytes boundary. */
#define _Py_IS_ALIGNED(p, a) (!((uintptr_t)(p) & (uintptr_t)((a) - 1)))

#ifdef __GNUC__
#define Py_UNUSED(name) _unused_ ## name __attribute__((unused))
#else
#define Py_UNUSED(name) _unused_ ## name
#endif

#endif /* Py_PYMACRO_H */
