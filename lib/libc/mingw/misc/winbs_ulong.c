unsigned long __cdecl _byteswap_ulong (unsigned long _Long);

unsigned long __cdecl _byteswap_ulong (unsigned long _Long)
{
  return __builtin_bswap32(_Long);
}
