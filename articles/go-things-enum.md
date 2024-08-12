# Go Things I _Don't_ Like: enums

https://articles.imjasonh.com/go-things-enum.md<br>
Jason Hall<br>
_First published August 12, 2024_

-----

I love -- or at least, like, or at worst, tolerate -- most things in Go. It's impossible to please everyone and I think Go's produced a broadly very usable language and ecosystem, and it's done it for more than a decade. You don't get that kind of success without making some hard decisions. In general, the Go team tends to bias toward smaller incremental changes, and I think that's a secret to the ecosystem's success. I can think of a dozen examples where the language or the standard library doesn't do something I want, and when I think about it for more than ten minutes I realize, no, they've made the right choice.

One exception is: enums.

### Enums in Java

Right before I learned Go, I mainly wrote Java. One language feature of Java that I liked was [`enum`](https://docs.oracle.com/javase/tutorial/java/javaOO/enum.html), which lets you specify a set number of values and their traits, at the type level. From the docs:

```java
public enum Planet {
    private final double mass;   // in kilograms
    private final double radius; // in meters
    Planet(double mass, double radius) {
        this.mass = mass;
        this.radius = radius;
    }

    MERCURY (3.303e+23, 2.4397e6),
    VENUS   (4.869e+24, 6.0518e6),
    EARTH   (5.976e+24, 6.37814e6),
    MARS    (6.421e+23, 3.3972e6),
    JUPITER (1.9e+27,   7.1492e7),
...
```

Then you can use those values as `Planet.EARTH` and `Planet.EARTH.getMass()`, etc., and unless it's defined in that list, there's no way to reference `Planet.X` or `Planet.ULTRAMAR` or anything besides the ones defined in the code.

This is pretty useful when there's a known set of valid values of a thing, and you want to attach other values or methods to those values. (think `NORTH`, `SOUTH`, `EAST`, `WEST`, etc., mapping to degrees)

I've seen some Java code that takes this too far (I've definitely written some, if you can believe it!), and tries to map too many things to enums, and adds too many methods to the enums, and eventually you just want a `class`. Not everything has to be an `enum` (I'm talking to you, Jason circa 2012!)

### Enums in Go

Anyway, enough about Java. Coming from Java to Go, I was surprised there was no such thing as `enum`. The planet example in Go would be something like:

```go
type Planet struct {
  Mass, Radius float64
}

var (
  PlanetMercury = Planet{3.303e+23, 2.4397e6}
  PlanetVenus   = Planet{4.869e+24, 6.0518e6}
  PlanetEarth   = Planet{5.976e+24, 6.37814e6}
  ...
)
```

And you can use them with `earthMass := PlanetEarth.Mass`, and so on.

An alternative to this would be to use Go's `iota` to give each planet an incrementing const value, and map those const values to masses and radii in an unexported method.

```
type Planet int

const (
  PlanetMercury = iota
  PlanetVenus
  PlanetEarth
)

func mass(p Planet) float64 {
  switch p {
    case PlanetMercury:
      return 3.303e+23
    case PlanetVenus:
      return 4.869e+24
  ...
    default:
      panic("invalid planet")
  }
}

func radius(p Planet) float64 {
  ...
}
```

The problem with both of these approaches is, there's no way to signal to the compiler what the valid values are. In the first example, anybody who wants to can define `planetX = Planet{100, 200}` and create their own planet. In the second example, `planetX := Planet(100)` is valid according to the compiler, and can cause a runtime panic.

There are various tips and workarounds to make these less likely to happen, using private methods and private types, but fundamentally they're ways to get around the fact that the compiler doesn't know the full set of things the value can be. These solutions technically work, but involve writing increasing amounts of boilerplate, or more realistically generating it. For example, protocol buffers support `enum`s, and the Go implementation of them generates a bunch of stuff to simulate them for Go.

[Here's an eleven-year-old Stack Overflow question about how to idiomatically support enums in Go](https://stackoverflow.com/questions/14426366/what-is-an-idiomatic-way-of-representing-enums-in-go), and all the answers are pretty underwhelming from a maintainability standpoint.

I kind of just lived with this for a while. If I had to sacrifice `enum` to get the rest of the benefits of the Go language and ecosystem, that's a trade I'm willing to make. When I need enums in Go, I tend to write some form of the second example above, and just accept that a runtime panic is technically possible but unlikely unless someone is Doing Something Weird™️.

### Enums in Rust

Every once in a while I dabble in learning Rust. I've never had an excuse to get deeply into it, but I like it from what I've seen so far. While dabbling, I've really liked [Rust's support for `enum`s](https://doc.rust-lang.org/book/ch06-01-defining-an-enum.html).

The planet example in Rust would (I think) look like this:

```rust
enum Planet {
  Mercury(f64, f64),
  Venus(f64, f64),
  Earth(f64, f64),
  ...
}
```

Rust enums go even further though. Unlike Java, each enum value doesn't have to have the same signature, or hold the same data. From the Rust docs:

```rust
enum Message {
    Quit,
    Move { x: i32, y: i32 },
    Write(String),
    ChangeColor(i32, i32, i32),
}
```

So Rust `enum`s are more like a known set of _types_ than a known set of _values_ of the _same type_. If you choose to make them all hold the same data, you can, but you don't have to.

Where Rust `enum`s really kick it up a notch though, is in [`match` statements](https://doc.rust-lang.org/book/ch06-02-match.html)

```rust
enum Coin {
    Penny,
    Nickel,
    Dime,
    Quarter,
}

fn value_in_cents(coin: Coin) -> u8 {
    match coin {
        Coin::Penny => 1,
        Coin::Nickel => 5,
        Coin::Dime => 10,
        Coin::Quarter => 25,
    }
}
```

In this example, we're defining four types of coins, and the behavior of those four types of coins. That `match` statement is _exhaustive_, which means if I forget to define the value in cents for a quarter, the code won't compile. If I add a `HalfDollar` coin, I have to define its value or this won't compile. This is _great_ for maintainability, since I can trust the compiler to tell me everywhere I've matched coin values, and yell at me if I forget one:

```
error[E0004]: non-exhaustive patterns: `HalfDollar` not covered
```

Rust has a catch-all option for `match` that acts like `default` in a switch case, but you have to be explicit about handling all other values. Readers know at a glance whether all other values are handled or not.

Seeing how great `enum`s are in Rust re-awakened my desire for better `enum`s in Go.

So what could that look like?

### Better Enums in Go?

First of all, I'm not going to be playing armchair quarterback. The Go team consists of infinitely better real-life programming language designers than I can ever hope to be. This proposal is off the top of my head, without knowing anything at all about Go's internal representations or constraints or performance concerns. Consider this a very quick sketch.

Secondly, for the record, I don't think Go needs to support everything Rust or Java does, just because they support it. The multi-typed Rust enums are cool, and I'm sure I'd find a way to use them, but it feels more complicated than Go would stomach. I'd settle for real defined values, and an exhaustive `switch` over them.

So here's my _sketch_ of better enum support in Go:

```go
type Planet struct {
  mass, radius float64

  enum (
    Mercury = {3.303e+23, 2.4397e6}
    Venus   = {4.869e+24, 6.0518e6}
    Earth   = {5.976e+24, 6.37814e6}
    ...
  )
}
```

The `enum` keyword is only valid inside a `type struct`, and it defines all the valid values there can ever be of that struct.

To reference a value, `var earth = Planet.Earth`. To `switch` over them, printing a fun fact about each planet:

```go
switch planet {
  case Mercury:
    fmt.Println("Mercury is about the size of Earth's moon.")
  case Venus:
    fmt.Println("Venus spins clockwise.")
  case Earth:
    fmt.Println("There are no fun facts about Earth.")
  ...
}
```

If we ever define a new planet, that `switch` statement would not compile until we add a `case` for it, or a `default` case. That's it, that's all I want.

Like I said, this is just a very quick sketch! How would this work with embedding, interfaces, type constraits, and so on? I don't know. But I think there's value enough in having a real answer for `enum`s in the Go language to be worth exploring it. And I believe the Go team has the chops to make it not only good, but _great_, in their typical fashion.

What do you think?
