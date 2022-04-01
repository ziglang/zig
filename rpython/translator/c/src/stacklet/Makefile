
all: stacklet.so

INC = -I../..

stacklet.so: stacklet.c stacklet.h
	gcc ${INC} -fPIC -shared -O2 -o $@ stacklet.c

stacklet_g.so: stacklet.c stacklet.h
	gcc ${INC} -fPIC -shared -g -o $@ stacklet.c -DDEBUG_DUMP

clean:
	rm -fr stacklet.so stacklet_g.so
	rm -fr run_tests_*_[go]


DEBUG = -DDEBUG_DUMP

tests: clean
	make -j1 run-all-tests

ALL_TESTS = tests-static-g \
            tests-static-o \
            #tests-dynamic-g tests-dynamic-o

run-all-tests: $(ALL_TESTS)
	@echo "*** All test suites passed ***"

tests-static-g: stacklet.c stacklet.h tests.c
	gcc ${INC} -Wall -g -o run_tests_static_g stacklet.c tests.c ${DEBUG}
	./run_tests_static_g

tests-static-o: stacklet.c stacklet.h tests.c
	gcc ${INC} -Wall -g -O2 -o run_tests_static_o stacklet.c tests.c ${DEBUG}
	./run_tests_static_o

tests-dynamic-g: stacklet_g.so tests.c
	gcc ${INC} -Wall -g -o run_tests_dynamic_g stacklet_g.so tests.c ${DEBUG}
	LD_LIBRARY_PATH=. ./run_tests_dynamic_g

tests-dynamic-o: stacklet.so tests.c
	gcc ${INC} -Wall -g -O2 -o run_tests_dynamic_o stacklet.so tests.c ${DEBUG}
	LD_LIBRARY_PATH=. ./run_tests_dynamic_o

tests-repeat: tests
	python runtests.py run_tests_static_g > /dev/null
	python runtests.py run_tests_static_o > /dev/null
	#LD_LIBRARY_PATH=. python runtests.py run_tests_dynamic_g > /dev/null
	#LD_LIBRARY_PATH=. python runtests.py run_tests_dynamic_o > /dev/null
	@echo "*** All tests passed repeatedly ***"
