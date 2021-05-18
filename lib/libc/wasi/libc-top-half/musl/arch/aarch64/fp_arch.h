#define fp_barrierf fp_barrierf
static inline float fp_barrierf(float x)
{
	__asm__ __volatile__ ("" : "+w"(x));
	return x;
}

#define fp_barrier fp_barrier
static inline double fp_barrier(double x)
{
	__asm__ __volatile__ ("" : "+w"(x));
	return x;
}

#define fp_force_evalf fp_force_evalf
static inline void fp_force_evalf(float x)
{
	__asm__ __volatile__ ("" : "+w"(x));
}

#define fp_force_eval fp_force_eval
static inline void fp_force_eval(double x)
{
	__asm__ __volatile__ ("" : "+w"(x));
}
