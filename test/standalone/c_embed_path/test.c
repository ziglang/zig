
#include <stdlib.h>
#include <string.h>
int main(void) {
    // Raw bytes; not a C string
    const char data[] = {
#embed <foo.data>
    };
    const char *expected = "This text is the contents of foo.data";
    if (sizeof data == strlen(expected) && memcmp(data, expected, sizeof data) == 0) {
        return EXIT_SUCCESS;
    } else {
        return EXIT_FAILURE;
    }
}
