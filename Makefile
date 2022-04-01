
all: pypy3-c cffi_imports

PYPY_EXECUTABLE := $(shell which pypy)

ifeq ($(PYPY_EXECUTABLE),)
RUNINTERP = python
else
RUNINTERP = $(PYPY_EXECUTABLE)
endif

URAM := $(shell $(RUNINTERP) -c "import sys; print(4.5 if sys.maxint>1<<32 else 2.5)")

JOBS=$(subst -j,--make-jobs ,$(filter -j%, $(MAKEFLAGS)))

.PHONY: pypy-c cffi_imports

pypy3-c:
	@echo
	@echo "===================================================================="
ifeq ($(PYPY_EXECUTABLE),)
	@echo "Building a regular (jitting) version of PyPy, using CPython."
	@echo "This takes around 2 hours and $(URAM) GB of RAM."
	@echo "Note that pre-installing a PyPy binary would reduce this time"
	@echo "and produce basically the same result."
else
	@echo "Building a regular (jitting) version of PyPy, using"
	@echo "$(PYPY_EXECUTABLE) to run the translation itself."
	@echo "This takes up to 1 hour and $(URAM) GB of RAM."
endif
	@echo
	@echo "For more control (e.g. to use multiple CPU cores during part of"
	@echo "the process) you need to run \`\`rpython/bin/rpython'' directly."
	@echo "For more information see \`\`http://pypy.org/download.html''."
	@echo "===================================================================="
	@echo
	@sleep 5
	cd pypy/goal && $(RUNINTERP) ../../rpython/bin/rpython $(JOBS) -Ojit targetpypystandalone.py

cffi_imports: pypy-c
	cd lib_pypy && ../pypy/goal/pypy3-c pypy_tools/build_cffi_imports.py || /bin/true
