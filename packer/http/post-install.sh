#!/bin/sh

echo "Mirror is " $1
ftp -o /SHA256 $1/pub/OpenBSD/5.9/SHA256
echo "hello";
