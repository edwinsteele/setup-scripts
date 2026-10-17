# gitdeck

Runs [Gitdeck](https://github.com/debba/gitdeck), a web dashboard over
Edwin's GitHub repos, issues, PRs, notifications and CI, on `viking` as a
rootful Podman Quadlet unit, using upstream's published image
(`ghcr.io/debba/gitdeck`). It follows the same pattern as `roles/tvheadend`
and `roles/home_assistant`, so systemd starts it at boot and restarts it if
it exits.

Reachable at:

- `http://viking.home.wordspeak.org:8765/` on the LAN, or
  `http://viking:8765/` over Tailscale (MagicDNS)
- `http://gitdeck.home.wordspeak.org/` via `roles/reverse_proxy` (needs the
  DNS alias - see that role's README)

## No login on the dashboard itself

Gitdeck has no authentication of its own: it's designed as a single-user
local tool, and whoever can reach the port uses the signed-in GitHub
account, including the few write actions it has (such as moving items on a
Projects board). This is accepted for viking - it's only reachable from the
LAN and the tailnet. Revisit if either of those widens.

## One-time setup: GitHub OAuth App

Gitdeck signs in with GitHub's Device Flow, which needs an OAuth App's
Client ID (no client secret).

1. <https://github.com/settings/developers> -> **OAuth Apps** ->
   **New OAuth App**. Name it e.g. `Gitdeck (viking)`, and set both the
   homepage and callback URL to `http://viking.home.wordspeak.org:8765`
   (Device Flow doesn't use the callback, but GitHub requires one).
2. On the app's page, tick **Enable Device Flow** and save. Without it,
   sign-in fails with `unsupported_grant_type`.
3. Copy the **Client ID** into `gitdeck_github_client_id` in
   `host_vars/viking.home.wordspeak.org.yml` and re-run the play.
4. Open the dashboard. It shows a code to enter at
   <https://github.com/login/device>. The resulting token is stored in
   `gitdeck_data_path` on viking and never reaches the browser.

To revoke access, remove the app under
<https://github.com/settings/applications> and delete the token file under
`gitdeck_data_path`.

## Updating

`gitdeck_image` is pinned to a release tag (`v1.0.9`). Don't switch it to
`:latest` or add an `AutoUpdate=` label to the Quadlet unit: upstream's CI
republishes `:latest` (and `:main`) on every push to their main branch, so
either would deploy unreleased code. Every release tag gets its own image.

To upgrade:

1. Check <https://github.com/debba/gitdeck/releases> (or watch the repo for
   releases only) and read `CHANGELOG.md` for the new version.
2. Bump the tag in `defaults/main.yml`, commit, and re-run the play with
   `--tags gitdeck`. The changed unit file triggers a restart, and Quadlet
   pulls the new tag on start.

The project is young (first release April 2026, mostly one maintainer) and
describes itself as early-stage, so read the changelog before jumping
several versions. To roll back, put the old tag back and re-run.

## Running the play

```bash
cd ansible
ansible-playbook -i inventory.yml site.yml --tags gitdeck,reverse_proxy \
  --limit viking.home.wordspeak.org
```

## Verifying

```bash
ssh viking.home.wordspeak.org "systemctl status gitdeck --no-pager; curl -s localhost:8765/api/auth/status"
```

`systemctl status` should show the unit active, and the status endpoint
should return JSON.
