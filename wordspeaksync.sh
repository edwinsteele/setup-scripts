#!/bin/sh

SITE_BASE="/Users/esteele/Code/wordspeak.org"

VENV=$(basename $VIRTUAL_ENV)
pushd $SITE_BASE
# Not sure how to do this programatically
if [ "$VENV" == "nikola-dev" ]; then
  NIKOLA=~esteele/Code/nikola-edwinsteele/nikola/scripts/nikola;
else
  NIKOLA=$(which nikola);
fi

$NIKOLA build

# Git check
git_output=$(git status -s)
if [ -n "$git_output" ]; then
  echo "Git status output:"
  git status -s;
  echo "Git status is unclean. Continue? [y/n]";
  read response;
  if [ "$response" != "y" ]; then
    echo "Aborting";
    exit 1
  fi
fi

echo "Syncing to staging site"
# Local rsync
rsync --del -a $SITE_BASE/output/ /Users/esteele/Sites/staging.wordspeak.org
rsync --del -a $SITE_BASE/output/.htaccess /Users/esteele/Sites/staging.wordspeak.org

# Check for broken links
linkchecker --ignore-url=^mailto: --no-status http://staging.wordspeak.org

if [ $? -eq 1 ]; then
  echo "Errors found. Continue? [y/n]";
  read response;
  if [ "$response" != "y" ]; then
    echo "Aborting";
    exit 1
  fi
fi

echo "Push to live site? [y/n]";
read response;
if [ "$response" != "y" ]; then
	echo "Not pushing."
	exit 1
else
	printf "Pushing to live site..."
fi

# Final rsync
rsync -e ssh --del -az $SITE_BASE/output/ wordspeak.org:/users/home/esteele/web/public
rsync -e ssh --del -az $SITE_BASE/output/.htaccess wordspeak.org:/users/home/esteele/web/public

echo "done."
printf "Pushing repo to git..."
git push
echo "done."
popd
