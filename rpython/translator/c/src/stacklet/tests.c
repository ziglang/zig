#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <assert.h>
#include "stacklet.h"


static stacklet_thread_handle thrd;

/************************************************************/

stacklet_handle empty_callback(stacklet_handle h, void *arg)
{
  assert(arg == (void *)123);
  return h;
}

void test_new(void)
{
  stacklet_handle h = stacklet_new(thrd, empty_callback, (void *)123);
  assert(h == EMPTY_STACKLET_HANDLE);
}

/************************************************************/

static int status;

stacklet_handle switchbackonce_callback(stacklet_handle h, void *arg)
{
  assert(arg == (void *)123);
  assert(status == 0);
  status = 1;
  assert(h != EMPTY_STACKLET_HANDLE);
  h = stacklet_switch(h);
  assert(status == 2);
  assert(h != EMPTY_STACKLET_HANDLE);
  status = 3;
  return h;
}

void test_simple_switch(void)
{
  status = 0;
  stacklet_handle h = stacklet_new(thrd, switchbackonce_callback, (void *)123);
  assert(h != EMPTY_STACKLET_HANDLE);
  assert(status == 1);
  status = 2;
  h = stacklet_switch(h);
  assert(status == 3);
  assert(h == EMPTY_STACKLET_HANDLE);
}

/************************************************************/

static stacklet_handle handles[10];
static int nextstep, comefrom, gointo;
static const int statusmax = 5000;

int withdepth(int self, float d);

stacklet_handle variousdepths_callback(stacklet_handle h, void *arg)
{
  int self, n;
  assert(nextstep == status);
  nextstep = -1;
  self = (ptrdiff_t)arg;
  assert(self == gointo);
  assert(0 <= self && self < 10);
  assert(handles[self] == NULL);
  assert(0 <= comefrom && comefrom < 10);
  assert(handles[comefrom] == NULL);
  assert(h != NULL && h != EMPTY_STACKLET_HANDLE);
  handles[comefrom] = h;
  comefrom = -1;
  gointo = -1;

  while (withdepth(self, rand() % 20) == 0)
    ;

  assert(handles[self] == NULL);

  do {
    n = rand() % 10;
  } while (handles[n] == NULL);

  h = handles[n];
  assert(h != EMPTY_STACKLET_HANDLE);
  handles[n] = NULL;
  comefrom = -42;
  gointo = n;
  assert(nextstep == -1);
  nextstep = ++status;
  //printf("LEAVING %d to go to %d\n", self, n);
  return h;
}

typedef struct foo_s {
  int self;
  float d;
  struct foo_s *next;
} foo_t;

int withdepth(int self, float d)
{
  int res = 0;
  if (d > 0.0)
    {
      foo_t *foo = malloc(sizeof(foo_t));
      foo_t *foo2 = malloc(sizeof(foo_t));
      foo->self = self;
      foo->d = d;
      foo->next = foo2;
      foo2->self = self + 100;
      foo2->d = d;
      foo2->next = NULL;
      res = withdepth(self, d - 1.1);
      assert(foo->self == self);
      assert(foo->d    == d);
      assert(foo->next == foo2);
      assert(foo2->self == self + 100);
      assert(foo2->d    == d);
      assert(foo2->next == NULL);
      free(foo2);
      free(foo);
    }
  else
    {
      stacklet_handle h;
      int n = rand() % 10;
      if (n == self || (status >= statusmax && handles[n] == NULL))
        return 1;

      //printf("status == %d, self = %d\n", status, self);
      assert(handles[self] == NULL);
      assert(nextstep == -1);
      nextstep = ++status;
      comefrom = self;
      gointo = n;
      if (handles[n] == NULL)
        {
          /* start a new stacklet */
          //printf("new %d\n", n);
          h = stacklet_new(thrd, variousdepths_callback, (void *)(ptrdiff_t)n);
        }
      else
        {
          /* switch to this stacklet */
          //printf("switch to %d\n", n);
          h = handles[n];
          handles[n] = NULL;
          h = stacklet_switch(h);
        }
      //printf("back in self = %d, coming from %d\n", self, comefrom);
      assert(nextstep == status);
      nextstep = -1;
      assert(gointo == self);
      assert(comefrom != self);
      assert(handles[self] == NULL);
      if (comefrom != -42)
        {
          assert(0 <= comefrom && comefrom < 10);
          assert(handles[comefrom] == NULL);
          handles[comefrom] = h;
        }
      else
        assert(h == EMPTY_STACKLET_HANDLE);
      comefrom = -1;
      gointo = -1;
    }
  assert((res & (res-1)) == 0);   /* to prevent a tail-call to withdepth() */
  return res;
}

int any_alive(void)
{
  int i;
  for (i=0; i<10; i++)
    if (handles[i] != NULL)
      return 1;
  return 0;
}

void test_various_depths(void)
{
  int i;
  for (i=0; i<10; i++)
    handles[i] = NULL;

  nextstep = -1;
  comefrom = -1;
  status = 0;
  while (status < statusmax || any_alive())
    withdepth(0, rand() % 50);
}

/************************************************************/
#if 0

static tealet_t *runner1(tealet_t *cur)
{
  abort();
}

void test_new_pending(void)
{
  tealet_t *g1 = tealet_new();
  tealet_t *g2 = tealet_new();
  int r1 = tealet_fill(g1, runner1);
  int r2 = tealet_fill(g2, runner1);
  assert(r1 == TEALET_OK);
  assert(r2 == TEALET_OK);
  assert(g1->suspended == 1);
  assert(g2->suspended == 1);
  tealet_delete(g1);
  tealet_delete(g2);
}

/************************************************************/

void test_not_switched(void)
{
  tealet_t *g1 = tealet_new();
  tealet_t *g2 = tealet_new();
  tealet_t *g3 = tealet_switch(g2, g1);
  assert(!TEALET_ERROR(g3));
  assert(g3 == g1);
  tealet_delete(g1);
  tealet_delete(g2);
}

/************************************************************/

static tealet_t *g_main;

static void step(int newstatus)
{
  assert(status == newstatus - 1);
  status = newstatus;
}

static tealet_t *simple_run(tealet_t *t1)
{
  assert(t1 != g_main);
  step(2);
  tealet_delete(t1);
  return g_main;
}

void test_simple(void)
{
  tealet_t *t1, *tmain;
  int res;

  status = 0;
  g_main = tealet_new();
  t1 = tealet_new();
  res = tealet_fill(t1, simple_run);
  assert(res == TEALET_OK);
  step(1);
  tmain = tealet_switch(g_main, t1);
  step(3);
  assert(tmain == g_main);
  tealet_delete(g_main);
  step(4);
}

/************************************************************/

static tealet_t *simple_exit(tealet_t *t1)
{
  int res;
  assert(t1 != g_main);
  step(2);
  tealet_delete(t1);
  res = tealet_exit_to(g_main);
  assert(!"oups");
}

void test_exit(void)
{
  tealet_t *t1, *tmain;
  int res;

  status = 0;
  g_main = tealet_new();
  t1 = tealet_new();
  res = tealet_fill(t1, simple_exit);
  assert(res == TEALET_OK);
  step(1);
  tmain = tealet_switch(g_main, t1);
  step(3);
  assert(tmain == g_main);
  tealet_delete(g_main);
  step(4);
}

/************************************************************/

static tealet_t *g_other;

static tealet_t *three_run_1(tealet_t *t1)
{
  assert(t1 != g_main);
  assert(t1 != g_other);
  step(2);
  tealet_delete(t1);
  return g_other;
}

static tealet_t *three_run_2(tealet_t *t2)
{
  assert(t2 == g_other);
  step(3);
  tealet_delete(t2);
  return g_main;
}

void test_three_tealets(void)
{
  tealet_t *t1, *t2, *tmain;
  int res;

  status = 0;
  g_main = tealet_new();
  t1 = tealet_new();
  t2 = tealet_new();
  res = tealet_fill(t1, three_run_1);
  assert(res == TEALET_OK);
  res = tealet_fill(t2, three_run_2);
  assert(res == TEALET_OK);
  step(1);
  g_other = t2;
  tmain = tealet_switch(g_main, t1);
  step(4);
  assert(tmain == g_main);
  tealet_delete(g_main);
  step(5);
}

/************************************************************/

static tealet_t *glob_t1;
static tealet_t *glob_t2;

tealet_t *test_switch_2(tealet_t *t2)
{
  assert(t2 != g_main);
  assert(t2 != glob_t1);
  glob_t2 = t2;

  step(2);
  t2 = tealet_switch(glob_t2, glob_t1);
  assert(t2 == glob_t2);

  step(4);
  assert(glob_t1->suspended == 1);
  t2 = tealet_switch(glob_t2, glob_t1);
  assert(t2 == glob_t2);

  step(6);
  assert(glob_t1->suspended == 0);
  t2 = tealet_switch(glob_t2, glob_t1);
  assert(t2 == glob_t1);
  printf("ok!\n");

  return g_main;
}

tealet_t *test_switch_1(tealet_t *t1)
{
  tealet_t *t2 = tealet_new();
  assert(t1 != g_main);
  tealet_fill(t2, test_switch_2);
  glob_t1 = t1;

  step(1);
  t1 = tealet_switch(glob_t1, t2);
  assert(t1 == glob_t1);
  assert(t2 == glob_t2);

  step(3);
  t1 = tealet_switch(glob_t1, t2);
  assert(t1 == glob_t1);
  assert(t2 == glob_t2);

  step(5);
  return t2;
}

void test_switch(void)
{
  int res;
  tealet_t *t, *t2;

  g_main = tealet_new();
  status = 0;
  t = tealet_new();
  res = tealet_fill(t, test_switch_1);
  assert(res == TEALET_OK);
  t2 = tealet_switch(g_main, t);
  assert(!TEALET_ERROR(t2));

  step(7);
  tealet_delete(g_main);
  tealet_delete(glob_t1);
  tealet_delete(glob_t2);
}

/************************************************************/

#define ARRAYSIZE  127
#define MAX_STATUS 50000

static tealet_t *tealetarray[ARRAYSIZE] = {NULL};
static int got_index;

tealet_t *random_new_tealet(tealet_t*);

static void random_run(tealet_t* cur, int index)
{
  int i, prevstatus;
  tealet_t *t, *tres;
  assert(tealetarray[index] == cur);
  do
    {
      i = rand() % (ARRAYSIZE + 1);
      status += 1;
      if (i == ARRAYSIZE)
        break;
      prevstatus = status;
      got_index = i;
      if (tealetarray[i] == NULL)
        {
          if (status >= MAX_STATUS)
            break;
          t = tealet_new();
          tealet_fill(t, random_new_tealet);
          t->data = (void*)(ptrdiff_t)i;
        }
      else
        {
          t = tealetarray[i];
        }
      tres = tealet_switch(cur, t);
      assert(tres == cur);

      assert(status >= prevstatus);
      assert(tealetarray[index] == cur);
      assert(got_index == index);
    }
  while (status < MAX_STATUS);
}

tealet_t *random_new_tealet(tealet_t* cur)
{
  int i = got_index;
  assert(i == (ptrdiff_t)(cur->data));
  assert(i > 0 && i < ARRAYSIZE);
  assert(tealetarray[i] == NULL);
  tealetarray[i] = cur;
  random_run(cur, i);
  tealetarray[i] = NULL;
  tealet_delete(cur);

  i = rand() % ARRAYSIZE;
  if (tealetarray[i] == NULL)
    {
      assert(tealetarray[0] != NULL);
      i = 0;
    }
  got_index = i;
  return tealetarray[i];
}

void test_random(void)
{
  int i;
  g_main = tealet_new();
  for( i=0; i<ARRAYSIZE; i++)
      tealetarray[i] = NULL;
  tealetarray[0] = g_main;
  status = 0;
  while (status < MAX_STATUS)
    random_run(g_main, 0);

  assert(g_main == tealetarray[0]);
  for (i=1; i<ARRAYSIZE; i++)
    while (tealetarray[i] != NULL)
      random_run(g_main, 0);

  tealet_delete(g_main);
}

/************************************************************/

tealet_t *test_double_run(tealet_t *current)
{
  double d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, *numbers;
  numbers = (double *)current->data;
  d0 = numbers[0] + 1 / 1.0;
  d1 = numbers[1] + 1 / 2.0;
  d2 = numbers[2] + 1 / 4.0;
  d3 = numbers[3] + 1 / 8.0;
  d4 = numbers[4] + 1 / 16.0;
  d5 = numbers[5] + 1 / 32.0;
  d6 = numbers[6] + 1 / 64.0;
  d7 = numbers[7] + 1 / 128.0;
  d8 = numbers[8] + 1 / 256.0;
  d9 = numbers[9] + 1 / 512.0;
  numbers[0] = d0;
  numbers[1] = d1;
  numbers[2] = d2;
  numbers[3] = d3;
  numbers[4] = d4;
  numbers[5] = d5;
  numbers[6] = d6;
  numbers[7] = d7;
  numbers[8] = d8;
  numbers[9] = d9;
  tealet_delete(current);
  return g_main;
}

void test_double(void)
{
  int i;
  double d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, numbers[10];
  g_main = tealet_new();

  d0 = d1 = d2 = d3 = d4 = d5 = d6 = d7 = d8 = d9 = 0.0;
  for (i=0; i<10; i++)
    numbers[i] = 0.0;

  for (i=0; i<99; i++)
    {
      tealet_t *t = tealet_new();
      tealet_t *tres;
      tealet_fill(t, test_double_run);
      t->data = numbers;
      tres = tealet_switch(g_main, t);
      assert(tres == g_main);
      d0 += numbers[0];
      d1 += numbers[1];
      d2 += numbers[2];
      d3 += numbers[3];
      d4 += numbers[4];
      d5 += numbers[5];
      d6 += numbers[6];
      d7 += numbers[7];
      d8 += numbers[8];
      d9 += numbers[9];
    }

  assert(d0 == 4950.0 / 1.0);
  assert(d1 == 4950.0 / 2.0);
  assert(d2 == 4950.0 / 4.0);
  assert(d3 == 4950.0 / 8.0);
  assert(d4 == 4950.0 / 16.0);
  assert(d5 == 4950.0 / 32.0);
  assert(d6 == 4950.0 / 64.0);
  assert(d7 == 4950.0 / 128.0);
  assert(d8 == 4950.0 / 256.0);
  assert(d9 == 4950.0 / 512.0);
  tealet_delete(g_main);
}

/************************************************************/

static tealet_t *g_main2, *g_sub, *g_sub2;

tealet_t *test_two_mains_green(tealet_t *current)
{
  tealet_t *tres;
  assert(current == g_sub2);

  step(3); printf("3 G: M1 [S1]  M2 [S2]\n");
  tres = tealet_switch(g_sub, g_main);
  assert(tres == g_sub);

  step(6); printf("6 G: M1 [S1]  [M2] S2\n");
  return g_sub2;
}

tealet_t *test_two_mains_red(tealet_t *current)
{
  tealet_t *tres;
  assert(current == g_sub);

  step(2); printf("2 R: M1 [S1]  [M2] S2\n");
  tres = tealet_switch(g_main2, g_sub2);
  assert(tres == g_main2);

  step(5); printf("5 R: [M1] S1  [M2] S2\n");
  return g_sub;
}

void test_two_mains(void)
{
  int res;
  tealet_t *tres;

  status = 0;
  g_main = tealet_new();
  g_main2 = tealet_new();
  g_sub = tealet_new();
  g_sub2 = tealet_new();
  res = tealet_fill(g_sub, test_two_mains_red);
  assert(res == TEALET_OK);
  res = tealet_fill(g_sub2, test_two_mains_green);
  assert(res == TEALET_OK);

  step(1); printf("1 W: [M1] S1  [M2] S2\n");
  tres = tealet_switch(g_main, g_sub);
  assert(tres == g_main);

  step(4); printf("4 W: [M1] S1  M2 [S2]\n");
  tres = tealet_switch(g_sub2, g_main2);
  assert(tres == g_sub2);

  step(7); printf("7 W: M1 [S1]  M2 [S2]\n");

  tealet_delete(g_main);
  tealet_delete(g_main2);
  tealet_delete(g_sub);
  tealet_delete(g_sub2);
}
#endif
/************************************************************/

#define TEST(name)   { name, #name }

typedef struct {
  void (*runtest)(void);
  const char *name;
} test_t;

static test_t test_list[] = {
  TEST(test_new),
  TEST(test_simple_switch),
  TEST(test_various_depths),
#if 0
  TEST(test_new_pending),
  TEST(test_not_switched),
  TEST(test_simple),
  TEST(test_exit),
  TEST(test_three_tealets),
  TEST(test_two_mains),
  TEST(test_switch),
  TEST(test_double),
  TEST(test_random),
#endif
  { NULL, NULL }
};


int main(int argc, char **argv)
{
  test_t *tst;
  if (argc > 1)
    srand(atoi(argv[1]));

  thrd = stacklet_newthread();
  for (tst=test_list; tst->runtest; tst++)
    {
      printf("+++ Running %s... +++\n", tst->name);
      tst->runtest();
    }
  stacklet_deletethread(thrd);
  printf("+++ All ok. +++\n");
  return 0;
}
