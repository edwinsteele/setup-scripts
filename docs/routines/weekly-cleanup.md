# Weekly cleanup — project rules

Read by the `weekly-cleanup` skill when this repo's weekly cleanup routine
runs. The skill holds the general procedure; this file holds only what is
specific to this repo. Where they disagree, this file wins.

## Issue filing

Propose only. List proposed issues in the summary; never run `gh issue create`.

## Doc changes

Doc-only fixes are committed and pushed straight to `master`. This repo has no
PR workflow.

## Leave alone

- `ansible/roles/*/files/` and any vendored third-party copies.

## Memory

This repo has no `docs/memory/`; technical memory lives only in Claude's
private project memory. Consolidate it fully (see skill Part 2b).
