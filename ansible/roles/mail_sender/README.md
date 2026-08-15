# mail_sender

Configures each host to relay outbound mail (root's local mail, `smartd`
warnings, cron output, etc.) out through Fastmail rather than delivering
it directly - no host here has a public IP suited to running its own
outbound MTA. Dispatches by `ansible_facts['os_family']`, like
`common`/`esteele_acct`: OpenBSD hosts use `opensmtpd`
(`tasks/OpenBSD.yml`), Rocky hosts use `postfix` as a relay-only satellite
(`tasks/RedHat.yml`, added 2026-08-16 - previously Rocky hosts had no MTA
at all, which is why `samba_server`'s `smartd` had no mail alerting until
this existed).

Both branches forward root's mail to `mail_sender_root_forward` (default
`edwin@wordspeak.org`).

## Prerequisites (outside this repo)

Same private `local_setup-scripts` overlay file the OpenBSD branch has
always used: `roles/common/files/etc_mail_secrets`
(`mail_sender_secrets_file`), an OpenBSD smtpd `secrets` table (one line
per label, `label user:pass`). The Rocky/RedHat branch doesn't get its own
copy of the credential - `tasks/RedHat.yml` parses the
`mail_sender_secrets_label` (default `fastmail`) line out of that same
file at run time (`no_log: true` on both tasks that touch the plaintext,
so it never hits the ansible log) and uses it to authenticate postfix's
relay the same way `opensmtpd`'s `auth <secrets>` does. Nothing to set up
here beyond what OpenBSD's branch already needed - if that file doesn't
have a `fastmail` line, this branch fails with an unhelpful Jinja error
rather than a friendly one, since that state shouldn't be reachable (the
OpenBSD hosts already depend on it existing).

## Rocky/RedHat design notes

`postfix` is configured as a relay-only satellite, not a full MTA:
`inet_interfaces = loopback-only` (never accepts mail from the network),
and `relayhost` points at Fastmail over implicit TLS
(`smtp_tls_wrappermode`) with SASL auth from `/etc/postfix/sasl_passwd`
(hashed via the `postmap` handler after every template change). Local
processes still hand mail to it via the standard `sendmail` binary/`mail`
command postfix provides - that's what lets `smartd`'s default warning
script (see `samba_server`) work without any extra plumbing.

## Verifying

```bash
ssh viking.home.wordspeak.org "echo 'mail_sender test' | mail -s 'mail_sender test' root"
ssh viking.home.wordspeak.org "sudo tail -20 /var/log/maillog"
```

Should show the message queued and relayed (`status=sent`) rather than
deferred/bounced, and it should arrive at `mail_sender_root_forward`.
