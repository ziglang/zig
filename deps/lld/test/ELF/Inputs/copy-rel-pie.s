.data
.global foo
.type foo, @object
.size foo, 4
foo:
.long 0

.text
.global bar
.type bar, @function
bar:
retq
