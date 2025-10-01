# Translations
Please read this document before working on any translations.

## Getting Started
Advtrains uses `.po` files for localization. These can be edited with
a regular text editor or with specialized programs (e.g. Poedit).

If the translation file for your language does not exist, you can
create it using:

`msginit -l LL -o <domain>.LL.po`

where `LL` is the language code and `<domain>` is the "domain" of the
translation file (which, for the Advtrains modpack, corresponds to the
name of the mods, e.g. `advtrains_interlocking`).

Feel free to use the [discussion mailing list][srht-discuss] if you
have any questions regarding localization.

You can share your `.po` file directly or [as a patch][gsm] to the [dev
mailing list][srht-devel]. The latter is encouraged, but, unlike code
changes, translation files sent directly are also accepted.

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
* The `update-translations.sh` script can be used to update the
translation files.
* Please make sure that the first argument to `S` _only_ includes
string literals without formatting or concatenation. This is
unfortunately a limitation of the `xgettext` utility.
* Avoid word-by-word translations.
* Avoid manipulating translated strings (except for concatenation). Use
server-side translations if you have to modify the text sent to users.
* Avoid truncating strings unless translations and multibyte characters
are handled properly.
