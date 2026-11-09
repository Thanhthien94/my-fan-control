# Contributing

Open feature/fix PRs against `develop`. Keep `main` for release source. Branch from an up-to-date `develop` using `feature/<short-name>` or `fix/<short-name>`. Use Conventional Commits (`feat`, `fix`, `test`, `docs`, `ci`, `chore`). Do not commit generated bundles, private device snapshots, credentials or third-party binaries.

Run `./script/test.sh` and `./script/build_and_run.sh --build-only` before opening a PR. Hardware-independent tests must not write SMC keys. Changes to SMC packets, encodings, write order, mode restoration or privilege boundaries need focused tests with failure injection, plus separately documented manual hardware validation.

For hardware reports include Mac model/chip, macOS version, fan limits, relevant SMC keys, expected/actual behavior and whether another fan controller was running. Redact identifying information. Do not attach a full system report by default.

To prepare a release, branch `release/<version>` from `develop`, update validation/release notes, merge the approved release into `main`, create an annotated SemVer tag, and merge the release changes back into `develop`. Hotfixes start from `main` and flow to both branches. Never force-push `main` or `develop`.

The CI workflow builds and runs fake-hardware tests; green CI does not establish compatibility with a physical Mac. Hardware support claims must name the actual tested machine and actions. Public artifacts are distributed only with their signing/notarization status and remaining verification gaps stated.
