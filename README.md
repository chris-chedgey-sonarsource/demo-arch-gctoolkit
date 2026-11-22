# SonarQube Architecture demo — gctoolkit

A real open-source Java project ([Microsoft GCToolKit](README-gctoolkit.md)) with an
**intended architecture** defined in SonarQube, and two branches that show a dependency
being introduced and then removed.

Use it to demonstrate, or to follow along yourself:

- what an intended architecture looks like on a real codebase
- what happens when code crosses a boundary the architecture does not allow
- that fixing the code clears the deviation

## What the architecture says

Five modules. `gctoolkit-api` is the foundation and depends on nothing else; everything
else depends on the api and **not on each other**:

```
gctoolkit-parser       ──→ gctoolkit-api
gctoolkit-vertx        ──→ gctoolkit-api
gctoolkit-integration  ──→ gctoolkit-api
gctoolkit-sample       ──→ gctoolkit-api
```

The model is in [`arch-demo/intended-architecture.json`](arch-demo/intended-architecture.json).
That is the whole thing — five components and four allowed dependencies.

## Branches

| Branch | Code | Deviations |
|---|---|---|
| `main` | upstream, untouched | **0** |
| `demo-parser-integration-added` | the integration harness reaches into the parser | **1** |
| `demo-parser-integration-removed` | that reference removed again | **0** |

Each branch is a child of the one above it, so `git log` and `git diff` show exactly what
changed and nothing else.

## Set up your own project

You need a SonarQube Cloud token in `SONAR_TOKEN`, plus Java 17+, Maven and git.

```bash
git clone <this repo> demo-arch-gctoolkit
cd demo-arch-gctoolkit
export SONAR_TOKEN=<your token>
./arch-demo/bootstrap.sh <your-name> --org <your-organization>
```

That creates the project, writes the intended architecture, scans all three branches, and
then **verifies the result** — because the one failure mode here is silent (see below). It
takes a few minutes, mostly Maven.

Use your own project rather than a shared one: there is a single intended architecture per
project, so two people demoing against the same project will interfere with each other.

## Running the demo

Switch branches with the selector on the architecture pages. The story is three beats:

1. **`main`** — here is the intended architecture, and the code follows it. Nothing to fix.
2. **`demo-parser-integration-added`** — someone made the integration harness use the
   parser directly. One deviation, naming one file.
3. **`demo-parser-integration-removed`** — two lines deleted. Clean again.

Presenter notes, including what to say and the numbers to expect, are in
[`arch-demo/DEMO.md`](arch-demo/DEMO.md).

## Walking through it by hand

More convincing than switching branches, because the change is yours:

```bash
git checkout main
git diff main..demo-parser-integration-added     # the change to make
# make it, then:
mvn package sonar:sonar -Dsonar.projectKey=<your key> ...   # see bootstrap.sh
```

The deviation appears. Undo it, rescan, it goes.

## One thing that will bite you

A SonarQube Cloud branch that does not match the project's long-lived-branch pattern is
analysed as **short-lived**: it reports only *new* code, so architecture deviations do not
appear at all. A demo set up that way shows zero deviations everywhere and looks like it is
working.

`bootstrap.sh` sets the pattern to `(main|master|demo-.*)` **before** scanning anything, and
`arch-demo/verify.sh` checks for it afterwards. If you set a project up by hand, do the same
— and note that branch type is fixed at analysis time, so a branch analysed before the
pattern was set must be deleted and rescanned.

## Contents

| | |
|---|---|
| `arch-demo/intended-architecture.json` | the model, as `sonar architecture intended set --file` expects it |
| `arch-demo/bootstrap.sh` | create project, set the pattern, write the model, scan, verify |
| `arch-demo/verify.sh` | check the demo is measuring what it should |
| `arch-demo/DEMO.md` | presenter notes and expected numbers |
| `README-gctoolkit.md` | the upstream project's own README |

Everything under `arch-demo/` is demo scaffolding. The rest of the repository is GCToolKit,
unmodified except on the two demo branches.
