# Render

Combines data from several XML files to create a single SILE XML document
that can generate a well-formatted PDF document.

Specifics:

    A human translator provides the following files:

    * Raw_interlinear.xml (xml) contains a mapping from greek words to their
      Urdo translation.
    * SSV.usx (xml) contains a literal Urdo translation.
    * SSV_Lit.usx (xml) contains a more readable Urdo translation.
    * ALEPH.usx (xml) contains notes on the Urdo translation organized by verse.

    A Lua script combines this data into a single XML file with SILE markup
    commands such that each page description contains a series of verses
    with these four parts:

    * Greek to Urdo interlinear
    * Literal Urdo translation
    * More readable Urdo translation
    * Notes on the translation

    Page breaks are added to keep related verses and notes on the same page.
    See the file "books/mockup.pdf" for an example.

File organization:

    Each book of the Bible is stored in a separate folder in the books
    subfolder:  ex. books/JHN

    Each book of the Bible is defined by the four files described above.

To execute the software:

    ./render JHN --maxChapter 2 --verse 14

    This will output the first 14 verses of the first two chapters of JHN and combine them into a single PDF.

    Creating the rendered chapters of the bible is a two step process:

    To create the SILE XML document, from the render folder

    cd preprocessing
    lua create-interlinear.lua book_folder_name

    To render the final PDF,

    sile input_folder output_file_name

    For example:
    sile ../books/book_folder_name interlinear.xml
