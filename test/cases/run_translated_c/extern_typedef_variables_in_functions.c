const int ev = 40;

static int func(void)
{
  typedef int test_type_t;
  extern const test_type_t ev;
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
