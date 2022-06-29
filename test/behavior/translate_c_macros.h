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
