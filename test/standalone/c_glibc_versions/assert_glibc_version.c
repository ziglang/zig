#include <stdio.h>

int main(int argc, char *argv[])
{
#if !defined(EXPECTED_GLIBC_MAJOR) || !defined(EXPECTED_GLIBC_MINOR)
    #error "expected glibc version not defined"
#endif

    _Static_assert(__GLIBC__ == EXPECTED_GLIBC_MAJOR, "unexpected major version of glibc");
    _Static_assert(__GLIBC_MINOR__ == EXPECTED_GLIBC_MINOR, "unexpected minor version of glibc");

    return 0;
}
