#!/bin/sh

cd /home/calicobill/perl
plackup -o localhost -p 16387 -E production -s Starman -D /home/calicobill/perl/bin/app.pl
