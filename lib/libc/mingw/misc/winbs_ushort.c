unsigned short __cdecl _byteswap_ushort(unsigned short _Short);

unsigned short __cdecl _byteswap_ushort(unsigned short _Short)
{
  return __builtin_bswap16(_Short);
}
