unsigned long __cdecl _byteswap_ulong (unsigned long _Long);

unsigned long __cdecl _byteswap_ulong (unsigned long _Long)
{
#if defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__)
  unsigned long retval;
  __asm__ __volatile__ ("bswapl %[retval]" : [retval] "=rm" (retval) : "[retval]" (_Long));
  return retval;
#else
  unsigned char *b = (void*)&_Long;
  unsigned char tmp;
  tmp = b[0];
  b[0] = b[3];
  b[3] = tmp;
  tmp = b[1];
  b[1] = b[2];
  b[2] = tmp;
  return _Long;
#endif /* defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__) */
}
