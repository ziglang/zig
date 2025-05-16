unsigned long long __cdecl _byteswap_uint64(unsigned long long _Int64);

unsigned long long __cdecl _byteswap_uint64(unsigned long long _Int64)
{
  return __builtin_bswap64(_Int64);
}
