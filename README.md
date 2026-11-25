# SonarQube Architecture Workshop — Microsoft GCToolKit

A real, open source Java project ([Microsoft GCToolKit](README-gctoolkit.md)) with an
**intended architecture** defined in SonarQube, and two branches that show a dependency
being introduced and then removed.

Follow along to learn:

- what an intended architecture looks like on a real codebase
- what happens when code crosses a boundary the architecture does not allow
- that fixing the code clears the deviation

## What the architecture says

In this project there are five modules; `gctoolkit-api` forms the foundation and depends on nothing else, while everything
else depends on the api (but **not on each other**):

```
gctoolkit-parser       ──→ gctoolkit-api
gctoolkit-vertx        ──→ gctoolkit-api
gctoolkit-integration  ──→ gctoolkit-api
gctoolkit-sample       ──→ gctoolkit-api
```

The model is defined in [`arch-demo/intended-architecture.json`](arch-demo/intended-architecture.json) and comprises five components and four allowed dependencies.

## Branches

| Branch | Code | Deviations |
|---|---|---|
| `main` | upstream, untouched | **0** |
| `demo-integration-parser-added` | the integration harness reaches into the parser | **1** |
| `demo-integration-parser-removed` | that reference, removed | **0** |

Each branch is a child of the one above it, so `git log` and `git diff` show what
changed.

## Set up your own project

Run the following to create the project, writes the intended architecture, scans all three
branches, and then **verifies the result** (the one failure mode here is silent).

### SonarQube Cloud

```bash
git clone <this repo> demo-arch-gctoolkit
cd demo-arch-gctoolkit
export SONAR_TOKEN=<token from sonarcloud.io/account/security>
./arch-demo/bootstrap.sh <your-name> --org <your-organization>
```

### SonarQube Server

```bash
export SONAR_TOKEN=<token from your server>
./arch-demo/bootstrap.sh <your-name> --instance sqs
```

Add `--sqs-url http://localhost:9010` if your server is not on the default port.

Your server requires an edition that includes Architecture; the script checks for this and tells you if
not.

### What you need either way

git, Maven, a JDK 17+, and the SonarQube CLI
(`brew install sonarsource/tap/sonarqube-cli`). The script checks for all four before it creates
anything, and determines whether or not your token works. 

### Checking it again later

```bash
./arch-demo/verify.sh <project-key>                              # cloud
./arch-demo/verify.sh <project-key> http://localhost:9000        # server
```

Three `ok` rows indicates that your implementation will behave as intended.

## Running the demo

Switch branches with the selector on the architecture pages.

1. **`main`** — here is the intended architecture, and the code follows it (nothing to fix).
2. **`demo-integration-parser-added`** — someone made the integration harness use the
   parser directly (one deviation, naming one file).
3. **`demo-integration-parser-removed`** — two lines deleted (clean again).

## Walking through it by hand

```bash
git checkout main
git diff main..demo-integration-parser-added     # the change to make
```

Make the change, then rescan. The simplest way is to re-run `bootstrap.sh` as it rescans all three
branches and re-verifies. If you want to scan just the one branch, copy the `mvn` invocation
from `arch-demo/bootstrap.sh`; the scanner plugin version differs between Cloud and Server,
which is why it is worth copying rather than improvising.

The deviation appears. Undo it, rescan, and watch it go.

> Callouts

A branch that does not match the project's long-lived branch pattern is analyzed as
**short-lived**: it reports only *new* code, so architecture deviations do not appear at all.
A demo set up that way shows zero deviations everywhere and looks as though it's working.

`bootstrap.sh` sets the pattern to `(main|master|demo-.*)` **before** scanning anything, and
`verify.sh` checks afterwards. Branch type is fixed at analysis time, so a branch analyzed
before the pattern was set must be deleted and rescanned.

Two smaller traps the scripts also handle, worth knowing if you set up a project up by hand:

- A scan without `sonar.branch.name` lands on the project's **default** branch; `bootstrap.sh` renames it to `main`.
- On SonarQube Server the intended architecture goes through the API rather than the CLI,
  and the API uses a different shape from the CLI's file format. It **accepts the wrong
  shape without complaining** and stores an empty model, which again reads as zero
  deviations everywhere. `bootstrap.sh` reads the model back after writing it.

## Contents

| | |
|---|---|
| `arch-demo/intended-architecture.json` | the model, as `sonar architecture intended set --file` expects it |
| `arch-demo/bootstrap.sh` | create project, set the pattern, write the model, scan, verify |
| `arch-demo/verify.sh` | check the demo is measuring what it should |
| `arch-demo/walkthrough.mp4` | a recording of the demo being given |
| `README-gctoolkit.md` | the upstream project's own README |

Everything under `arch-demo/` is demo scaffolding. The rest of the repository is GCToolKit,
unmodified except on the two demo branches.
