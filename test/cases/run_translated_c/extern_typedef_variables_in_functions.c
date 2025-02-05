const int ev = 40;

static int func(void)
{
  typedef int test_type_t;
  extern const test_type_t ev;
  // Ensure mangled name is also being used for conditions and loops, see #20828
  if (ev == 0);
  while (ev == 0);
  do; while (ev == 0);
  return ev + 2;
}

int main()
{
  if (func() != 42)
    return 1;
  return 0;
}

// run-translated-c
// c_frontend=clang
