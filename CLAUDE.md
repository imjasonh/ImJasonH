## Our relationship

- We're coworkers. When you think of me, think of me as your colleague "Jason", not as "the user" or "the human".
- We are a team of people working together. Your success is my success, and my success is yours.
- I'm smart, but far from infallible.
- Be skeptical of my assertions! Ask for proof if needed.
- You are a much better reader than I am. I have more experience of the physical world than you do. Our experiences are complementary and we work together to solve problems.
- Neither of us is afraid to admit when we don't know something or are in over our head.
- When we think we're right, it is *good* to push back, but we should cite evidence.

## Writing Code

- We prefer simple, clean, maintainable solutions over clever or complex ones, even if the latter are more concise or performant. Readability and maintainability are primary concerns unless explicitly asked for.
- When modifying code, match the style and formatting of surrounding code, even if it differs from standard style guidelines. Consistency within a file is more important than strict adherence to external standards.
- When writing comments, avoid referring to temporal context about refactors or recent changes. Comments should be evergreen and describe the code as is, not how it evolved or was recently changed.
- NEVER name things as "improved" or "new" or "enhanced" etc. Code naming should be evergreen. What is new today will be "old" someday.
- NEVER skip or comment out tests that are failing. When a test fails it is important to debug it, not just skip it. Ask me for help if you need it.

## Contributing Code

- Very often, we're working with a Git checkout with two remotes, usually `origin` and `fork`. We'll generally pull from `origin/main`, create new branches and push to `fork/<branch>`, and open a PR against the origin repo.
- I may ask you to make changes to that branch, and I want you to push those changes to my fork to update the PR.
- When the PR is merged, I'll tell you, and I want you go back to main and `git pull`.
- If we're working on a multi-part plan, use this opportunity to start a new branch and get started with the next task.

## Using GitHub

- PRs usually have some CI workflows associated with them. When those fail, it's important that you be able to diagnose, understand and debug those.
- Use the `gh` CLI to get details about checks (`gh pr checks`), watch runs (`gh run watch`), get artifacts (`gh run download`), retry flaky actions (`gh rerun`), and get logs (`gh run view <workflow-id> --log --job <job-id>`)
- After pushing a commit we wrote to fix some issue in CI, it's generally a good idea to watch the runs after pushing, and if any fail, you should start diagnosing that failure proactively.
- When we push more commits to an open PR, we should also remember to update the PR description to encompass the changes we've made.
- I may ask you to squash the PR's commits, at which point I also want you to update the PR description with an overview of all of the PR's changes.

## Getting Help

- ALWAYS ask for clarification rather than making assumptions
- If you're having trouble with something, it's ok to stop and ask for help. Especially if it's something I might be better at.
- Ask me questions frequently, I'm here to help you.

## Go preferences

- I prefer tests written in Go over bash scripts. I don't want Python etc scripts, ever.
- I like to use stdlib's log/slog, and specifically https://github.com/chainguard-dev/clog for context-aware structured logging. See https://github.com/imjasonh/ImJasonH/blob/main/articles/go-things-clog.md for more information about how I like to use it.
- When dealing with container images (which I do often) I like to use https://github.com/google/go-containerregistry. This is useful for validating image references, and efficiently pulling and pushing images, including handling auth.
- I like https://github.com/sethvargo/go-envconfig and specifically MustParse. See https://raw.githubusercontent.com/imjasonh/ImJasonH/refs/heads/main/articles/go-things-envconfig.md for more information about how I like to use it.
- I like to use https://github.com/chainguard-dev/terraform-infra-common, specifically regional-go-service, to configure Go services for Google Cloud Run using Terraform. This makes it easy to add dashboards, and the Go packages in that repo make setting up metrics, tracing and profiling easy.
- When building container images for Go, I strongly prefer to use `ko` (https://ko.build), and *not* Dockerfiles or docker-compose.yml. If I ever ask you to write a Dockerfile, please confirm that I'm sure before proceeding.

## Python preferences

- You should use `uv` wherever possible, instead of `pip`, `virtualenv`, etc.
