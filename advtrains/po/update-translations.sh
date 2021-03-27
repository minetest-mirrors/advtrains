#!/bin/sh
# NOTE: Please make sure you also have basic_trains installed, as it uses attrans for historical reasons

ATDIR=`dirname "$0"`/../..
BTDIR="$ATDIR"/../basic_trains

xgettext \
	-D "$ATDIR" \
	-D "$BTDIR" \
	-d advtrains \
	-p . \
	-L lua \
	--from-code=UTF-8 \
	--keyword='attrans' \
	--keyword='S' \
	--package-name='advtrains' \
	--msgid-bugs-address='advtrains-discuss@lists.sr.ht' \
	`find $ATDIR $BTDIR -name '*.lua' -printf '%P\n'` \
	&&
mv advtrains.po template.pot &&
for i in *.po; do
	msgmerge -U \
		$i template.pot
done
