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
5. **The `[Recordings]` Samba share needs an SELinux boolean, not the
   usual `sefcontext`/`restorecon` fix.** `tvheadend_recordings_path` is
   bind-mounted into the container with the `:Z` flag (see the Quadlet
   template), so Podman relabels it `container_file_t` on every container
   start - a one-off `semanage fcontext` + `restorecon` (the
   `samba_media`/`samba_timemachine` roles' approach for their own shares)
   would just get overwritten on the next restart. This role instead
   enables the `samba_export_all_rw` SELinux boolean, which lets `smbd`
   read/write any file regardless of its type. That's a host-wide toggle,
   but it's inert for the other shares - their content already carries the
   correct `samba_share_t` label.
6. **Guest deletes need the recordings *directory's* Unix permissions
   fixed too, not just `smb.conf`.** `[Recordings]` is deliberately
   `guest ok = yes` + `read only = no` (unlike `[Media]`, which stays
   read-only) so Infuse can delete watched recordings with no login
   prompt. But Unix delete permission is governed by the *parent
   directory's* write+execute bits for the acting identity, not the
   file's own permissions - and Samba's guest connections map to the
   `nobody` account (uid 65534 on Rocky, confirmed via `id nobody`, no
   `guest account` override set), which isn't in `esteele`'s group. So the
   recordings directory's group is set to `tvheadend_recordings_guest_group`
   (`nobody`) with mode `0775`, giving that group the write bit it
   actually needs - an `smb.conf` permission change alone wouldn't have
   been enough.

## Still open / not automated by this role

- **DVB network setup and channel scan** aren't done by this role - that's
  a one-time interactive step (Configuration > DVB Inputs > Networks > add
  a DVB-T network, pick the closest predefined scanfile region e.g.
  `Australia: au-Sydney`, enable it on the tuner adapters). Tvheadend ships
  1171+ predefined DVB-T mux lists across 46 regions built in, so this
  doesn't need external scan files for normal use.
- **Live TV in a browser doesn't work, and can't without a rebuild.**
  Confirmed directly against the running container (`ldd`/`find` show no
  `libavcodec`/`libx264`/`libfdk-aac` anywhere, and `tvheadend --version`
  matches the Dockerfile's `--disable-libav` build flag): this image ships
  with zero transcoding support compiled in, at all - not a setting. The
  `matroska` playback profile is a pure remux, so AC-3 audio (what AU DVB-T
  actually broadcasts) passes through unchanged, and no mainstream browser
  can decode AC-3 natively - hence "An unknown error occurred" in the web
  player regardless of which profile is picked. VLC (or any real media
  player, not a browser) pointed at `/stream/channel/<uuid>?profile=pass`
  works fine, since it has its own AC-3 decoder. Fixing the in-browser
  player for real would mean compiling Tvheadend from source with
  `--enable-libav`, or switching to a different community image that
  bundles it - not attempted, since live TV is a rare use case here
  (recording/playback is the actual goal) and Infuse decodes AC-3 natively
  for recorded files regardless.
- ~~First real recording, played back via Infuse over Samba~~ **Done** -
  confirmed working end to end: a real recording landed on disk and played
  back correctly through Infuse over the `[Recordings]` share, including
  no-login deletion once the recordings directory's group/mode were fixed
  (gotcha 6 above) - and confirmed `[Media]` correctly stayed undeletable
  throughout, since the two shares' permissions are independent.

The core PoC is complete: tuner driver, Tvheadend, channel mapping, both
Samba shares, and a real recording all confirmed working end to end. What
remains above (DVB scan being a one-time manual step, no browser Live TV)
are known, accepted limitations, not open work.

## Service-to-channel mapping via the API

The web UI's "Services tab, select all, Map selected services" button is a
thin wrapper over `/api/service/mapper/save` - scriptable once you know the
payload shape (not discoverable from the API alone; found by reading
Tvheadend's own source, `src/service_mapper.c` + `src/api/api_idnode.c`):

- The endpoint takes a form-encoded `node` field whose *value* is itself a
  JSON object - `htsmsg_field_get_msg()` in Tvheadend's `htsmsg.c`
  transparently deserializes any string-typed field that looks like JSON,
  which is what makes this work.
- That object's `services` key is a list of service UUIDs (from
  `/api/service/list`); the rest are the same boolean options the UI
  exposes (`check_availability`, `encrypted`, `merge_same_name`, etc).
- The endpoint is `ACCESS_ADMIN`-gated in Tvheadend's source, but worked
  unauthenticated here - the `--firstrun` unauthenticated-access rule (see
  gotcha 4 above) grants it.

```bash
curl -s 'http://viking.home.wordspeak.org:9981/api/service/list' | \
  python3 -c "import json,sys; print(json.dumps([e['uuid'] for e in json.load(sys.stdin)['entries']]))"
# then POST {"services": [...], "check_availability": false, "encrypted": true,
#   "merge_same_name": false, "merge_same_name_fuzzy": false,
#   "tidy_channel_name": false, "type_tags": true, "provider_tags": false,
#   "network_tags": false} as the urlencoded "node" field to
#   /api/service/mapper/save, then poll /api/service/mapper/status for
#   {"total","ok","fail"} counts.
```
