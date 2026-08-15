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

Same pattern as [nut_ups](../nut_ups/README.md): real credentials live in
the private `local_setup-scripts` overlay, not this repo.

- **OpenBSD**: the whole secrets file is pulled in wholesale from
  `local_setup-scripts/ansible/roles/common/files/etc_mail_secrets`
  (already existed before this role gained a Rocky branch).
- **Rocky/RedHat**: `mail_sender_relay_username` and
  `mail_sender_relay_password` must be set via
  `local_setup-scripts/ansible/roles/mail_sender/vars/private_vars.yml`
  (pulled into the `rocky_9` play by `vars_files` in `site.yml`). Same
  Fastmail account the OpenBSD hosts relay through
  (`mail_sender_relay_host`, default `mail.messagingengine.com:465`) - use
  a Fastmail app password, not the account password, and treat it as
  sensitive (it's templated into `/etc/postfix/sasl_passwd` with
  `no_log: true` so it never hits the ansible log).

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
