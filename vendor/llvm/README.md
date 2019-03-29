# Build llvm sources

The ./Makefile provides allowing multiple versions of llvm to be built and
tested. Various variables/parameters need to be set which can be done directly
on the command line or set in \*.cfg files and passed to the makefile by
setting LLVM_CFG=XXX.cfg on the command line or export into the environment.

See [llvm getting started](http://llvm.org/docs/GettingStarted.html) for more
information on building llvm.

## Prerequesites
  * gcc 6+
  * cmake
  * ninja &| make
  * gold, bfd &| lld

## Build and install in one step
For options See `make help` or ./Makefile

Build llvm as defined by the commit associated with lib/llvm/src submodule:
```
make -j12
```
Example over riding some defaults
```
make -j6 LLVM_BUILD_ENGINE=Ninja LLVM_BUILD_TYPE=Debug
```

## Rebuild current src
Use the same options as the initial 'all' build
```
make -j12 rebuild LLVM_BUILD_ENGINE=Ninja LLVM_BUILD_TYPE=Debug
```
## Install after a rebuild
Use the same options as the initial 'all' build
```
make install LLVM_BUILD_ENGINE=Ninja LLVM_BUILD_TYPE=Debug
```
## Clean
Clean binaries
```
make clean
```
## Distributation Clean
Clean binaries and sources
```
make distclean
```
