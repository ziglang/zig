
extern "C" int add_C_header(int x, int a);

#ifdef IMPLEMENTATION

int add_C_header(int x, int a) {
    return x+a;
}

#endif
