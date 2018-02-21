#!/bin/sh

# Copy current LE certs and domain privkeys over the top of existing
#  (probably outdated) certs. Outdated certs are pushed as a part of
#  initial setup simply so nginx can start

for domain in $(echo "wordspeak.org connectbox.org"); do
	for cert in $(echo "cert fullchain chain"); do
		file="/etc/ssl/letsencrypt/${domain}/${cert}.pem"
		scp root@origin.wordspeak.org:$file $file
		chmod 444 $file
		ls -l $file
	done
	file="/etc/ssl/letsencrypt/private/${domain}/privkey.pem"
	scp root@origin.wordspeak.org:${file} ${file}
	chmod 400 $file;
	ls -l $file
done
