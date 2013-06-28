#!/bin/bash

LOGFILE=~/log/gunicorn/sensorsproject.log
LOGDIR=$(dirname $LOGFILE)
NUM_WORKERS=3

USER=esteele
GROUP=esteele
cd ~/sensorsproject
source ~/.virtualenvs/sensors27/bin/activate
test -d $LOGDIR || mkdir -p $LOGDIR

DJANGO_SETTINGS_MODULE=sensorsproject.prod_settings
exec gunicorn -b 0.0.0.0:8001 sensorsproject.wsgi:application
