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

One command. It creates the project, writes the intended architecture, scans all three
branches, and then **verifies the result** — because the one failure mode here is silent.

### SonarQube Cloud

```bash
git clone <this repo> demo-arch-gctoolkit
cd demo-arch-gctoolkit
export SONAR_TOKEN=<token from sonarcloud.io/account/security>
./arch-demo/bootstrap.sh <your-name> --org <your-organization>
```

### A local SonarQube Server

```bash
export SONAR_TOKEN=<token from your server>
./arch-demo/bootstrap.sh <your-name> --instance sqs
```

Add `--sqs-url http://localhost:9010` if your server is not on the default port. There is no
`--org` — SonarQube Server has no organizations.

Your server needs an edition that includes Architecture; the script checks and tells you if
not.

### What you need either way

git, Maven, a JDK 17+, and the SonarQube CLI
(`brew install sonarsource/tap/sonarqube-cli`). The script checks all four before it creates
anything, and proves your token works, so it fails in seconds rather than minutes into a
build.

It takes a few minutes, mostly Maven. The build normally downloads 362MB of GC test logs
during `process-test-resources`; `bootstrap.sh` skips that, since it is test data the scan
does not need. A first-ever build still has to fetch Maven's own plugins.

Use your own project rather than a shared one: there is a single intended architecture per
project, so two people demoing against the same project will interfere with each other.

### Checking it again later

```bash
./arch-demo/verify.sh <project-key>                              # cloud
./arch-demo/verify.sh <project-key> http://localhost:9000        # a local server
```

Three `ok` rows means the demo will behave as scripted.

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
```

Make it, then rescan. The simplest way is to re-run `bootstrap.sh` — it rescans all three
branches and re-verifies. If you want to scan just the one branch, copy the `mvn` invocation
from `arch-demo/bootstrap.sh`; the scanner plugin version differs between Cloud and Server,
which is why it is worth copying rather than improvising.

The deviation appears. Undo it, rescan, it goes.

## One thing that will bite you

A branch that does not match the project's long-lived-branch pattern is analysed as
**short-lived**: it reports only *new* code, so architecture deviations do not appear at all.
A demo set up that way shows zero deviations everywhere and looks like it is working.

`bootstrap.sh` sets the pattern to `(main|master|demo-.*)` **before** scanning anything, and
`verify.sh` checks afterwards. Branch type is fixed at analysis time, so a branch analysed
before the pattern was set must be deleted and rescanned.

Two smaller traps the scripts also handle, worth knowing if you set a project up by hand:

- A scan without `sonar.branch.name` lands on the project's **default** branch, which is
  called `master` whatever git calls it. `bootstrap.sh` renames it to `main`.
- On SonarQube Server the intended architecture goes through the API rather than the CLI,
  and the API uses a different shape from the CLI's file format. It **accepts the wrong
  shape without complaining** and stores an empty model — which again reads as zero
  deviations everywhere. `bootstrap.sh` reads the model back after writing it.

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
