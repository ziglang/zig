#include <assert.h>
#include <objc/runtime.h>

int main() {
  assert(objc_getClass("NSObject") > 0);
  assert(objc_getClass("NSApplication") > 0);
}
