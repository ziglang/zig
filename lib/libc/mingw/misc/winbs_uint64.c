unsigned long long __cdecl _byteswap_uint64(unsigned long long _Int64);

unsigned long long __cdecl _byteswap_uint64(unsigned long long _Int64)
{
#if defined(_AMD64_) || defined(__x86_64__)
  unsigned long long retval;
  __asm__ __volatile__ ("bswapq %[retval]" : [retval] "=rm" (retval) : "[retval]" (_Int64));
  return retval;
#elif defined(_X86_) || defined(__i386__)
  union {
    long long int64part;
    struct {
      unsigned long lowpart;
      unsigned long hipart;
    };
  } retval;
  retval.int64part = _Int64;
  __asm__ __volatile__ ("bswapl %[lowpart]\n"
    "bswapl %[hipart]\n"
    : [lowpart] "=rm" (retval.hipart), [hipart] "=rm" (retval.lowpart)  : "[lowpart]" (retval.lowpart), "[hipart]" (retval.hipart));
  return retval.int64part;
#else
  unsigned char *b = (void*)&_Int64;
  unsigned char tmp;
  tmp = b[0];
  b[0] = b[7];
  b[7] = tmp;
  tmp = b[1];
  b[1] = b[6];
  b[6] = tmp;
  tmp = b[2];
  b[2] = b[5];
  b[5] = tmp;
  tmp = b[3];
  b[3] = b[4];
  b[4] = tmp;
  return _Int64;
#endif
}
