# Release Guide

## Versioning

Semantic versioning on git tags: `vMAJOR.MINOR.PATCH` (`v1.0` is the first release of the template; `v1.0.1` for fixes).

- **Major**: breaking change for projects created from the template (variable renames, state moves, bootstrap changes that need manual steps).
- **Minor**: new capability that existing projects can adopt without manual steps.
- **Patch**: fixes and documentation.

Every release has notes in `docs/releases/vX.Y.md`.

## Release process

1. Everything is merged to `main` and the latest Pipeline run on `main` is green.
2. `terraform plan` in both stacks shows no changes (`-detailed-exitcode` is 0).
3. Documentation matches behaviour: README, guides, and the review report's hard-coded value list.
4. Write or update `docs/releases/vX.Y.md` (notes, architecture and security summaries, lessons, limitations).
5. Tag and push:

```bash
git tag -a v1.0 -m "v1.0: initial release of the platform template"
git push origin v1.0
```

6. Optionally create a GitHub Release from the tag (Releases -> Draft a new release -> choose tag -> paste the notes), or `gh release create v1.0 --notes-file docs/releases/v1.0.md`.

Tags do not trigger the pipeline (it runs only on pushes to `main` and manually).

## Using a release as the template

Projects should start from a tag, not from `main`:

```bash
git clone --branch v1.0 --depth 1 https://github.com/<owner>/<template> <new-project>
```

## Hotfixes

Fix on `main`, run the pipeline, tag `vX.Y.Z+1`. There are no long-lived release branches.
