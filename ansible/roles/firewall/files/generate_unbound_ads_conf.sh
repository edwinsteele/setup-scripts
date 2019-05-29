#!/bin/ksh

new_ads_conf=$(mktemp /tmp/generate_ads_conf.XXXXXXXX)

# StevenBlack
ad_lists[0]="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
# MalwareDom
ad_lists[1]="https://mirror1.malwaredomains.com/files/justdomains"
# Cameleon
ad_lists[2]="http://sysctl.org/cameleon/hosts"
# ZeusTracker
ad_lists[3]="https://zeustracker.abuse.ch/blocklist.php?download=domainblocklist"
# DisconTrack
ad_lists[4]="https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt"
# DisconAd
ad_lists[5]="https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt"

for ad_list in ${ad_lists[*]}
do
  echo "Processing: $ad_list";
  curl -o - -s "$ad_list" |
    grep '^0\.0\.0\.0' |
    awk '{print "local-zone: \""$2"\" redirect\nlocal-data: \""$2" A 0.0.0.0\""}' >> ${new_ads_conf}
done

echo $new_ads_conf

cp $new_ads_conf /var/unbound/etc/unbound-adhosts.conf 
