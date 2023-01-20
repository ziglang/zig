#include "all.h"
#include <cstdio>

void fn_c() {
  SimpleStringOwner c{ "cccccccccc" };
}

void fn_b() {
  SimpleStringOwner b{ "b" };
  fn_c();
}

int main() {
  try {
    SimpleStringOwner a{ "a" };
    fn_b();
    SimpleStringOwner d{ "d" };
  } catch (const Error& e) {
    printf("Error: %s\n", e.what());
  } catch(const std::exception& e) {
    printf("Exception: %s\n", e.what());
  }
  return 0;
}
