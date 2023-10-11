# Double by bit

A `double` value is stored in computers using the into a 64 bit [double-precision floating-point format](https://en.wikipedia.org/wiki/Double-precision_floating-point_format) according to the [IEEE754](https://en.wikipedia.org/wiki/IEEE_754) standard. This means that a double like

`6.62607015e-34`

is stored internally as

`0x 39 0B 86 0B DE 02 31 11`

It is stored as a `1.xxxxx` number times a power of `2` so the above number will be stored as

`1.7202261612138196*2^-111`

This is a swift implementation of how a computer might handle doubles under the hood. It therefor uses bit operations only.

The following operations are supported: `<`, `>`, `+`, `-`, `*`, `/`, `pow`, `sqrt`, `sin`, `cos`, `tan`, `log` and `exp`.

For clarity reasons, the code is deliberately written without focus on rounding errors, overflow situations, `NaN`, `Inf` or efficiency, it's just to show how calculations with doubles could be done with bit operations only.

This is an example of what you can do with it:

```swift
let f = DoubleByBit(1.234)
let g = DoubleByBit(-1.99)
let h = DoubleByBit.pow(f, g)
print(h.doubleValue)         // 0.6580862733673336
```

It also provides an initializer for strings so this will also work:

```swift
let f = DoubleByBit("1.234")
let g = DoubleByBit("-1.99")
let h = DoubleByBit.pow(f, g)
print(h.doubleValue)         // 0.6580862733673336
```

There is some validation on the input string so in case of invalid input it will fail with a `Parse error`.

Valid examples include:

* `299792458`
* `00299792458.0000`
* `2.99792458e8`
* `+2.99792458e+8`
* `0000.0000299792458000e+0013`
* `-6.62607015e-34`
* `-0.00e+10`
