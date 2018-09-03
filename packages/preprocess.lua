local book = arg[1]

if not book then
  print "The 'book' argument is required"
  os.exit()
end

local time = os.time()
function clock (msg)
  local newTime = os.time()
  print(msg, (newTime - time).." seconds")
  time = newTime
end

local base = require "base"
local lom = require "lomwithpos"
local lexiconMap = require "resources.lexicon-map"

local inputDir = "../books/"..book
local outputDir = "../output/"..book

local buildOrder = {
  "interlinear",
  "ssv-lit",
  "ssv"
}

function getAttr (attr)
  local str = ""
  if #attr == 0 then
    return str
  end
  for i, at in ipairs(attr) do
    str = str.." "..at.."=\""..attr[at].."\""
  end
  return str
end

function deparse (xml)
  if type(xml) ~= "table" then
    return xml
  end
  local str = "<"..xml.tag..getAttr(xml.attr)
  if (#xml == 0) then
    return str.." />"
  end
  str = str..">"
  for i, child in ipairs(xml) do
    str = str..deparse(child)
  end
  str = str.."</"..xml.tag..">"
  return str
end

function createNested (parent, child, tag, index)
  local nested = {
    attr = child.attr,
    tag = child.tag
  }
  for i = index, #parent do
    if parent[i].tag == tag or parent[i].tag == "chapter" then
      return i - 1, nested
    end
    table.insert(nested, parent[i])
  end
  return #parent, nested
end

function nest (xml, tag)
  tag = tag or "verse"
  local nested = {
    attr = xml.attr,
    tag = xml.tag
  }
  local child
  local i = 0
  local length = #xml
  while i < length do
  -- for i = 1, 20 do
    i = i + 1
    -- print(i)
    child = xml[i]
    if child.tag == tag then
      i, child = createNested(xml, child, tag, i + 1)
    end
    table.insert(nested, child)
  end
  return nested
end

function flatten (xml)
  local flattened = {
    attr = xml.attr,
    tag = xml.tag
  }
  for i, child in ipairs(xml) do
    if child.tag == "para" then
      -- table.insert(flattened, {
      --   attr = child.attr,
      --   tag = "begin-"..child.tag
      -- })
      table.insert(flattened, {
        attr = child.attr,
        tag = child.tag.."-start"
      })
      for j, paraChild in ipairs(child) do
        table.insert(flattened, paraChild)
      end
      table.insert(flattened, {
        attr = {},
        tag = child.tag.."-end"
      })
    else
      table.insert(flattened, child)
    end
  end
  return flattened
end

function flip (xml) return nest(nest(flatten(xml)), "chapter") end

function getNext (tag, index, xml)
  if not xml then
    return {
      index = index,
      value = nil
    }
  end
  local extra = {}
  local child
  for i = index, #xml do
    child = xml[i]
    if child.tag == tag then
      if #extra == 0 then extra = nil end
      return {
        extra = extra,
        index = i,
        value = child
      }
    else
      table.insert(extra, child)
    end
  end
  return {
    index = index,
    value = nil
  }
end

function normalize (children)
  local keepGoing = false
  local numbers = {}
  for i, child in ipairs(children) do
    if child.value then
      keepGoing = true
      table.insert(numbers, tonumber(child.value.attr.number))
    end
  end
  if not keepGoing then return false end
  local min = math.min(table.unpack(numbers))
  local validChild
  for i, child in ipairs(children) do
    if child.value then
      if tonumber(child.value.attr.number) > min then
        child.value = nil
        child.index = child.index - 1
      else
        validChild = child.value
      end
    end
  end
  return validChild
end

function getFirst (array)
  for i, value in ipairs(array) do
    if value then return value end
  end
  return nil
end

function combineChapter (xmls)
  local valid = getFirst(xmls)
  local combined = {
    attr = valid.attr,
    tag = valid.tag
  }
  local children = {}
  for i = 1, #xmls do children[i] = {index = 1} end
  while true do
    for i, xml in ipairs(xmls) do
      children[i] = getNext("verse", children[i].index, xml)
    end
    valid = normalize(children)
    if not valid then break end
    local verse = {
      attr = {
        "number",
        number = valid.attr.number
      },
      tag = "verse"
    }
    for i, child in ipairs(children) do
      if child.value then
        child.index = child.index + 1
        child.value.tag = buildOrder[i]
        if child.extra then
          for extraIndex, extraInsert in ipairs(child.extra) do
            table.insert(child.value, extraIndex, extraInsert)
          end
        end
        table.insert(verse, child.value)
      end
    end
    table.insert(combined, verse)
  end
  return combined
end

function combine (xmls)
  local ssv = xmls[3]
  local combined = {
    attr = ssv.attr,
    tag = ssv.tag
  }
  local ssvChild
  local i = 1
  while true do
    ssvChild = ssv[i]
    if ssvChild.tag == "chapter" then break end
    table.insert(combined, ssvChild)
    i = i + 1
  end
  
  local children = {}
  for i = 1, #xmls do children[i] = {index = 1} end
  while true do
    for i, xml in ipairs(xmls) do
      children[i] = getNext("chapter", children[i].index, xml)
    end
    if not normalize(children) then break end
    local sections = {}
    for i, child in ipairs(children) do
      -- if child.extra then
      --   -- print("Extra", child.extra[1].tag)
      --   -- print("Value", child.value.tag)
      --   for extraIndex, extraInsert in ipairs(child.extra) do
      --     table.insert(child.value, extraIndex, extraValue)
      --   end
      -- end
      table.insert(sections, child.value)
    end
    table.insert(combined, combineChapter(sections))
    for i, child in ipairs(children) do
      child.index = child.index + 1
    end
  end
  return combined
end

-- function getVerses (xml, stack, paths)
--   -- if !stack then stack = {} end
--   if type(stack) ~= "string" then
--     stack = xml.tag
--   else
--     stack = stack.."."..xml.tag
--   end
--   if type(paths) ~= "table" then paths = {} end
--   if xml.tag == "verse" then
--     paths[stack] = true
--   end
--   for i, child in ipairs(xml) do
--     if type(child) == "table" then
--       getVerses(child, stack, paths)
--     end
--   end
--   return paths
-- end

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
      vernacular = vernacular
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
            number = chapter
          },
          tag = "chapter"
        }
      end
      verseTable = {
        attr = {
          "number",
          number = verse
        },
        tag = "verse"
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
  -- return map["aa85WCbr"]
end

clock("Begin")
local ssvLit = lom.parse(base.readFile(inputDir.."/SSV_Lit.xml"))
local ssv = lom.parse(base.readFile(inputDir.."/SSV.xml"))
local inter = lom.parse(base.readFile(inputDir.."/Interlinear.xml"))
clock("Build XML")

ssv = flip(ssv)
ssvLit = flip(ssvLit)
-- inter = buildInterlinear(inter, lexiconMap)

base.writeFile(outputDir.."/prepared-interlinear.xml", deparse(inter))
base.writeFile(outputDir.."/prepared-ssv_lit.xml", deparse(ssvLit))
base.writeFile(outputDir.."/prepared-ssv.xml", deparse(ssv))
base.writeFile(outputDir.."/prepared.xml", deparse(combine({
  inter,
  ssvLit,
  ssv
})))