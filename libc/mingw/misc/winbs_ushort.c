unsigned short __cdecl _byteswap_ushort(unsigned short _Short);

unsigned short __cdecl _byteswap_ushort(unsigned short _Short)
{
#if defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__)
  unsigned short retval;
  __asm__ __volatile__ ("rorw $8, %w[retval]" : [retval] "=rm" (retval) : "[retval]" (_Short));
  return retval;
#else
  unsigned char *b = (void*)&_Short;
  unsigned char tmp;
  tmp = b[0];
  b[0] = b[1];
  b[1] = tmp;
  return _Short;
#endif /* defined(_AMD64_) || defined(__x86_64__) || defined(_X86_) || defined(__i386__) */
}
