# Go Things I Like: `envconfig`

https://articles.imjasonh.com/go-things-envconfig.md<br>
Jason Hall<br>
_First published August 9, 2024_

-----

When I write a thing, it's usually either configured with a command-line flag (if it's a CLI), or environment variables. For CLIs, I always use [`cobra`](https://github.com/spf13/cobra), and it almost never lets me down. For long-running services, I tend to use env vars, and for the longest time I didn't have a good clean way I liked to use those, like I did with `cobra`.

Until `envconfig`. 

My first `envconfig` was [Kelsey Hightower's](https://github.com/kelseyhightower/envconfig), but it seems to be "lightly maintained" now, and all the new development seems to be happening in [Seth Vargo's](https://github.com/sethvargo/go-envconfig), which I recommend.

The benefit of `envconfig` is that env vars are originally expressed as dumb strings, but generally you want to consume them in some other, better, more typed way. Like Go has `flag` to parse command-line flags (which are just strings), you want the same thing for env vars.

The basic usage of `envconfig` is this:

```
type envConfig struct {
  Port int `env:"PORT" required:"true" default:"8080"`
}
func main() {
  ctx := context.Background()
  var env envConfig
  if err := envconfig.Process(ctx, &env); err != nil {
    log.Fatalf("parsing env: %v", err)
  }
  // run stuff on env.Port...
}
```

That's a heck of a lot simpler than `os.Getenv("PORT")`, `strconv.Atoi`, validating, defaulting, and all that mumbo jumbo. Even with just one env var to care about, it's worth it. It's definitely worth it if you have more than 5. Some places, there are like 20+.

So first of all, 👏 to `envconfig`. It's a powerful, simple little Go package, and I use it basically everywhere.

But, there's an even simpler form of using `envconfig` that I've started gravitating toward, to minimize the boilerplate:

```
var env = envconfig.MustProcess(context.Background(), &struct{
  Port int `env:"PORT" required:"true" default:"8080"`
}{})

func main() {
  // run stuff on env.Port...
}
```

This isn't just fewer lines, it's a lot less boilerplate at the top of `func main`, for the same end result.

`MustProcess` processes the env at startup and populates the global variable `env`, and panics if processing the env fails. As soon as `func main` is called, it's already got all it needs to start doing stuff with env values. It's pretty swell.

If I need to pass parts of the env down to methods in the program, I can. I don't tend to need to pass the whole `env` down, so using the anonymous struct isn't too much of a barrier. If I do need to pass multiple parts of the `env` down, I can populate another struct with the values I need.

In extreme cases, I can also do this `var env = envconfig.MustProcess` in sub-packages, but that can anger the DI gods, so be careful.
