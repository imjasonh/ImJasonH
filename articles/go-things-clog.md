# Go Things I Like: `slog` and `clog`

https://articles.imjasonh.com/go-things-clog.md<br>
Jason Hall<br>
_First published August 9, 2024_

-----

In 2023, Go 1.21 added the `log/slog` package. You can read all about it [on the Go blog](https://go.dev/blog/slog) and in [the godoc](https://pkg.go.dev/log/slog).

`slog` improves on the venerable [`log`](https://pkg.go.dev/log) package by adding "structured logging", where you can attach arbitrary key/values to loggers.

```go
logger.With("url", r.URL).Info("got request to URL")
```

Before `slog` was in the Go standard library, there was [`uber-go/zap`](https://github.com/uber-go/zap), and [`siprupsen/logrus`](https://github.com/sirupsen/logrus) and a few others. I'm really glad they adopted it into the standard library, and in typical Go team fashion, it's an insanely small but powerful package. I like it enough to write about it here.

## Missing Context

Coming from `zap` and `logrus`, the first thing I immediately wanted was a way to stuff my logger into a `context.Context`, and pull it back out again. I'm a little surprised `slog` didn't come with this, but 🤷‍♂️ that's their choice. Decisions like that are how you end up with an insanely small and powerful package.

But, I wanted contextual logging anyway. And luckily, [**@wlynch**](https://github.com/wlynch) did too. He started the delightfully-named https://github.com/chainguard-dev/clog.

```go
func main() {
	ctx := context.Background()
	f(ctx)
}

func f(ctx context.Context) {
	clog.FromContext(ctx).Info("you are in f")
}
```

This avoids needing a global logger (🤢) and the need to pass a `logger` to each and every method, alongside your `ctx`.

Having a logger in your context means you can _add_ structured context to your logs, and pass that down through your program alongside the rest of your context.

```go
func f(ctx context.Context) {
	log := clog.FromContext(ctx).With("inside", "f")
	log.Info("you are in f")
	ctx = clog.WithLogger(log)
	g(ctx)
}
```

With this, anything inside `g` that uses the logger inside the context, also gets `inside=f` added to its structured logs. This can be useful when reading logs, since you can tell whether `g` was called via `f` versus another method, or called directly.

There's a lot more to `clog`, but even just having context-awareness was enough to make me want to migrate everything we had from our previous structured logging package to `slog` and `clog`.

## How Very Ungoogley of You!

When you log `With` something, you can see the extra context in the log output, and use `grep` to filter your logs. But where structured logging _really_ shines is when your logs end up in a managed logging solution. Being a GCP fanboy, I'm talking about Cloud Logging.

When you log something basically anywhere in GCP, it gets transparently collected and written to Cloud Logging. If what you're writing happens to be JSON, GCP parses it, and you can filter on the structured values in the UI and CLI. It's ✨magical✨.

`slog` has a built-in JSON handler, which writes logs to stderr in JSON form, but it didn't go quite far enough to be optimally useful for GCP Logging, which treats some fields as special in their logging solution. Namely, in GCP, the field `message` gets treated as the main message of the log, and there's a `logging.googleapis.com/sourceLocation` field that GCP uses to map log lines to the line of source code that logged it. These were slightly incompatible with the decisions `slog` made about naming these fields. There's also more log severity levels in GCP than there are in `slog` by default.

But that's okay, that's nothing we can't fix with a little adapter package! And so, [`clog/gcp`](https://github.com/chainguard-dev/clog/tree/main/gcp) was born. Using this log handler adapts your logs into the form that GCP expects. All your logging callsites can just keep doing `log.Infof`, and the logger will take care of massaging those logs into the optimal form for GCP. If you're building a CLI, you can use `slog`'s built-in `TextHandler` and your callsites are unchanged.

I even added a `clog/gcp/init` package that can be underscore-imported to set the GCP logger as the default, so leveling up your GCP logging game in Go is just one `import` line at the top of your `package main`.

```
import (
	_ "github.com/chainguard-dev/clog/gcp/init"
)
```

All of `clog`'s GCP-aware features were originated in https://github.com/remko/cloudrun-slog, which we forked and modified nearly beyond recognition, but the basic idea was [**@remko**](https://github.com/remko)'s. Great stuff.

## But wait, there's more!

After migrating everything to `clog` we found a few more missing pieces of `slog` -- again, more a testament to their conservatism than an indictment of their imagination!

[`slag`](https://pkg.go.dev/github.com/chainguard-dev/clog/slag): a simple package to adapt `flag` to let you specify a slog level as a command-line flag. From the docs:

```go
func main() {
	var level slag.Level
	flag.Var(&level, "log-level", "log level")
	flag.Parse()
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: &level})))
}
```

This lets you do `go run ./cmd/server --log-level=debug` or `--log-level=warn` to tweak the verbosity of your logs.

[`slogtest`](https://pkg.go.dev/github.com/chainguard-dev/clog/slogtest): a package to adapt `*testing.T` logs to `clog` contexts, so all the contextual debug logs you emit in your methods under test get reported to your unit tests:

```go
func TestExample(t *testing.T) {
	ctx := slogtest.Context(t)
	f(ctx)
}
```

...produces...

```
=== RUN   TestExample
	slogtest.go:24: level=INFO source=/path/to/example_test.go:13 msg="you are in f" inside=f
```

These are simple little adapters that make day-to-day life building a distributed system in Go more pleasant, and more maintainable. I'm really happy with how they've turned out.

Oh! And did I mention, [`clog` has zero dependencies outside of the standard library](https://github.com/chainguard-dev/clog/blob/main/go.mod)? That one's a little bonus for all the folks who read all the way to the bottom.

Anyway, `clog` is great. Use `clog`. Tell your friends.
