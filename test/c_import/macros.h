// initializer list expression
typedef struct Color {
    unsigned char r;
    unsigned char g;
    unsigned char b;
    unsigned char a;
} Color;
#define CLITERAL(type)      (type)
#define LIGHTGRAY  CLITERAL(Color){ 200, 200, 200, 255 }   // Light Gray

#define MY_SIZEOF(x) ((int)sizeof(x))
#define MY_SIZEOF2(x) ((int)sizeof x)

struct Foo {
    int a;
};

union U {
    long l;
    double d;
};

#define SIZE_OF_FOO sizeof(struct Foo)

#define MAP_FAILED	((void *) -1)

#define IGNORE_ME_1(x) ((void)(x))
#define IGNORE_ME_2(x) ((const void)(x))
#define IGNORE_ME_3(x) ((volatile void)(x))
#define IGNORE_ME_4(x) ((const volatile void)(x))
#define IGNORE_ME_5(x) ((volatile const void)(x))

#define IGNORE_ME_6(x) (void)(x)
#define IGNORE_ME_7(x) (const void)(x)
#define IGNORE_ME_8(x) (volatile void)(x)
#define IGNORE_ME_9(x) (const volatile void)(x)
#define IGNORE_ME_10(x) (volatile const void)(x)

#define UNION_CAST(X) (union U)(X)
#define CAST_OR_CALL_WITH_PARENS(type_or_fn, val) ((type_or_fn)(val))

#define NESTED_COMMA_OPERATOR (1, (2, 3))
#define NESTED_COMMA_OPERATOR_LHS (1, 2), 3

#include <stdint.h>
#if !defined(__UINTPTR_MAX__)
typedef _Bool uintptr_t;
#endif

#define CAST_TO_BOOL(X) (_Bool)(X)
#define CAST_TO_UINTPTR(X) (uintptr_t)(X)

#define LARGE_INT 18446744073709550592

#define EMBEDDED_TAB "hello	"

#define DIVIDE_CONSTANT(version) (version / 1000)
#define DIVIDE_ARGS(A, B) (A / B)

#define REMAINDER_CONSTANT(version) (version % 10000)
#define REMAINDER_ARGS(A, B) (A % B)

#define LONG(x) x##L
#define X LONG(10)

#define BLANK_MACRO
#define BLANK_CHILD_MACRO BLANK_MACRO BLANK_MACRO BLANK_MACRO
#define MACRO_VALUE 0
typedef long def_type;
#define BLANK_MACRO_CAST (BLANK_CHILD_MACRO def_type BLANK_CHILD_MACRO)MACRO_VALUE
