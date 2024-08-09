# Go Things I like: `if err :=`

https://articles.imjasonh.com/go-things-if-err.md<br>
Jason Hall<br>
_First published August 9, 2024_

Let's say there's a method you want to call, and it might fail. One standard way to do this is:

```go
err := MightFail()
if err != nil {
  log.Fatal("it did fail: %v", err)
}
```

...and that's fine. It's correct, it's succinct (enough), and it gets the job done.

If I see this in a code review I won't ask you to change it (anymore).

But when I _write_ Go, I prefer this form:

```go
if err := MightFail(); err != nil {
  log.Fatal("it did fail: %v", err)
}
```

...and this is about why I prefer that.

First, it's one line shorter. This isn't about code golf and being able to save precious keystrokes. If I only cared about that I'd disable `gofmt` and rewrite it as `if e := f(); e != nil { panic(e) }` or something idiotic.

The reason I care about this being shorter is because it's _vertically_ shorter, without losing any relevant information, or violating common Go idioms, like naming it `err`.

Requiring fewer lines of code means I can fit one more line of "real" code on every screen. The screen scroll window is literally a memory buffer -- if I can glance up three lines and see some useful context, that's helpful. Having to scroll or search for that context wastes time, breaks the flow, and loses context.

The other reason I like this is because I can tell at a glance that that `err` is only handled _right there_. I can correctly know that error isn't part of some larger thing, and I can ignore it once I'm on to scanning the next line. This frees up more of my mental context window for other important things.

This might seem like a meaningless hyperoptimization -- and you might be right! -- but when you're writing a bunch of code and trying to keep a few dozen things in your head, every little bit helps.

### It doesn't always work :-/

Unfortunately, this falls apart when the method returns another value, which you need to care about later.

```go
foo, err := FindFoo()
if err != nil {
  log.Fatal("no foos for you: %v", err)
}
// use the `foo` here
```

And now that `err` escapes into the surrounding scope, where it _might_ get used later. 

That's fine. You can't win 'em all.

Sometimes if you know you only need that `foo` for a brief moment you can do something like:

```go
if foo, err := FindFoo(); err != nil {
  log.Fatal("no foos for you: %v", err)
} else {
  UseFoo(foo)
}
```

...but trying to do that at all costs can make the code harder to read, and isn't generally worth it.

As a more extreme example (one I _don't_ recommend except in very specific cases!):

```go
{
  foo, err := FindFoo()
  if err != nil {
    log.Fatalf("no foos for you: %v", err)
  }
  UseFoo(foo)
}
```

This keeps `foo` and `err` in that little mini-scope, at the cost of some vertical space. But, at that point, this is a weird enough constrcut to really deserve a comment, and at that point, you might as well make it a function with a name like `func findAndUseFoo() error`. Don't get to clever.

