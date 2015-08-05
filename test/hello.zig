#include <stdio.h>
#include "add.h"

int main(int argc, char **argv) {
    fprintf(stderr, "hello: %d", add(1, 2));
}
