#!/bin/sh
for i in advtrains.*.tr; do
	${LUA:-luajit} update-l10n.lua $i && mv $i.new $i;
done
