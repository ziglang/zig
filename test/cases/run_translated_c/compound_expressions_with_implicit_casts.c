int main() {
  int i = 2;
  float f = 2.0f;
  
  i += 1.5;
  i += f;

  f += 2UL;
  f += i;

  return 0;
}

// run-translated-c
// c_frontends=clang
