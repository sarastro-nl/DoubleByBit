# Double by bit

A `double` value is stored in computers using the into a 64 bit [double-precision floating-point format](https://en.wikipedia.org/wiki/Double-precision_floating-point_format) according to the [IEEE754](https://en.wikipedia.org/wiki/IEEE_754) standard. This means that a double like

`6.62607015e-34`

is stored internally as

`0x 39 0B 86 0B DE 02 31 11`

It is stored as a `1.xxxxx` number times a power of `2` so the above number will be stored as

`1.7202261612138196*2^-111`

This is a swift implementation of how a computer might handle doubles under the hood. It therefor uses bit operations only.

The following operations are supported: `<`, `>`, `+`, `-`, `*`, `/`, `^`, `sqrt`, `sin`, `cos`, `tan` and `log`.

For clarity reasons, the code is deliberately written without focus on rounding errors, overflow situations, `NaN`, `Inf` or efficiency, it's just to show how calculations with doubles could be done with bit operations only.
