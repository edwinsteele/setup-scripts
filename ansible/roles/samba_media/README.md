# samba_media

Owns the `Media` share on `viking`: mounts the `Data`-labelled XFS
partition (`sdb2`, see [samba_server](../samba_server/README.md#disk-layout)
for the full disk layout) at `/srv/media`, and shares the `Media Archive`
subfolder within it (`/srv/media/Media Archive`, `samba_media_share_path`)
- not the partition root. The root also holds `.fseventsd`/
`.Spotlight-V100`, leftover macOS metadata directories from the disk's
previous life as an APFS volume, copied along with everything else during
the rsync onto this partition - deliberately excluded from the share by
pointing `path` at the subfolder instead. Ownership and the SELinux
`samba_share_t` context are set on that subfolder, not the mount root.
Plain file share - no Time Machine (`fruit`) options, no Bonjour
advertisement. Used as an Infuse library on Apple TV.

It doesn't install Samba, own `smb.conf`, or manage the `smb` service -
that's [samba_server](../samba_server/README.md), which reads this role's
`samba_media_*` defaults to render the `[Media]` share stanza. See that
role's README for installation, networking, running the play, and the
Samba password setup step.

Browsable at `smb://viking.home.wordspeak.org/Media` - add it as an Infuse
library on the Apple TV using the same `esteele` credentials.
