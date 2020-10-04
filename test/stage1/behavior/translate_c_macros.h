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
