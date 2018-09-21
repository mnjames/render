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
local outputDir = ".."

local buildOrder = {
  "interlinear",
  "ssv-lit",
  "ssv",
  "notes"
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

local counter = 0
function deparse (xml)
  if type(xml) ~= "table" then
    return xml
  end
  if xml.tag == "chapter" and tonumber(xml.attr.number) > 1 then return ""
  -- elseif xml.tag == "interlinear" or xml.tag == "ssv-lit" or xml.tag == "ssv" then
  --   counter = counter + 1
  --   if counter > 3*12 then
  --     return ""
  --   end
  -- elseif xml.tag == "note" then return "<note>This is an english note</note>"
  end
  if not xml.tag then
    for a, b in pairs(xml) do
      if type(b) == "table" then print(a, b.tag)
      else print(a, b)
      end
    end
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

function splitSection (obj)
  local split1 = {
    attr = obj.attr,
    tag = obj.tag
  }
  local split2 = {
    attr = {
      "number",
      "type",
      number = tonumber(obj.attr.number) + 0.5,
      type = obj.attr.type
    },
    tag = obj.tag
  }
  local breakPoint = #obj / 2
  for i, child in ipairs(obj) do
    if i < breakPoint then table.insert(split1, child)
    else table.insert(split2, child)
    end
  end
  return {
    split1,
    split2
  }
end

function createNested (parent, child, tag, index)
  local nested = {
    attr = {
      "number",
      "type",
      number = child.attr.number,
      type = tag
    },
    tag = "section"
  }
  if tag == "verse" then
    table.insert(nested, {
      attr = child.attr,
      tag = child.tag
    })
  end
  -- local nested = {
  --   attr = child.attr,
  --   tag = child.tag
  -- }
  for i = index, #parent do
    if parent[i].tag == tag or parent[i].tag == "chapter" then
      return i - 1, nested
    end
    table.insert(nested, parent[i])
  end
  return #parent, nested
  -- return #parent, splitSection(nested)
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
    -- table.insert(nested, child[1])
    -- table.insert(nested, child[2])
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

function getNextType (type, index, xml)
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
    if child.tag == "section" and child.attr.type == type then
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
  -- local combined = {
  --   attr = valid.attr,
  --   tag = valid.tag
  -- }
  local combined = {
    attr = {
      "number",
      number = valid.attr.number
    },
    tag = "chapter"
  }
  local children = {}
  for i = 1, #xmls do children[i] = {index = 1} end
  while true do
    for i, xml in ipairs(xmls) do
      children[i] = getNextType("verse", children[i].index, xml)
    end
    valid = normalize(children)
    if not valid then break end
    -- local verse = {
    --   attr = {
    --     "number",
    --     "type",
    --     number = valid.attr.number,
    --     type = "verse"
    --   },
    --   tag = "section"
    -- }
    for i, child in ipairs(children) do
      if child.value then
        child.index = child.index + 1
        child.value.tag = buildOrder[i]
        child.value.attr = {}
        if child.extra then
          for extraIndex, extraInsert in ipairs(child.extra) do
            table.insert(child.value, extraIndex, extraInsert)
          end
        end
        table.insert(combined, child.value)
        -- table.insert(verse, child.value)
      end
    end
    -- table.insert(combined, verse)
  end
  return combined
end

function combine (xmls)
  local ssv = xmls[3]
  local combined = {
    attr = {
      "class",
      "version",
      class = "sections",
      version = "2.5"
    },
    tag = "sile"
  }
  -- local combined = {
  --   attr = ssv.attr,
  --   tag = ssv.tag
  -- }
  local ssvChild
  local i = 1
  while true do
    ssvChild = ssv[i]
    if ssvChild.tag == "section" then break end
    table.insert(combined, ssvChild)
    i = i + 1
  end
  
  local children = {}
  for i = 1, #xmls do children[i] = {index = 1} end
  while true do
    for i, xml in ipairs(xmls) do
      children[i] = getNextType("chapter", children[i].index, xml)
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

function buildNotes (ssv)
  local xml = {
    attr = {},
    tag = "usx"
  }
  for i, chapter in ipairs(ssv) do
    if chapter.tag == "section" then
      local chapterSection = {
        attr = chapter.attr,
        tag = chapter.tag
      }
      for j, verse in ipairs(chapter) do
        if verse.tag == "section" then
          local verseSection = {
            attr = verse.attr,
            tag = verse.tag
          }
          for k, note in ipairs(verse) do
            if note.tag == "note" then
              verse[k] = {
                attr = {},
                tag = "notemark"
              }
              for _, content in ipairs(note) do
                table.insert(verseSection, content)
              end
            end
          end
          table.insert(chapterSection, verseSection)
        end
      end
      table.insert(xml, chapterSection)
    end
  end
  return xml
end

clock("Begin")
local ssvLit = lom.parse(base.readFile(inputDir.."/SSV_Lit.xml"))
local ssv = lom.parse(base.readFile(inputDir.."/SSV.xml"))
local inter = lom.parse(base.readFile(inputDir.."/Interlinear.xml"))
clock("Build XML")

ssvLit = flip(ssvLit)
ssv = flip(ssv)

-- local notes = buildNotes(ssv)

-- inter = buildInterlinear(inter, lexiconMap)
-- base.writeFile(inputDir.."/Interlinear.xml", deparse(inter))

-- outputDir = "../output/"..book
-- base.writeFile(outputDir.."/prepared-interlinear.xml", deparse(inter))
-- base.writeFile(outputDir.."/prepared-ssv_lit.xml", deparse(ssvLit))
-- base.writeFile(outputDir.."/prepared-ssv.xml", deparse(ssv))
-- base.writeFile(outputDir.."/prepared-notes.xml", deparse(notes))
-- base.writeFile(outputDir.."/prepared.xml", deparse(combine({
--   inter,
--   ssvLit,
--   ssv,
--   notes
-- })))

base.writeFile(outputDir.."/prepared.xml", deparse(combine({
  inter,
  ssvLit,
  ssv,
  -- notes
})))