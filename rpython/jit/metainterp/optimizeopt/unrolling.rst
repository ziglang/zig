
nomenclature:

Unrolling follows that order of operations:

* optimize one version of a loop, call it <preamble>. At the end of <preamble>,
  we gather virtual state by visiting the status of optimized boxes as
  presented in the arguments to JUMP. Virtual state then can produce
  a number of inputargs from a list

* gather all the operations that can be produced in the short preamble. They're,
  as far as I can tell:

  - jump arguments, as generated from the virtual state

  - pure operations, including pure calls

  - call_loopinvariant

  - heap cache

  or the combination of the above. Note that some operations can be produced
  in more than one way. In those cases we keep both.

* the optimizer state is influenced by replaying all the short boxes producing
  operations. This populates the heap cache and the pure operation cache.

* import the values of the inputargs (so e.g. constantness, intbounds, etc.)

* we optimize normally, using extra boxes from the optimizer state

* we import all the boxes that were not generated during this optimization
  phase. This means, they have to:

  * be added to the start label

  * be added to the end jump

  * be added to the short preamble

* we close the loop, which creates correct boxes in the jump (from virtualstate)
  
