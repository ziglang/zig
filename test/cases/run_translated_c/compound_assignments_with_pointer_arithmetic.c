int main() {
  const char *s = "forgreatjustice";
  unsigned int add = 1;
  
  s += add;
  if (*s != 'o') return 1;

  s += 1UL;
  if (*s != 'r') return 2;

  const char *s2 = (s += add);
  if (*s2 != 'g') return 3;

  s2 -= add;
  if (*s2 != 'r') return 4;

  return 0;
}

// run-translated-c
// c_frontend=clang
