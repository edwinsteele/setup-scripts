# tvheadend

Runs [Tvheadend](https://tvheadend.org/) (TV streaming server / DVR) as a
Podman Quadlet unit, using the tuner set up by `roles/dvb_tuner`. Requires
that role to have run first (`site.yml` orders them accordingly).

## Why a container, not an RPM

No RHEL9/Rocky9 RPM exists for Tvheadend in any repo (checked
BaseOS/AppStream/EPEL/CRB and Tvheadend's own site) - same DVB-adjacent
packaging gap as `roles/dvb_tuner`'s kernel drivers. Rather than build from
source, this uses Tvheadend's official container image
(`ghcr.io/tvheadend/tvheadend`), matching how `roles/home_assistant`
already runs on this box - one less bespoke pattern to maintain.

## Gotchas hit getting this working (all handled by the role, documented
here so they don't need rediscovering)

1. **Rootless Podman breaks bind-mount permissions.** Rootless Podman
   remaps container UIDs into the calling user's *subordinate* UID range,
   not the literal host UID - so a bind-mounted directory owned by host
   UID 1000 doesn't match what a rootless container's "UID 1000" process
   actually runs as, and writes fail with `Permission denied`. This role
   uses root-level Podman (via Quadlet's default `.container` handling,
   same as `home_assistant`) to sidestep this entirely.
2. **The tuner devices need a supplementary group, not just `--device`.**
   `/dev/dvb/adapter*/*` are group-owned (GID 39, "video," *inside the
   container's own `/etc/group`* - check this again if the upstream image
   changes) and the container's default user isn't a member. Without
   `--group-add {{ tvheadend_device_gid }}`, Tvheadend detects zero
   tuners (`/api/idnode/load?class=linuxdvb_frontend` returns empty) even
   though the device nodes are correctly passed through.
3. **`firewalld` blocks the ports by default.** Same class of gap as the
   HomeKit Bridge incident on this box - a new service's ports need
   explicit opening, they're never open by default. Handled by this role's
   `firewalld` tasks.
4. **A brand-new config needs `--firstrun` or nothing can log in.** Without
   it, a fresh Tvheadend has zero ACL/user entries and every request
   (including blank-credential attempts) 401s - there's no way in at all.
   `--firstrun` seeds an initial unauthenticated-access rule. See the
   Quadlet template's comment for the security note on this long-term.

## Still open / not automated by this role

- **DVB network setup and channel scan** aren't done by this role - that's
  a one-time interactive step (Configuration > DVB Inputs > Networks > add
  a DVB-T network, pick the closest predefined scanfile region e.g.
  `Australia: au-Sydney`, enable it on the tuner adapters). Tvheadend ships
  1171+ predefined DVB-T mux lists across 46 regions built in, so this
  doesn't need external scan files for normal use.
- **Service-to-channel mapping** (Services tab, select all, "Map selected
  services") also hasn't been scripted - found while building this role
  that the underlying `/api/service/mapper/save` endpoint needs a payload
  shape that wasn't determined from the API alone; doing it via the web UI
  is a two-click action and more reliable than guessing further.
- **No Samba share for `tvheadend_recordings_path` yet.** The directory is
  a sibling of `samba_media`'s "Media Archive" (see the default's comment
  for why that's safe/inert until a share is actually configured), but
  nothing exposes it over SMB yet - Infuse can't browse recordings until
  either a new `[Recordings]` stanza is added to `samba_server`'s
  `smb.conf.j2`, or the directory is moved under the existing `[Media]`
  share's path. Not decided yet which.
- **First real recording, played back via Infuse over Samba** - the actual
  "does it work end to end" proof - hasn't been done. Tuning and service
  discovery are confirmed working (a manual DVB-T scan found real,
  correctly-named Sydney services), but nothing has been recorded to disk
  and played back yet.
