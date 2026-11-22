# Presenter notes

Internal. The customer-facing version is [`../README.md`](../README.md).

## Before you start

Run `./arch-demo/verify.sh <your-key>` and get three `ok` lines. If any branch reports
`SHORT`, or `all = 0`, the demo will show zeros everywhere and you will not notice during
the demo. Two minutes now saves that.

Open three tabs, one per branch, on `project/architecture/current`. Switching tabs is
faster and calmer than using the branch selector live.

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
