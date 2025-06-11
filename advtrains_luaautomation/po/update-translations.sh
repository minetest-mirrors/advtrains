#!/bin/sh

MODNAME="advtrains_luaautomation"
MSGID_BUGS_ADDR='advtrains-discuss@lists.sr.ht'

PODIR=`dirname "$0"`
ATDIR="$PODIR/.."
POTFILE="$PODIR/$MODNAME.pot"

xgettext \
	-D "$ATDIR" \
	-d "$MODNAME" \
	-o "$POTFILE" \
	-p . \
	-L lua \
	--add-location=file \
	--from-code=UTF-8 \
	--sort-by-file \
	--keyword='S' \
	--package-name="$MODNAME" \
	--msgid-bugs-address="$MSGID_BUGS_ADDR" \
	`find $ATDIR $BTDIR -name '*.lua' -printf '%P\n'` \
	&&
for i in "$PODIR"/*.po; do
	msgmerge -U \
		--sort-by-file \
		$i "$POTFILE"
done
