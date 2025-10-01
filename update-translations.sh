#!/bin/sh

MSGID_BUGS_ADDR='advtrains-discuss@lists.sr.ht'

for MODPATH in `dirname "$0"`/advtrains*; do
	MODNAME=`basename "$MODPATH"`
	PODIR="$MODPATH/locale"
	POTFILE="$PODIR/$MODNAME.pot"
	[ -d "$PODIR" ] &&
	xgettext \
		-D "$MODPATH" \
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
		`find "$MODPATH" -name '*.lua' -printf '%P\n'` \
		&&
	for i in "$PODIR"/*.po; do
		msgmerge -U \
			--sort-by-file \
			$i "$POTFILE"
	done
done
