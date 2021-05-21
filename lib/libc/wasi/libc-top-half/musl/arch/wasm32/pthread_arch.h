#ifdef _REENTRANT
#error "multiple threads not supported in musl yet"
#endif

static inline struct pthread *__pthread_self(void)
{
  return (struct pthread *)-1;
}

#define TP_ADJ(p) (p)

#define tls_mod_off_t unsigned long long
