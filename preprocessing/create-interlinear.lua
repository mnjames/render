local book = arg[1]

if not book then
  print "The 'book' argument is required"
  os.exit()
end

local base = require "base"
local lom = require "lomwithpos"
local lexiconMap = require "resources.lexicon-map"

local dir = "../books/"..book

function getChapterAndVerse (str)
  local fn = string.gmatch(string.sub(str, string.find(str, ' ') + 1, -1), '%d+')
  return tonumber(fn()), tonumber(fn())
end

--------------------------------------------------------------------
-- Debugging function to print a table (recursively)
function printTable(name, t, level)
  level = level or 0
  if type(t) == "table" then
    local tabs = ""
    for j=1,level do
      tabs = tabs .. '\t'
    end

    for key, value in pairs(t) do
      print( string.format("%s %s [%s] = %s", tabs, name, key, value) )
      if type(value) == "table" then
        printTable(key, value, level+1)
      end
    end
  end
end

--------------------------------------------------------------------
-- Given a cluster, which is information about a single greek "word",
-- lookup and record its vernacular translation.
function buildLink (cluster, map)
  local greekWord = ""
  local vernacularWord
  local id
  local index = 0
  -- local length = 0

  -- printTable("cluster", cluster, 0)

  for i, data in ipairs(cluster) do

    if data.tag == "Range" then
      index = data.attr.Index
      -- length = data.attr.Length
      -- print( string.format("Found Range - index = %d  length = %d", index, length) )

    elseif data.tag == "Lexeme" then
      id = data.attr.Id
      if string.find(id, 'Word:') ~= nil then
        -- Make sure there is only one "word" in a cluster
        if string.len(greekWord) > 0 then print("Warning ... Found more than one word in a cluster") end

        -- Get the greek word
        greekWord = string.sub(id, string.find(id, ':') + 1, -1)

        -- Get the word translation
        vernacularWord = map[data.attr.GlossId] or "~"

        -- print( string.format("Found Word: greekWord = '%s' vernacularWord = '%s'", greekWord, vernacularWord) )
      end
    end
  end -- for loop

  if index == 0 then print("Warning: index was not found for cluster.") end

  if vernacularWord == nil then return nil
  else
    local wordData = {
      index = index,
      attr = {
        "greek",
        "vernacular",
        greek = greekWord,
        vernacular = string.gsub(vernacularWord, "-", " ")
      },
      tag = "item"
    }
    return wordData
  end
end

--------------------------------------------------------------------
-- Given (input) a "Raw_interlinear.xml" translation, output a word
-- for word transliteration.
function buildInterlinear (inter, map)
  local chapters = {
    attr = {},
    tag = "usx"
  }
  local verses = base.getChild(inter, "Verses")
  local verseData
  local chapter
  local verse
  local verseWords
  local verseTable
  local oneCluster

  -- Create an empty array to hold the words for one verse.
  -- Make the array big enough to allow the maximum character index into any verse
  local verseWords = {}    -- new array
  local MAX_CHARACTERS_IN_A_VERSE = 800
  local maxIndex = 0
  local lastIndex = 0

  for i, item in ipairs(verses) do
    if item.tag == "item" then
      chapter, verse = getChapterAndVerse(base.getChild(item, "string")[1])
      verseData = base.getChild(item, "VerseData")
      if not chapters[chapter] then
        chapters[chapter] = {
          attr = {
            "number",
            "type",
            number = chapter,
            type = "chapter"
          },
          tag = "section",
          totalVerses = 0
        }
      end
      verseTable = {
        attr = {
          "number",
          "type",
          number = verse,
          type = "verse"
        },
        tag = "section"
      }

      -- Initialize all the array indexes in the verseWords array to be "empty"
      for j=1, MAX_CHARACTERS_IN_A_VERSE do
        verseWords[j] = -1
      end

      lastIndex = 0
      for j, cluster in ipairs(verseData) do
        if cluster.tag == "Cluster" then
          oneCluster = buildLink(cluster, map)
          -- printTable("oneCluster", oneCluster, 2)

          if oneCluster ~= nil then
            verseWords[tonumber(oneCluster.index)] = oneCluster
            if tonumber(oneCluster.index) > lastIndex then
              lastIndex = tonumber(oneCluster.index)
            end
          end
        end
      end
      -- printTable("verseWords", verseWords, 0)

      -- Get the words from the verseWords array in linear order,
      -- skipping over empty indexes.
      for j=1, lastIndex do
        if verseWords[j] ~= -1 then
          -- print( string.format("Insert word %d", j) )
          table.insert(verseTable, verseWords[j]);

          -- After finding the maximum index for the entire Bible
          -- this can be removed.
          if j > maxIndex then maxIndex = j end
        end
      end

      -- printTable("verseTable", verseTable, 4)
      chapters[chapter][verse] = verseTable
      if chapters[chapter].totalVerses < verse then
        chapters[chapter].totalVerses = verse
      end
    end
  end

  if maxIndex > MAX_CHARACTERS_IN_A_VERSE then print("Warning, MAX_CHARACTERS_IN_A_VERSE is too small.") end

  -- Fill in any gaps that may exist
  for _, chapter in ipairs(chapters) do
    if #chapter < chapter.totalVerses then
      -- Found a gap
      for i=1, chapter.totalVerses do
        if not chapter[i] then chapter[i] = '' end
      end
    end
  end

  return chapters
end

local inter = buildInterlinear(lom.parse(base.readFile(dir.."/Raw_Interlinear.xml")), lexiconMap)
base.writeFile(dir.."/Interlinear.xml", base.deparse(inter))