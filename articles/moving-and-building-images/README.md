# Moving and Building Container Images, The Right Way

https://articles.imjasonh.com/moving-and-building-images

Jason Hall

_First published October 16, 2021_

---

## It started with a Tweet

It was a sunny Fall Saturday morning in New York, and Jérôme Petazzoni [asked on Twitter](https://twitter.com/jpetazzo/status/1446514470075998225):

> Folks who work with containers: what's a thing that you find very useful or important, but was very difficult to figure out?

I mean, where do you even start. But I knew right away it would have to be something about my favorite container hobbyhorse: how people build and manage container images.

So I wrote what I considered to be a Good Tweet™️, hit Send, and went back to sipping my pumpkin spice latte in my thick cable knit sweater overlooking a quiet lake.

[The Tweet In Question](https://twitter.com/ImJasonH/status/1446624521507819521) said:

> You don't need `docker build` to build a container image, and you don't need to `docker pull / tag / push` to move one around. In a lot of cases it's actively slowing you down, or making you less secure.

It got (what I consider to be) a lot of ✨Engagement✨, and even got retweeted by some folks in the community I really admire. But more importantly, it got replies asking for what to use instead.

Since Twitter is, to quote a reply, ["notorious for setting context on fire"](https://twitter.com/arachnocapital2/status/1446952657113866242), some folks rightly asked for a longer explanation uncaged by the bird site's character limit. And that's what you're reading _right now. Keep going!_

---

The reason container image building is such a hobbyhorse for me is because of two things:

1. Developers don't want to care about containers at all. They want to write code, hopefully write tests, hopefully have those tests pass, and deploy it. Containers are an implementation detail, and any time they're thinking about it they're probably pissed off to have to be thinking about it.
1. Regardless, how you build and manage those images can have a surprising effect on your developer productivity, and even your security posture.

Those two things combined can lead to disaster: lazy developers just want something that works, and "what works" might be slow or less secure.

Making things easier on its own isn't enough, if it makes it less secure. An ideal solution would make it _easier_ to do the _right_ thing.

The Tweet In Question describes two common operations that people use the `docker` CLI for, when they might not have to, and I'll talk about each separately:

- building container images
- moving/renaming/retagging container images

Let's start with the easier of the two, moving images.

## Moving Container Images

### What you want to do

Let's say you have an image sitting in `registry.biz/dev/app:a1b2c3`, and you want to promote it to prod. Because you care about these things, you use a separate repository for dev images, that anybody can push to, and for images intended for prod, that only your CI/CD pipeline can push to.

The way I've seen a lot of people accomplish this is to have the pipeline do roughly:

```
docker pull registry.biz/dev/app:v0.52.1
docker tag registry.biz/dev/app:v0.52.1 registry.biz/prod/app:v0.52.1
docker push registry.biz/prod/app:v0.52.1
```

And it works, so the lazy developer calls it a day and goes back to ~~introducing bugs~~ writing code.

But, by using `docker` to accomplish this, you've actually used a much heavier tool than you needed, and in doing so may have made your pipeline less secure.

### What actually happened

Let's peel back the layers. (rimshot)

The `docker` CLI is really just a client for the Docker daemon, which runs in the background all the time, and does all the real work. When you invoke `docker pull`, your client sends a request to the daemon and tells it to pull the image from the registry.

The daemon pulls the image contents from the registry and stores it in some path on your computer, where it stores these things.

Next your pipeline invokes `docker tag`, which tells the daemon to also refer to those layers as the new image reference. When you invoke `docker push`, the daemon pushes the layers to the registry, and when your pipeline completes the worker and all its attached storage disappears forever. A new worker starts fresh the next time.

(You are using ephemeral build environments right? _RIGHT?!_)

And like I said, all of that _works_.

Except...

#### It's Slow

Eagle-eyed readers would notice, there's some buffering involved. All those layer blobs all get pulled into local storage, then pushed back up.

[The registry API protocol is actually smart enough to avoid pushes for contents it already has elsewhere](https://github.com/opencontainers/distribution-spec/blob/main/spec.md#mounting-a-blob-from-another-repository), so when you `docker push` that image, the registry might just say "oh I already have that layer, thanks". If you hadn't buffered it, you could have avoided ever pulling it.

The `pull`/`tag`/`push` dance has already made your pipeline worse, by making it take longer. But wait, there's more.

#### It Loses Information

Because the `docker` CLI is mainly focused on running containers, `docker pull` doesn't bother pulling image data for architectures it can't run. So if your image happens to be a [Docker manifest list](https://docs.docker.com/registry/spec/manifest-v2-2/#manifest-list) or [OCI image index](https://github.com/opencontainers/image-spec/blob/main/image-index.md) (e.g., a multi-architecture image, like most base images), `docker pull` will only pull the image suitable for the platform you're running on.

This means that when you `docker tag` and `docker push` that image, you'll only push the image specific to your computer's architecture. This can lead to confusion when comparing the digest of `alpine` on Dockerhub to your copy that you've `docker pull`/`tag`/`push`ed to your own repository, since your copy will only include one image.

Even if you're not dealing with multi-arch manifest lists, information can get lost in the `pull`/`tag`/`push` dance due to differences in compression, and support for legacy formats. See [this great comment](https://github.com/google/go-containerregistry/issues/895#issuecomment-753521526) from Jon Johnson, complete with requisite graphviz, to learn more.

All of this is understandable, because again, the `docker` CLI is not mainly a tool for moving images around, it's a tool for pulling and running them.

#### It's Less Secure

Finally, by involving the Docker daemon in the process, you've accepted its [Faustian bargain](https://en.wiktionary.org/wiki/Faustian_bargain). In order to take part in this dance, the Docker daemon requires escalated privileges to run on your computer*. It needs this to be able to run containers, which is what the `docker` CLI is really intended for. But in this case your pipeline doesn't want to run containers, it just wants to move images around some registries. It doesn't need privilege, and it [should have as little of it as possible](https://en.wikipedia.org/wiki/Principle_of_least_privilege).

> *Technically, there are ways to run containers without root (dubbed "rootless"). In practice, if you're sophisticated enough to know how to setup and operate this, I expect you to understand enough to avoid the issues I'm talking about here. This advice is for the rest of us who don't want to care about container images and just get back to work.

If your CI/CD pipeline is running in a containerized build environment like Kubernetes (and I [personally think it should be](https://tekton.dev)), then now you have to deal with containers-in-containers. There are elaborate, brittle, confusing ways to make this work, and then there's [just mounting the host's docker socket](https://estl.tech/accessing-docker-from-a-kubernetes-pod-68996709c04b), which, again, _works_, but is guaranteed to summon a flock of daemonic geese into your cluster. _Don't do this. Despite what they say, the geese have bad intentions._

To account for this gaping security hole, in most hosted SaaS build services like [Google Cloud Build](https://cloud.google.com/build) and [GitHub Actions](https://github.com/features/actions), the worker environment is an ephemeral VM that only exists for the lifetime of the build. Because workloads can't be bin-packed onto the same machines, this tends to mean lower utilization across the fleet, and accordingly higher prices passed on to end users. If only there was a better way.

### What to do instead

Fundamentally the `docker` CLI is not primarily a registry API client. It's a container runtime client, focused on running images. So let's not use that.

There are a number of tools that aim to make dealing with container images easier. Two of these are [Skopeo](https://github.com/containers/skopeo) and [`crane`](https://github.com/google/go-containerregistry/blob/main/cmd/crane/README.md).

I personally have more experience with `crane`, so I'll use that in my example, but Skopeo is also great and works fine for this. If you're more familiar with Skopeo, you should use that.

What you were trying to do was move an image from `registry.biz/dev/app:v0.52.1` to `registry.biz/prod/app:v0.52.1`. So let's just do that:

```
crane cp registry.biz/dev/app:v0.52.1 registry.biz/prod/app:v0.52.1
```

`crane cp` will make all the necessary registry API calls to copy the image from A to B, by efficiently streaming layer blobs to your computer, and streaming that data to the target registry, taking into account cross-repository mounting to avoid pulling anything it can. Not a single byte of data hits your disk. If the target registry says, "got it, thanks", that layer data is never pulled from the source registry.

And, because you're not involving the Docker daemon, this can be done in a containerized build environment, without unlocking doors to some bottomless Lovecraftian abyss.

Faster. More Secure. Nice.

---

## Building Container Images

This one's a bit more complicated.

Practically speaking, you might have no option but to use the `docker` CLI and Dockerfiles to build your image. It might just be unavoidable.

But, it's worth considering _whether_ it's unavoidable, and what kinds of trade-offs you're making. Don't just use Dockerfiles because that's what the tutorial you read in 2017 told you to use, understand what you're doing.

I'm going to focus on building container images for Go, because that's what a lot of people do these days. But the same spirit of curiosity applies to any language or framework.

### What you want to do

You have a Go application, and you'd like to put it in a container image, and push it to a registry. Seems easy. Like any good software engineer, you google `dockerfile golang` and the first result is [this page on Docker's site](https://docs.docker.com/language/golang/build-images/). You're even really good and smart and scroll all the way down to the part about [multi-stage builds](https://docs.docker.com/language/golang/build-images/#multi-stage-builds) for smaller faster images!

It tells you to use this Dockerfile:

```
# syntax=docker/dockerfile:1

##
## Build
##
FROM golang:1.16-buster AS build
WORKDIR /app
COPY go.mod ./
COPY go.sum ./
RUN go mod download
COPY *.go ./
RUN go build -o /docker-gs-ping

##
## Deploy
##
FROM gcr.io/distroless/base-debian10
WORKDIR /
COPY --from=build /docker-gs-ping /docker-gs-ping
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/docker-gs-ping"]
```

You take that, modify it to fit your codebase, `docker build` it, `docker push`, it works, you go back to ~~introducing bugs~~ writing code.

But, by using `docker` to accomplish this, you’ve used a much heavier tool than you needed, and in doing so may have made your pipeline less secure.

### What actually happened

When `docker build` runs through that Dockerfile, it builds up the resulting container image on the base image (`FROM`), by either copying some files into it (`COPY`, `ADD`), or for `RUN`, by running the specified command in the image its built up, and capturing any changes. There are also some metadata changes like `EXPOSE`, `USER`, and `ENTRYPOINT`.

But the real workhorse of this build is the `go build` line. Every other line in the `## Build` section is carefully setting up the build environment so that it can run `go build` at the end.

The `## Deploy` section is just taking the built Go binary out of the `build` image, putting it on top of the [Distroless](https://github.com/GoogleContainerTools/distroless) image (yay distroless!), and telling the image to run that binary on startup.

But why does this need to be done in a container? For Node and Python apps I get it, setting up isolated, repeatable, efficient build environments for those languages can be really hard. Again, using `docker build` and Dockerfiles might be the best answer for you, but make that decision consciously.

Anyway, back to my Go example. What's wrong there?

#### It's Slow

Go takes care to make builds isolated and repeatable. In general, you don't have to worry about `go build` starting other random processes or getting tricked into mining bitcoin.

Setting up an isolated build environment in a container using the Dockerfile above means you lose out on one of the best tools for making a build run faster: _caching._

In all that setup to `ADD` and `COPY` files into the container environment, we never mounted the [Go build cache](https://pkg.go.dev/cmd/go#hdr-Build_and_test_caching), so every time you `docker build` it's doing a `go build` as if it's never seen a line of Go before. Because this container hasn't.

Even if you did mount in the Go build cache, you're still unnecessarily copying files around from your dev environment to this containerized build environment, for what? So it can run `go build` without side effects? `go build` already doesn't have side effects.

#### It's Confusing!

Take a look at that Dockerfile again. How confident are you that each line in that Dockerfile is "correct"?

- What would happen, practically speaking, if I deleted either `WORKDIR` directive?
- What would happen if I swapped the `ADD go.mod ./` and `ADD go.sum ./` lines?
- ...or moved them after `COPY *.go ./`?
- What happens if I change it to `EXPOSE 1337`?
- What _is_ the difference between `CMD` and `ENTRYPOINT` anyway!

In some cases, changing a line means the build will fail. In some cases, changing a line will silently make your build slower. In some cases, it really doesn't matter at all. Because developers are lazy, and because that Dockerfile _works_, most never consider what it's actually describing, and why it is the way it is.

Over time, some bug creeps in and somebody fixes it by copying a line or two from StackOverflow, and they get back to work. Another project starts and someone copies the Dockerfile that worked in a previous project. These Dockerfiles proliferate and mutate and form cargo cults. Two divergent cargo cults inevitably meet and clash over whether you need to `COPY go.mod ./` first or last, or whether it matters.

Lazy though they are, there's nothing developers love more than arguing in code reviews about micro-optimizing build configs, when they should be writing better tests.

Remember! All you really wanted to do was `go build` a binary and stick it in a container image, not argue over Dockerfile ~~dogma~~ best practices.

#### It's Less Secure

As mentioned, `docker build` necessarily runs a container every time it encounters a `RUN` directive. As with moving images, this involves giving the build process privileges, which in your delivery pipeline can lead to compromises.

For many languages (Python, Node, etc.), this is going to be largely unavoidable. The value of being able to repeatably build your application in isolation makes it worth dealing with the headache of making that work in a containerized build environment.

But for Go, it's usually avoidable. So let's avoid it.

### What to do instead

Focus on what you're actually doing. `go build` my app, put it in a container image.

For a long time, "just put this file into a container image" was like some kind of unattainable dark art. The only way to do that was involved `FROM` and `ADD` and our old friend `docker build`. And again, because it _works_, a lot of people just stop there.

But it's not that hard at its core, I promise. The `crane` tool has a [`crane append`](https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane_append.md) command that takes a tarball and an image reference, and adds the tarball as a new top layer on the base image, and pushes that to a registry. That's it. As with `crane cp`, it does it entirely using regisry API operations, streaming and deduping blob uploads, without having to run any containers on your computer.

With `crane append`, you could `go build` your binary, tar it up, and append it to a base image. There's even a [recipe](https://github.com/google/go-containerregistry/blob/main/cmd/crane/recipes.md#bundle-directory-contents-into-an-image) to do it in a few lines of Bash.

That operation -- `go build && crane append` -- is so powerful, that some folks and I wrote a tool that does just that, and a bit more, called **✨[`ko`](https://github.com/google/ko)✨**.

`ko publish` (soon to be renamed `ko build`) takes a Go importpath, builds it, and pushes it to a registry.

If you `go build ./cmd/app` to get a Go binary, you can `ko build ./cmd/app` to get a container image that runs that Go binary.

Because it's just `go build`, tarring and registry operations to append a layer, `ko` doesn't require that pesky Docker daemon and its pesky privileges.

Because it's running `go build` in your regular development environment, it takes advantage of your regular build cache. If the code hasn't changed, `ko build` won't push any new layers.

`ko` has a lot more than just `ko build`, like dead simple multi-arch images, YAML templating integration, and more. I think you should give it a shot, is what I'm saying.

#### But What About Non-Go?

That's all well and good for Go, but you might be a Java developer, or a Node developer, or one of those Rust folks I keep hearing about.

For Java, there's [Jib](https://github.com/GoogleContainerTools/jib), which integrates with Maven and Gradle and does basically what `ko` does -- it builds an executable jar outside in your regular build environment, puts it on top of a base image, and pushes it to a registry.

For Node, you can kinda sorta maybe do something like `ko` using [deno](https://deno.land)? I honestly don't know much about Node. But I hacked together [this proof-of-concept](https://github.com/imjasonh/deno-image) using `deno compile` and `crane append`. If this seems interesting, I'd love feedback.

The same sort of thing should be possible with Rust. You could build the Rust executable with `cargo build` and `crane append` it to a base image that provides glibc. Again, if this is interesting to you, let me know and we can see how it works.

#### Buildpacks

Another alternative worth considering in this case is [CNCF Buildpacks](https://buildpacks.io/). Using Buildpacks, you can produce an image from source in a variety of languages (including Go), without having to write a Dockerfile. Buildpacks take care to produce images that are highly cacheable, for faster pushes and pulls.

The main situation where Buildpacks shine is when a platform provides an opinionated set of approvder builders, in a variety of languages, so that you as a developer can just invoke them and get a runnable image. The platform in this case might be a serverless platform like Heroku or Cloud Foundry or Google Cloud Run, or your company's internal runtime platform team which is responsible for defining and maintaining the set of approved and supported builders.

Think of it like having a catalog of highly-optimized Dockerfiles that you can choose from, except they're defined in a Real Programming Language.🙃

A number of these SaaS platforms make their buildpacks available for use outside of their runtime platforms:

- [Paketo Buildpacks](https://paketo.io/)
- [GCP Buildpacks](https://github.com/GoogleCloudPlatform/buildpacks)

You can build your image from source with these builders, or fork them and create your own to meet your own needs.

Buildpacks' [`pack` CLI](https://buildpacks.io/docs/tools/pack/) lets you run a builder on your source, but since the build steps aren't guaranteed to be isolated from your development environment, the build steps run in containers, requiring the Docker daemon to be running on your computer. Unlike `docker build`, however, Buildpacks can integrate more deeply with containerized CI/CD platforms like Tekton to avoid the need for containers-in-containers when running those environments.

Buildpacks are an especially attractive choice if your team builds software in many languages, and if you can either use one of the provided open source buildpacks, or if your company can justify staffing an internal team to maintain your own.

## Closing Thoughts

If I had to sum it all up, it would be this: understand the tools you're using, and understand why you should be using them. Understand the trade-offs, in developer productivity and in security, and if you're not comfortable with those trade-offs, use other tools, if those tools exist.

After considering the alternatives, `docker build` and Dockerfiles _might_ still be the best solution for you. They have the distinct advantage of working for you today, and inertia is real. But I'd just encourage you to consider what value you're getting out of them, and what inefficiencies and vulnerabilities they might be introducing.

Thank you for coming to my TED Talk.

---

If you have questions or comments, please [file an issue](https://github.com/imjasonh/imjasonh/issues/new?title=moving-and-building-images) or [suggest an edit in a pull request](https://github.com/imjasonh/ImJasonH/edit/main/articles/moving-and-building-images/README.md).
