extern inline int __libc_use_alloca (size_t size)
{
  return size <= __MAX_ALLOCA_CUTOFF;
}
