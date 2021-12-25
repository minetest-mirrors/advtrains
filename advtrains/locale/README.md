# Translations
Please read this document before working on any translations.

## Getting Started
If there is a translation file for your language (e.g. German), you can edit the file directly. Please read [the documentation on the translation file format](https://minetest.gitlab.io/minetest/translations/#translation-file-format) for more information.
If the translation file for your language needs to be created, create it by copying `template.txt` to `advtrains.XX.tr`, where `XX` is replaced by the language code.

## Translation Notes
* Translations should be consistent. Use translations in Minetest as a reference.
* Replacement sequences (`@1`, `@2`, etc) should not be translated.
* Certain abbreviations or names, such as "Ks" or "Zs 3", should generally not be translated.

### (de) German
* Verwenden Sie die neue Rechtschreibung und die Sie-Form
* Mit der deutschen Tastaturbelegung unter Linux können die Anführungszeichen „“ durch AltGr-V bzw. AltGr-C eingegeben werden.

### (zh) Chinese
(This section is written in English to avoid writing the note twice or using only one of the variants, as most of this section applies to both the traditional and simplified variants.)
* Please use the 「」 quotation marks for Traditional Chinese and “” for Simplified Chinese.
* Please use the fullwidth variants of: ， 、 。 ？ ！ ： ；
* Please use the halfwidth variants (i.e. variants used with Latin alphabets) of: ( ) [ ] / \ |
* Please do not leave any space between Han characters (including fullwidth punctuation marks).
* Please leave a space between Han characters (excluding fullwidth punctuation marks) and characters from other scripts (including halfwidth punctuation marks). However, do not leave any space between Han characters and Arabic numerals.
