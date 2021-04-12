_First Posted February 10, 2020_

_Last Updated February 23, 2020_

Self Link: https://articles.imjasonh.com/k8s-controllers-operators.md

# Kubernetes Controllers and Operators

While reading Kubernetes documentation (I know, I know, already a bad idea), you will come across the terms "Controller" and "Operator" very often.

Unfortunately, despite there being pretty extensive official articles to describe both [Controllers](https://kubernetes.io/docs/concepts/architecture/controller/) and [the Operator pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/), these terms sometimes get used interchangeably, leading to unnecessary confusion.

I'm going to attempt to describe how to think of these two concepts, how they're different, how they're similar, and when to use each term correctly.

## Reconciling and Control Loops

The Kubernetes API pattern is heavily based on the concept of _control loops_ -- that is, observing the state of a thing, comparing it to the user's desired state, and moving the current state toward the desired state. This steady movement toward the desired state is called "_reconciling_".

In Kubernetes APIs, the desired state is described in an object's `.spec` field, and the current state is described in the `.status`.

Both _Controllers_ and _Operators_ are responsible for running a control loop, and _reconciling_ the observed state of something toward its desired state. The difference comes from _what_ they reconcile.

## Controllers

A Controller is software that runs a control loop. A Controller the state of a class of objects, takes some action, and updates the object's `.status`. It _reconciles_.

With the proliferation of [Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) has come a similar proliferation of Controllers to watch and reconcile those Custom Resource objects. Lots of big add-ons in the Kubernetes ecosystem, from [Istio](https://istio.io) to [OPA](https://openpolicyagent.org) to [Knative](https://knative.dev) to [Tekton](https://knative.dev), and dozens more, use Custom Resources to describe data and Controllers to manage and take action that data.

In Tekton's case, the PipelineRun Controller watches for new instances of the `PipelineRun` type, and takes action by creating new `TaskRun` objects. The TaskRun Controller sees these new objects and takes action by creating `Pod`s, which run containers to execute the user's requested workflow. As the execution progresses and Pod's status changes, Tekton's Controllers watch and update other objects' status accordingly, to signal that the execution is ongoing, or has succeeded or failed, and provide more information about how things went.

In Knative, the Service Controller watches for changes to `Service` objects, and takes action by creating new `Revision` objects. The Revision Controller sees these and takes action by configuring other downstream components. As it does this, each Controller in the chain updates objects' `.status` to signal that they were successful, or if they were unsuccessful, what went wrong and clues about how to fix it.

These are the two projects I'm most familiar with personally, but there are dozens more examples out there of Controllers watching, taking action, and updating status.

## Operators

So then what's an Operator? Well, there's a clue in the name. Operators help with _Operations_. That is, the "Ops" part of "DevOps" -- the day-to-day running and maintenance of cluster operations. Things like releases and rollbacks, feature flags, configuration, making sure the machine runs smoothly.

An Operator _is a Controller_ (i.e., it runs a control loop) that reconciles the observed operational state of _some piece of software_ toward a desired operational state.

Operators can be responsible for watching a bundle of Controllers, to make sure they're happy and healthy. Operators can also watch other types of software running on the cluster, to perform database maintenance and migrations ([here's an Operator for PostgreSQL](https://postgres-operator.readthedocs.io/en/latest/)).

Operators are particularly useful when it comes time to upgrade (or downgrade) a bundle of software on the cluster. To accomplish this, the desired state of those components can be described in an object the Operator watches. When the state of the object changes, the Operator performs some action like an upgrade, and updates that object's status.

For example, an Operator could watch a type that describes the desired and observed versions of a bundle of controller components.

```yaml=
apiVersion: operator.example.dev/v1alpha1
kind: FeatureAddOn
...
spec:
  versions:
    controller: v0.1.1
    webhook: v0.1.1
    queueManager: v0.1.1
status:
  observedVersions:
    controller: v0.1.1
    webhook: v0.1.1
    queueManager: v0.1.1
```

In this scenario, the `.spec` matches the `.status`, so there's nothing to do.

When a human cluster operator wants to upgrade the components, they can update the `.spec.versions`:

```yaml=
apiVersion: operator.example.dev/v1alpha1
kind: FeatureAddOn
...
spec:
  versions:
    controller: v0.2.0  # <-- Upgrade!
    webhook: v0.1.1
    queueManager: v0.1.1
```

The Operator would notice this change and perform an upgrade of the `controller` component. This upgrade might be as simple as applying some YAML, or replacing an image reference, but it might also be more complex, requiring draining and refilling a queue, requesting upgrades of other dependencies, scheduling downtime, anything at all.

When that process is complete, the Operator will update the `.status` to reflect the version upgrade landed successfully:

```yaml=
apiVersion: operator.example.dev/v1alpha1
kind: FeatureAddOn
...
status:
  observedVersions:
    controller: v0.2.0  # <-- Upgrade landed!
    webhook: v0.1.1
    queueManager: v0.1.1
```

If the upgrade _doesn't_ go according to plan, the Operator can report that in the `.status` too, with `.status.conditions`:

```yaml=
apiVersion: operator.example.dev/v1alpha1
kind: FeatureAddOn
...
status:
  observedVersions:
    controller: v0.1.0  # <-- Rolled back!
    ...
  conditions:
  - type: Available
    status: False
    reason: UpgradeFailed
    message: "Component 'controller' upgrade failed: ah ah ah, you didn't say the magic word."
```

The Operator can validate that the requested upgrade is valid -- maybe `webhook` and `controller` always have to be upgraded together, or maybe `v0.2.0` isn't released yet, or maybe you have to upgrade to at least `v0.1.5` before upgrading to `v0.2.0` -- all of this custom logic can be enforced and executed by the Operator.

It's not just about whole component upgrades either. Operators can be used to turn on and off features, scale up/down controller components, and more. But the important distinction is that these are _operations_ (in the "DevOps" sense), and not related to the day-to-day usage of whatever functionality is provided to end users by the _Controller_ components.

The `FeatureAddOn` type above could be namespaced or cluster-scoped, meaning the Operator watching it could be responsible for one cluster-wide installation of the controller components, or even multiple installations across multiple namespaces.

### Permissions

Another benefit of having an Operator in charge of managing cluster components is around _limiting cluster permissions_. Because the state of the `FeatureAddOn` is described in a Custom Resource, you can also limit which users have permission to view and update it.

This can limit the number of human users with permission to update `Deployment`s, for instance, since the Operator is responsible for that, and can validate the requested change, and -- absent bugs and vulnerabilities -- only make certain kinds of changes to the Controller components.

### Who Operates the Operator?

You might be asking yourself, "how does the Operator itself get upgraded, downgraded, configured, ..._operated_"? Well, it's complicated.

Operator operation is probably best left to a human performing manual processes. As such, upgrades, etc., of an Operator are likely to be rare, or at least much less common that similar operations of the controller components it operates.

In some cases, Operators can be installed and managed by components running outside the cluster, in some cases by cloud providers running the underlying platform.

## Why The Confusion?

I think the main source of confusion comes from the fact that, fundamentally, both Controllers and Operators perform a similar action -- running a control loop, and reconciling state. Indeed, Operators are a _kind_ of Controller. As such, the code that powers the two can look very similar: observe state, take action, update status; rinse, repeat.

Operators are very common when operating software of all kinds inside a Kubernetes cluster, and Controllers that reconcile custom resources are becoming more prevalant as CRDs become more common in the ecosystem.

The [Operator Framework](https://operatorframework.io/) is a widely used framework for developing Operators, which includes the [`operator-sdk`](https://github.com/operator-framework/operator-sdk), which itself uses the [`controller-runtime`](https://github.com/kubernetes-sigs/controller-runtime) framework to more easily program control loops. Neither Operators nor Controllers _require_ any of these frameworks -- at their core, they just need to watch for changes, take action, and update status -- but they can be useful when getting started.

Because both the general concepts and these specific frameworks are so useful to people new to the Kubernetes ecosystem and its large and growing lexicon of terms, these similar concepts unfortunately end up being used interchangeably.

## Conclusion

Kubernetes APIs are based on the concept of _control loops_, in which code _reconciles_ an object's current state toward its desired state.

_Controllers_ reconcile user-facing objects, including custom resources, and are by far more common.

_Operators_ are a _type of Controller_ that is used to automate maintenance actions, like upgrading and configuring other Controllers.

Thank you for coming to my TED Talk. :) 

## Comments?

If you spotted a typo or disagree with my definitions, please [file an issue](https://github.com/ImJasonH/ImJasonH/issues/new?title=k8s-controllers-operators:%20YOUR%20ISSUE%20TITLE).
