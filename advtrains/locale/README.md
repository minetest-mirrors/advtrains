# Translations
**Please note that this document is outdated as transition to `.po`
files is currently in progress.**

Please read this document before working on any translations.

## Getting Started
If there is a translation file for your language (e.g. German), you can
edit the file directly. Please read [the documentation on the
translation file format][tr-format].

Alternatively, Advtrains provides a script named `gui` that can be used
to, among other things, edit translation files. The script requires
Tcl/Tk 8.6, which is provided by most Linux distributions.

If the translation file for your language does not exist, create it by
copying `template.txt` to `advtrains.XX.tr`, where `XX` is replaced by
the language code.

Feel free to use the [discussion mailing list][srht-discuss] if you
have any questions regarding localization.

You can share your `.tr` file directly or [as a patch][gsm] to the [dev
mailing list][srht-devel]. The latter is encouraged, but, unlike code
changes, translation files sent directly are also accepted.

[tr-format]: https://minetest.gitlab.io/minetest/translations/#translation-file-format
[srht-discuss]: https://lists.sr.ht/~gpcf/advtrains-discuss
[srht-devel]: https://lists.sr.ht/~gpcf/advtrains-devel
[gsm]: https://git-send-email.io

## Translation Notes
* Translations should be consistent. You can use other entries or the
translations in Minetest as a reference.
* Translations do not have to fully correspond to the original text -
they only need to provide the same information. In particular,
translations do not need to have the same linguistical structure as the
original text.
* Replacement sequences (`@1`, `@2`, etc) should not be translated.
* Certain abbreviations or names, such as "Ks" or "Zs 3", should
generally not be translated.

### (de) German
* Verwenden Sie die neue Rechtschreibung und die Sie-Form.
* Mit der deutschen Tastaturbelegung unter Linux können die
Anführungszeichen „“ mit AltGr-V bzw. AltGr-B eingegeben werden.

### (zh) Chinese
(This section is written in English to avoid writing the note twice or
using only one of the variants, as most of this section applies to both
the traditional and simplified variants.)

* Please use the 「」 quotation marks for Traditional Chinese and “”
for Simplified Chinese.
* Please use the fullwidth variants of: ， 、 。 ？ ！ ： ；
* Please use the halfwidth variants of: ( ) [ ] / \ |
* Please do not leave any space between Han characters (including
fullwidth punctuation marks).
* Please leave a space between Han characters (excluding fullwidth
punctuation marks) and characters from other scripts (including
halfwidth punctuation marks). However, do not leave any space between
Han characters and Arabic numerals.

## Notes for developers
* Avoid word-by-word translations.
* Avoid manipulating translated strings (except for concatenation). Use
server-side translations if you have to modify the text sent to users.
* Avoid truncating strings unless multibyte characters are handled
properly.
