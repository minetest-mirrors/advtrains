#!/bin/sh

head -n18 ../po/template.pot | sed 's/charset=CHARSET/charset=UTF-8/'
sed -En 's/@n/\\n/g;s/@\n/\\n/g;s/\"/\\"/g;s/^([^=]+)=\1$/\1=/;s/^([^=]+)=([^=]*)$/\nmsgid "\1"\nmsgstr "\2"/gp'
