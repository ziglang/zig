/*
 * The Hexagon user status register includes five status fields which work
 * as sticky flags for the five IEEE-defined exception conditions:
 * inexact, overflow, underflow, divide by zero, and invalid.
 * A sticky flag is set when the corresponding exception occurs,
 * and remains set until explicitly cleared.
 *
 *  usr:23:22 - Rounding Mode
 *  00: Round toward nearest
 *  01: Round toward zero
 *  10: Downward Round toward negative infinity
 *  11: Upward Round toward positive infinity
 *
 *  usr:5 - Floating-point IEEE Inexact Sticky Flag.
 *  usr:4 - Floating-point IEEE Underflow Sticky Flag.
 *  usr:3 - Floating-point IEEE Overflow Sticky Flag.
 *  usr:2 - Floating-point IEEE Divide-By-Zero Sticky Flag.
 *  usr:1 - Floating-point IEEE Invalid Sticky Flag.
 *  usr:0 - Sticky Saturation Overflow, when 1 saturation occurred.
 */

#define FE_ALL_EXCEPT 0x3f

#define USR_FE_MASK 0x3fc0003f
#define RND_MASK    (0x3 << 22)
#define RND_NEAR    (0x0 << 22)
#define RND_ZERO    (0x1 << 22)
#define RND_DOWN    (0x2 << 22)
#define RND_UP      (0x3 << 22)

/*
 * int feclearexcept(int mask)
 */
.global feclearexcept
.type feclearexcept,@function
feclearexcept:
  {
    r0 = and(r0, #FE_ALL_EXCEPT) // Only touch the IEEE flag bits.
    r1 = usr
  }
  r1 = and(r1, ~r0)
  {
    usr = r1
    r0 = #0
    jumpr r31
  }

/*
 * int feraiseexcept(int mask)
 */
.global feraiseexcept
.type feraiseexcept,@function
feraiseexcept:
  {
    r0 = and(r0, #FE_ALL_EXCEPT) // Only touch the IEEE flag bits.
    r1 = usr
  }
  r1 = or(r1, r0)
  {
    usr = r1
    r0 = #0
    jumpr r31
  }


/*
 * int fetestexcept(int mask)
 */
.global fetestexcept
.type fetestexcept,@function
fetestexcept:
  {
    r0 = and(r0, #FE_ALL_EXCEPT) // Only touch the IEEE flag bits.
    r1 = usr
  }
  {
    r0 = and(r1, r0)
    jumpr r31
  }

/*
 *int fegetround(void)
 */
.global fegetround
.type fegetround,@function
fegetround:
  r0 = usr
  r0 = and(r0, ##RND_MASK)
  r0 = lsr(r0, #22);
  jumpr r31

/*
 * int __fesetround(int r)
 */
.global __fesetround
.type __fesetround,@function
__fesetround:
  {
    r0 = and(r0, #0x3) // Can only be 0,1,2, or 3
    r1 = usr
    r2 = ##RND_MASK
  }
  {
    r1 = and (r1, ~r2)  // Clear the current rounding bits.
    r0 = asl (r0, #22)
  }
  r1 = or(r1, r0)
  usr = r1
  {
    r0 = #0; jumpr r31
  }

/*
 * int fegetenv(fenv_t *envp)
 */
.global fegetenv
.type fegetenv,@function
fegetenv:
  r1 = usr
  memw(r0) = r1
  {
    r0 = #0
    jumpr r31
  }

/*
 * int fesetenv(const fenv_t *envp)
 */
.global fesetenv
.type fesetenv,@function
fesetenv:
  { p0 = cmp.eq(r0, #-1); if (p0.new) r1 = #0 }  /* The default mode */
  if (!p0) r1 = memw(r0)                         /* stored in fenv_t */

  r2 = ##USR_FE_MASK // USR:FE bit mask
  r1 = and(r1, r2)   // MASK the input bits with the FE bits
  r3 = usr
  r3 = and(r3, ~r2)  // Clear any currently set FE bits
  r3 = or(r3, r1)    // Set the newbits
  usr = r3
  {
    r0 = #0
    jumpr r31
  }
