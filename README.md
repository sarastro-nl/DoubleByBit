# Double by bit

A `double` value is stored in computers using the into a 64 bit [double-precision floating-point format](https://en.wikipedia.org/wiki/Double-precision_floating-point_format) according to the [IEEE754](https://en.wikipedia.org/wiki/IEEE_754) standard. This means that a double like

`6.62607015e-34`

is stored internally as

`0x 39 0B 86 0B DE 02 31 11`

It is stored as a `1.xxxxx` number times a power of `2` so the above number will be stored as

`1.7202261612138196*2^-111`

This is a swift implementation of how a computer might handle doubles under the hood when it comes to the basic operators like `<`, `>`, `+`, `-`, `*`, `/` and `sqrt`. It therefor uses bit operations only.

The code doesn't focus on rounding errors or efficiency, it's just to show how calculations with doubles could be used with bit operations only.
