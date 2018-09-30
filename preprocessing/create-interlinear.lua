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

function buildLink (cluster, map)
  local greek = ""
  local vernacular= ""
  local id
  for i, lexeme in ipairs(cluster) do
    if lexeme.tag == "Lexeme" then
      id = lexeme.attr.Id
      greek = greek..string.sub(id, string.find(id, ':') + 1, -1)
      if string.len(vernacular) > 0 then vernacular = vernacular.." " end
      vernacular = vernacular..(map[lexeme.attr.GlossId] or "~")
    end
  end
  return {
    attr = {
      "greek",
      "vernacular",
      greek = greek,
      vernacular = string.gsub(vernacular, "-", " ")
    },
    tag = "item"
  }
end

function buildInterlinear (inter, map)
  local chapters = {
    attr = {},
    tag = "usx"
  }
  local verses = base.getChild(inter, "Verses")
  local verseData
  local chapter
  local verse
  local verseTable
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
          tag = "section"
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
      for j, cluster in ipairs(verseData) do
        if cluster.tag == "Cluster" then
          table.insert(verseTable, buildLink(cluster, map))
        end
      end
      chapters[chapter][verse] = verseTable
    end
  end
  return chapters
end

local inter = buildInterlinear(lom.parse(base.readFile(dir.."/Raw_Interlinear.xml")), lexiconMap)
base.writeFile(dir.."/Interlinear.xml", base.deparse(inter))