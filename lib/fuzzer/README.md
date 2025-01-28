There are two things the fuzzer is storing: explored features and the corpus.

Explored features is a sorted buffer of u32 values. Explored feature is
anything "interesting" that happened in the code when we run it with some input
and *it did not crash*. Different "interesting things" should correspond to
different u32 values but collisions never 100% avoidable. Explored features are
not shared among different workers.

Currently tracked "interesting things" are:

* taken edges in the CFG
* address of cmp instructions executed
* address of switch statements executed
* indirect calls

Fuzzer is trying to maximize the number of unique explored features over all
inputs.

The corpus is a set of inputs where input is some array of bytes. The initial
corpus is either provided by the user or generated randomly. The corpus is
stored as two arrays that are shared among all workers. One of the arrays
stores the inputs, densely packed one after another. The other is storing some
metadata and indexes of string ends. Whenever some input explores a new
feature, it is added to the corpus. The corpus is never shrunk, only appended.

All that the fuzzer does is pick random input, mutate it, see if it hits any
new features and if so, add the mutated input to the corpus and the new
features to explored features.

Every file starts with a more detailed documentation on the part of the fuzzer
that is implemented in that file:

* `feature_capture.zig` - storing and deduplication of features that the user
  code is emitting
* `InputPool*.zig` - corpus implementations
* `main.zig` - the main loop
* `memory_mapped_list*.zig` - shared growable memory mapped files
* `mutate.zig` - mutations

Possible improvements:

* Prioritize mutating inputs that hit rare features
* Table of recently compared values used in mutations
* In-place mutation to avoid copying?
* Implement more mutations
* Multithreading
* Maybe use hash table for explored features instead of sorted array

