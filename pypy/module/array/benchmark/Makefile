CFLAGS=-O3 -mtune=native -march=native -std=gnu99 

intimg: intimgtst.o intimg.o
	gcc -o $@ $^
loop: loop.o
	gcc -o $@ $^
sum: sumtst.o sum.o
	gcc -o $@ $^	
circular: circulartst.o circular.o
	gcc -o $@ $^	

run: run-intimg run-sum run-circular

run-%: %
	@echo $^
	@echo -n '         C: '
	@/usr/bin/time -f '%e s' ./$^ 2>&1 | tail -1
	@echo -n '      pypy: '
	@/usr/bin/time -f '%e s' ../../../translator/goal/pypy-c $^tst.py 2>&1 | tail -1
	@echo -n 'pypy-trunk: '
	@/usr/bin/time -f '%e s' ../../../../../trunk/pypy/translator/goal/pypy-c $^tst.py 2>&1 | tail -1
	@echo -n '   cpython: '
	@/usr/bin/time -f '%e s' python $^tst.py 2>&1 | tail -1
	@echo
