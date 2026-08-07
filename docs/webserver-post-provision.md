# Webserver: manual steps after provisioning

Once `site.yml` has run against a freshly provisioned webserver, finish
bringing it into service:

1. As root on the new VM (ssh session with agent forwarding enabled):
   ```bash
   openrsync -av www.wordspeak.org:/etc/ssl/wordspeak.org/ /etc/ssl/wordspeak.org/
   openrsync -av www.wordspeak.org:/etc/ssl/private/wordspeak.org/ /etc/ssl/private/wordspeak.org/
   rcctl restart nginx
   ```
2. As `esteele` on the new VM (ssh session with agent forwarding enabled):
   ```bash
   for d in images.wordspeak.org language-explorer.wordspeak.org staging.wordspeak.org www.wordspeak.org; do
     openrsync -av www.wordspeak.org:/home/esteele/Sites/$d/ /home/esteele/Sites/$d/
   done
   cd ~/Code/dotfiles && ./make.sh
   ```
3. Flip DNS to point to the new host.
4. `doas acme-client -v wordspeak.org && rcctl restart nginx`

## Additional webserver-specific steps

1. Update the DNS record for `staging.wordspeak.org` (do this first, since
   nobody is watching staging - simplifies the final cutover).
2. `rsync -av --rsync-path=/usr/bin/openrsync /usr/local/var/www/lex-mirror/ staging.wordspeak.org:/var/www/htdocs/language-explorer.wordspeak.org/`
3. In the `images.wordspeak.org` checkout, run `./images_tool.py sync`.
4. Run the GitHub Actions deploy.
