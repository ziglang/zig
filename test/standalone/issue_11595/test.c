 #include <string.h>

int check(void) {
    if (FOO != 42) return 1;
    if (strcmp(BAR, "BAR")) return 2;
    if (strcmp(BAZ, "\"BAZ\"")) return 3;
    if (strcmp(QUX, "QUX")) return 4;
    if (strcmp(QUUX, "QU\"UX")) return 5;
    return 0;
}
