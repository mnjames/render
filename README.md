# Render

Combines data from several XML files to create a single SILE XML document
that can generate a well-formatted PDF document.

#### Specifics:

A human translator provides the following files:

* `Raw_interlinear.xml` contains a series of Bible verses and a maps
  each greek word to its translated Urdo equivalent.
* `SSV.usx` contains a literal Urdo translation.
* `SSV_Lit.usx` contains a more readable Urdo translation.
* `ALEPH.usx` contains notes on the Urdo translation organized by verse.

See https://app.thedigitalbiblelibrary.org/static/docs/usx/index.html
for a description of the `.usx` (XML) data format.

A Lua script combines this data into a single XML file with SILE markup
commands such that each page description contains a series of verses
with these four parts:

* Greek to Urdo interlinear
* Literal Urdo translation
* More readable Urdo translation
* Notes on the translation

Page breaks are added to keep related verses and notes on the same page.
See the file `books/mockup.pdf` for an example.

#### File organization:

Input files: Each book of the Bible is stored in a separate folder in the `books`
sub folder:  e.g. `books/JHN`.
Each book of the Bible is defined by the four files described above.

Output file: Output files are stored in the `output` sub folder.
The rendered document is stored in a `pdf` using the book's name. e.g. `output/JHN`

#### To execute the software:

To render chapters of a book, specify the book folder name, the starting
and ending chapters and the maximum number of verses per chapter:
```
./render JHN --minChapter 3 --maxChapter 5 --verse 14`.
```

This will output the first 14 verses of chapters 3, 4 and 5 of `JHN` and
render them into a single PDF.

The argument `maxChapter` must always be defined. If `minChapter` is not
defined, it defaults to `1`. If `verse` is not defined, it renders every
verse defined in the data files.

#### Software Setup and Initial File Downloads

1. Install the `Lua` programming language:
    * Macintosh: `brew install lua`

2. Install the `Lua` package manager called luarocks:
    * Macintosh: `brew install luarocks`

3. Install a `Lua` module that performs XML parsing called `lxp`
    * Macintosh: `luarocks install luaexpat`

4. Install `SILE` which performs the formatted rendering to a pdf:
    * Macintosh: `brew install sile`

5. Install `ghostscript`:
    * Macintosh: `brew install ghostscript`

6. Download fonts:
    * Download `Awami Nastaliq` (Arabic font) from https://software.sil.org/awami/download/
    * Download `SBL_grk` (Greek) from http://www.bible-researcher.com/sblgreek.html

7. Install fonts:
    * Macintosh: Copy the `.ttf` (True Type Font) files to `/Library/Fonts`
