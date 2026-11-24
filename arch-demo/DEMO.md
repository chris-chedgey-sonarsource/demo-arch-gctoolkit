# Presenter notes

How to give the demo. For setting it up, see [`../README.md`](../README.md).

**The demo as given, start to finish.** Worth watching once before presenting it yourself;
the notes below are the detail behind it rather than a substitute.

https://github.com/user-attachments/assets/f76a7901-d35d-476c-a2b8-82a2a910bcfe

Also available [as a download](walkthrough.mp4), or
[on Loom](https://www.loom.com/share/2afd04d7ffa34604b1543d11380f31ca) for Sonar colleagues.

## Before you start

Run `./arch-demo/verify.sh <your-key>` and get three `ok` lines. If any branch reports
`SHORT`, or `all = 0`, the demo will show zeros everywhere and you will not notice during
the demo. Two minutes now saves that.

Decide which demo you are giving: **enforcement** (the model exists, show it catching a
violation) or **creation** (build the model on screen). The bootstrap sets you up for the
first; the next section covers resetting for the second.

## What the bootstrap leaves you, and when to reset

**`bootstrap.sh` produces the project as it looks *after* the demo** — the intended
architecture already defined, deviations already computed. That is what you want if you are
showing an existing architecture being enforced.

**If you want to create the architecture on screen, reset it first.** Go to the intended
architecture page on `main` and delete the model, then in the demo use **Generate draft** to
build it live.

```
Cloud  https://sonarcloud.io/project/architecture/intended?id=<key>
Server <host>/project/architecture/intended?id=<key>
```

**Rule of thumb: only generate the intended architecture from `main`.**

There is no reason to do it anywhere else — the intended architecture is a single
project-level artefact, so generating it on `main` gives every branch its model. Generate
draft also always reads **main's** current architecture whatever branch the URL names, so
generating it from another branch produces a model that does not reflect that branch's code.
Confusing for you, and more so for an audience.

The current architecture and the deviations *are* per-branch. That is why one model, written
once, produces different deviations on each branch — and why this demo works at all.

Three things to know before you do that:

**There is one intended architecture per project, not per branch.** Deleting it on `main`
deletes it for every branch. There is no way to have `main` without a model and the demo
branches with one.

**The deviations already on the branches survive the delete.** [measured 2026-11-22]
Deleting the model does not recompute anything — findings are stored at analysis time. So
after a reset, `demo-integration-parser-added` still shows its one deviation. That is what
makes an interactive demo possible without rescanning: create the model live on `main`, then
switch to the branch and the deviation is there.

**But those deviations were computed against the model you deleted.** If what you author on
screen differs from `arch-demo/intended-architecture.json`, the deviation page is telling you
about the old model, not the new one. Either author the same five components and four
relationships, or say plainly that deviations update at the next analysis. A sharp customer
will ask.

**To get back to the scripted state**, re-run `bootstrap.sh`. It recreates the model and
rescans, taking about two minutes.

## The three beats

**1 — `main`. Here is the architecture.**

Five modules, four arrows, everything pointing at `gctoolkit-api`. Say what the rule is in
one sentence: *the api is the foundation, and nothing else depends on anything but the api.*
Then show **zero deviations**. The point to land: this is not a report of problems, it is a
statement of intent that the code currently satisfies.

**2 — `demo-integration-parser-added`. Someone crossed a boundary.**

A fifth arrow appears: `gctoolkit-integration → gctoolkit-parser`. One deviation, and it
names the file — `SharedAggregation.java`. Open it. The change is a field nobody uses:

```java
public UnifiedG1GCParser testonly;
```

Worth saying: no one did anything obviously wrong, and nothing is broken. The integration
harness is supposed to exercise the toolkit through its public API, and now it reaches past
it. That is the kind of thing that is invisible in review and permanent once it spreads.

**3 — `demo-integration-parser-removed`. Two lines, and it is gone.**

Delete the field and its import. Rescan. Back to four arrows and zero deviations.

## The detail worth keeping in your pocket

`module-info.java` still says `requires com.microsoft.gctoolkit.parser;` on the fixed
branch, and the architecture is clean anyway. If someone asks why, the answer is the useful
one: **architecture is computed from what the code actually references, not from what it
declares or imports.** A module declaration grants access; it does not create a dependency.

The same point is visible upstream on `main`: `XYDataSet.java` imports
`UnifiedG1GCParser` with its usage commented out, and contributes nothing. That is why the
dependency weight is 1 and not 2.

## Numbers

| Branch | Deviations | Rule |
|---|---|---|
| `main` | 0 | — |
| `demo-integration-parser-added` | 1 | `javaarchitecture:S7788` disallowed dependency |
| `demo-integration-parser-removed` | 0 | — |

The deviation names `IT/src/main/java/com/microsoft/gctoolkit/integration/shared/SharedAggregation.java`
and reports a dependency count of 1.

## Questions you should expect

**"Does it fail the build?"** Deviations are issues against architecture rules, so they flow
through quality gates and pull-request decoration like any other issue — if the rules are
active in the quality profile. Check that before promising it.

**"What if the architecture is wrong rather than the code?"** Then you change the model.
That is the honest answer and it is a feature: the model is a statement someone made, not a
truth handed down, and it is meant to be revised.

**"How long did defining this take?"** Five components and four dependencies, for a project
this size. Be ready to say that most of the work is deciding what you mean, not writing it.

## What this demo does not show

Interfaces and visibility, directives, tangles and other structural flaws, or anything at
package level. It is deliberately the smallest honest demo: one rule, one violation, one
fix. Reach for a different one if the conversation goes deeper.
