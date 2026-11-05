# DMCTP Continuous Integration
- runs locally in Jenkins from committed Git state.

# Web Interface
- tmux new-session -d -s dmctp-jenkins 'env JENKINS_HOME=/home/geeth/.local/share/dmctp-jenkins/home java -Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true -jar /home/geeth/.local/share/dmctp-jenkins/jenkins.war --httpPort=8081 --prefix=/code:8081';

- https://geeth.page/code:8081/

- admin:
- cat /home/geeth/.local/share/dmctp-jenkins/home/secrets/initialAdminPassword
- d5a99101003348389f858c28b8224d41
- user:
- geethwa03@gmail.com
- pw:    geeth
- uname: geeth

## Daily use
- An ordinary commit requests the fast smoke tier:
```bash
git add <files>
git commit -m "message"
```
- A completed change requests presubmit:
```bash
git add <files>
git commit -m "message [presubmit]"
```
- it polls every 2 minutes

## Nightly and weekly jobs run on their schedules without a commit.

Use **Build with Parameters** on `dmctp-local-ci` for a manual run. `CI_TIER`
chooses the tier and `SUITES` optionally limits it to comma separated suite
IDs.

Nightly: every day    @ 09:13
Weekly : every Sunday @ 03:01

## Trigger policy

| Trigger                         | Tier             | Expected duration   |
|---                              |---               |---:                 |
| Ordinary local commit           | `smoke`          | under 5 minutes     |
| Commit containing `[presubmit]` | `presubmit`      | 5–30 minutes        |
| Manual `dmctp-local-ci` build   | selected by user | -                   |
| `dmctp-nightly-ci` timer        | `nightly`        | may take hours      |
| `dmctp-weekly-ci` Sunday timer  | `weekly`         | may take many hours |

- tiers are cumulative


## Suite catalog and results

- a suite produces:

```text
regressions/results/
├── dmctp-local-ci/
│   ├── latest -> build-<number>
│   └── build-<number>/
│       ├── SUMMARY.md
│       └── suites/
│           └── <suite-id>/
│               ├── console.log
│               ├── junit.xml
│               └── status.json
├── dmctp-nightly-ci/
└── dmctp-weekly-ci/
```

`SUMMARY.md`  - summary of result
`status.json` - machine parsable result
`console.log` - terminal dump
`@`           - temp directories Jenkins created to so parralle tasks
                wont collide


Run a suit
```bash
python3 regressions/ci/run_suite.py rtl-filelists
```
this writes to
```text
regressions/results/local/latest/suites/<suite-id>/
```
Run a simulator matrix
```bash
python3 regressions/ci/simulator_matrix.py \
  --mode boot --configs current --timeout-seconds 1200
```

## Adding coverage

To add a verification flow:
1. Provide a deterministic non interactive command that returns nonzero on
   failure.
2. Keep generated data under `build/`.
3. Add the command to `suites.json` at the cheapest appropriate tier.
4. Add any new supported SoC configuration to `configurations.json`.
5. Extend the CI self tests.

