# kavod

Kavod is a turing tarpit (probably). This means it is able to compute everything that a Turing Machine is able to compute.

## Memory layout

Memory is a map of stacks. Each stack has a reference, which is an integer.

Stack `-1` is the "register stack"; it behaves just like a normal stack, but certain operators push and pop from it.

The default stack is `0`, but this can be changed. This default stack is where most commands are focused.

## Commands

Note 1: a run of digits pushes that number to the stack.

Note 2: "Pop `A, B`" means that the stack ends with `B` and `A` is before `B`, like so: `[..., A, B]`. After the command, both `A` and `B` are removed from the stack. ("Peek", however, leaves these numbers on the stack.)

| Command | Effect |
| ------- | ------ |
| `-`     | Pop `A, B`: push `A - B`. |
| `+`     | Pop `A, B`: push `A + B`. |
| `.`     | Pop `N`: go to token position `N`. |
| `?`     | Pop `N`, peek `C`: if `C` is nonzero, go to token position `N`. |
| `>`     | Peek `A`: push `A` to the register stack. |
| `<`     | Pop `A` from the register stack: push `A`. |
| `}`     | Pop `A, R`: push `A` to stack `R`. |
| `{`     | Pop `A` from stack `R`: push `A`. |
| `~`     | Pop `R`: set the current stack to `R`. |
| `*`     | Read a byte from the input and push it to the stack (-1 if EOF). |
| `#`     | Output a byte. |
| `` ` `` | Debug the program. |