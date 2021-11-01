#include <cassert>
#include <iostream>

#ifndef _LIBCPP_HAS_NO_THREADS
#include <future>
#endif

thread_local unsigned int tls_counter = 1;

// a non-optimized way of checking for prime numbers:
bool is_prime(int x) {
  for (int i = 2; i <x ; ++i) {
    if (x % i == 0) {
      return false;
    }
  }
  return true;
}

class CTest {
public:
  CTest(int val) : m_val(val) {
    tls_counter++;
  };
  virtual ~CTest() {}

  virtual int getVal() const { return m_val; }
  virtual void printVal() { std::cout << "val=" << m_val << std::endl; }
private:
  int m_val;
};

int main (int argc, char *argv[])
{
  auto t = std::make_unique<CTest>(123);
  assert(t->getVal() != 456);
  assert(tls_counter == 2);
  if (argc > 1) {
    t->printVal();
  }
  bool ok = t->getVal() == 123;

  if (!ok) abort();

#ifndef _LIBCPP_HAS_NO_THREADS
  std::future<bool> fut = std::async(is_prime, 313);
  bool ret = fut.get();
  assert(ret);
#endif

#ifndef _LIBCPP_NO_EXCEPTIONS
  try {
    throw 20;
  } catch (int e) {
    assert(e == 20);
  }
#endif

  return EXIT_SUCCESS;
}
