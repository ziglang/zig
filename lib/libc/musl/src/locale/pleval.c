#include <stdlib.h>
#include <ctype.h>
#include "pleval.h"

/*
grammar:

Start = Expr ';'
Expr  = Or | Or '?' Expr ':' Expr
Or    = And | Or '||' And
And   = Eq | And '&&' Eq
Eq    = Rel | Eq '==' Rel | Eq '!=' Rel
Rel   = Add | Rel '<=' Add | Rel '>=' Add | Rel '<' Add | Rel '>' Add
Add   = Mul | Add '+' Mul | Add '-' Mul
Mul   = Prim | Mul '*' Prim | Mul '/' Prim | Mul '%' Prim
Prim  = '(' Expr ')' | '!' Prim | decimal | 'n'

internals:

recursive descent expression evaluator with stack depth limit.
for binary operators an operator-precedence parser is used.
eval* functions store the result of the parsed subexpression
and return a pointer to the next non-space character.
*/

struct st {
	unsigned long r;
	unsigned long n;
	int op;
};

static const char *skipspace(const char *s)
{
	while (isspace(*s)) s++;
	return s;
}

static const char *evalexpr(struct st *st, const char *s, int d);

static const char *evalprim(struct st *st, const char *s, int d)
{
	char *e;
	if (--d < 0) return "";
	s = skipspace(s);
	if (isdigit(*s)) {
		st->r = strtoul(s, &e, 10);
		if (e == s || st->r == -1) return "";
		return skipspace(e);
	}
	if (*s == 'n') {
		st->r = st->n;
		return skipspace(s+1);
	}
	if (*s == '(') {
		s = evalexpr(st, s+1, d);
		if (*s != ')') return "";
		return skipspace(s+1);
	}
	if (*s == '!') {
		s = evalprim(st, s+1, d);
		st->r = !st->r;
		return s;
	}
	return "";
}

static int binop(struct st *st, int op, unsigned long left)
{
	unsigned long a = left, b = st->r;
	switch (op) {
	case 0: st->r = a||b; return 0;
	case 1: st->r = a&&b; return 0;
	case 2: st->r = a==b; return 0;
	case 3: st->r = a!=b; return 0;
	case 4: st->r = a>=b; return 0;
	case 5: st->r = a<=b; return 0;
	case 6: st->r = a>b; return 0;
	case 7: st->r = a<b; return 0;
	case 8: st->r = a+b; return 0;
	case 9: st->r = a-b; return 0;
	case 10: st->r = a*b; return 0;
	case 11: if (b) {st->r = a%b; return 0;} return 1;
	case 12: if (b) {st->r = a/b; return 0;} return 1;
	}
	return 1;
}

static const char *parseop(struct st *st, const char *s)
{
	static const char opch[11] = "|&=!><+-*%/";
	static const char opch2[6] = "|&====";
	int i;
	for (i=0; i<11; i++)
		if (*s == opch[i]) {
			/* note: >,< are accepted with or without = */
			if (i<6 && s[1] == opch2[i]) {
				st->op = i;
				return s+2;
			}
			if (i>=4) {
				st->op = i+2;
				return s+1;
			}
			break;
		}
	st->op = 13;
	return s;
}

static const char *evalbinop(struct st *st, const char *s, int minprec, int d)
{
	static const char prec[14] = {1,2,3,3,4,4,4,4,5,5,6,6,6,0};
	unsigned long left;
	int op;
	d--;
	s = evalprim(st, s, d);
	s = parseop(st, s);
	for (;;) {
		/*
		st->r (left hand side value) and st->op are now set,
		get the right hand side or back out if op has low prec,
		if op was missing then prec[op]==0
		*/
		op = st->op;
		if (prec[op] <= minprec)
			return s;
		left = st->r;
		s = evalbinop(st, s, prec[op], d);
		if (binop(st, op, left))
			return "";
	}
}

static const char *evalexpr(struct st *st, const char *s, int d)
{
	unsigned long a, b;
	if (--d < 0)
		return "";
	s = evalbinop(st, s, 0, d);
	if (*s != '?')
		return s;
	a = st->r;
	s = evalexpr(st, s+1, d);
	if (*s != ':')
		return "";
	b = st->r;
	s = evalexpr(st, s+1, d);
	st->r = a ? b : st->r;
	return s;
}

unsigned long __pleval(const char *s, unsigned long n)
{
	struct st st;
	st.n = n;
	s = evalexpr(&st, s, 100);
	return *s == ';' ? st.r : -1;
}
