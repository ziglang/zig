#include <objc/runtime.h>

int main() {
  if (objc_getClass("NSObject") == 0) {
    return -1;
  }
  if (objc_getClass("NSApplication") == 0) {
    return -2;
  }
}
