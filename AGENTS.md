# Agent instructions

## Landing changes

This repo has no PR workflow. Commit every change, code included, and push
it straight to `master`. Don't open a PR or run `/ticket-to-pr`. This
overrides the global rule that routes non-doc changes through a PR. The
private `local_setup-scripts` overlay works the same way.

Pushing to `master` doesn't apply anything to a live host. Running a
playbook against the gateway or viking is a separate step that still needs
the owner's go-ahead.
