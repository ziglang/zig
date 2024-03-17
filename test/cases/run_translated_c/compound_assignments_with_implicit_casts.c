int main() {
  int i = 2;
  float f = 3.2f;
  
  i += 1.7;
  if (i != 3) return 1;
  i += f;
  if (i != 6) return 2;


  f += 2UL;
  if (f <= 5.1999 || f >= 5.2001) return 3;
  f += i;
  if (f <= 11.1999 || f >= 11.2001) return 4;

  return 0;
}

// run-translated-c
// c_frontend=clang
