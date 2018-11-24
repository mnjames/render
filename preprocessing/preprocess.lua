local book = arg[1]

if not book then
  print "The 'book' argument is required"
  os.exit()
end

-- Create a string that contains the contents of a table
function dump(o, level)
  if (level <= 0) then
    return tostring(o)
  end
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. '['..k..'] = ' .. dump(v, level-1) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

-- Get the command line arguments
local args = {}
local var
for _, a in ipairs(arg) do
  if string.sub(a, 1, 2) == "--" then
    if var then args[var] = true end
    var = string.sub(a, 3)
  else
    if var then args[var] = a end
    var = nil
  end
end

print("cmd line args = ", dump(args, 2))

local chapters = {}
if args.verse then args.verse = tonumber(args.verse) end
if args.chapter then chapters[1] = tonumber(args.chapter) end
if args.maxChapter or args.minChapter then
  local min = args.minChapter and tonumber(args.minChapter) or 1
  local max = tonumber(args.maxChapter)
  for i=min, max do
    table.insert(chapters, i)
  end
end
local resolution
if args.resolution then
  resolution = tonumber(args.resolution)
end

print("managed cmd line args = ", dump(args, 2))

local base = require "base"
local lom = require "lomwithpos"

local inputDir = "../books/"..book
local outputDir = ".."

local buildOrder = {
  "interlinear",
  "ssv-lit",
  "ssv",
  "notes"
}

-- function splitSection (obj)
--   local split1 = {
--     attr = obj.attr,
--     tag = obj.tag
--   }
--   local split2 = {
--     attr = {
--       "number",
--       "type",
--       number = tonumber(obj.attr.number) + 0.5,
--       type = obj.attr.type
--     },
--     tag = obj.tag
--   }
--   local breakPoint = #obj / 2
--   for i, child in ipairs(obj) do
--     if i < breakPoint then table.insert(split1, child)
--     else table.insert(split2, child)
--     end
--   end
--   return {
--     split1,
--     split2
--   }
-- end

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
    table.insert(nested, parent[i])  -- look here
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
      if child.attr.style ~= "h" and child.attr.style ~= "toc1" and child.attr.style ~= "toc2" then
        if child.attr.style ~= "p" then
          table.insert(flattened, child)
        else
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
        end
      end
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
  --print("normalize called", dump(children, 2))
  local keepGoing = false
  local numbers = {}
  for i, child in ipairs(children) do
    if child.value then
      keepGoing = true
      table.insert(numbers, tonumber(child.value.attr.number))
    end
  end
  --print("numbers = ", dump(numbers, 2))

  if not keepGoing then return false end
  local min = math.min(table.unpack(numbers))
  local validChild
  for i, child in ipairs(children) do
    if child.value then
      if extractNumber(child.value.attr.number) > min then
        child.value = nil
        child.index = child.index - 1
      else
        validChild = child.value
      end
    end
  end
  --print("validChild = ", dump(validChild, 2))
  return validChild
end

function extractNumber (str)
  return tonumber(string.gmatch(str, '%d+')())
end

function getFirst (array)
  for i, value in ipairs(array) do
    if value then return value end
  end
  return nil
end

function getLength (item)
  if type(item) == 'string' then
    return #item
  else
    local length = 0
    for _, child in ipairs(item) do
      length = length + getLength(child)
    end
    return length
  end
end

function createTag (array, tag)
  array.tag = tag
  array.attr = {}
  return array
end

function chunkUpString (str, obj)
  local fn = string.gmatch(str, '[^%s]+')
  local word = fn()
  while word do
    table.insert(obj, {
      word = word
    })
    word = fn()
  end
end

-- Not called if resolution is not defined
function splitSection (section, tag)
  local all = {}
  for _, item in ipairs(section) do
    if type(item) == 'string' then
      chunkUpString(item, all)
    else
      table.insert(all, item)
    end
  end
  local length = #all / resolution
  local split = {}
  local sec = {}
  local tot = 0
  for _, item in ipairs(all) do
    tot = tot + 1
    if item.word then
      item = item.word.." "
      if type(sec[#sec]) == 'string' then
        sec[#sec] = sec[#sec]..item
      else
        table.insert(sec, item)
      end
    else
      table.insert(sec, item)
    end
    if tot > length then
      tot = 0
      table.insert(split, createTag(sec, tag))
      sec = {}
    end
  end
  if #sec > 0 then
    table.insert(split, createTag(sec, tag))
  end
  return split
end

function combineChapter (xmls)
  local valid = getFirst(xmls)
  if args.chapter and tonumber(valid.attr.number) ~= args.chapter then
    return
  end
  local chapter = {
    attr = {
      "number",
      number = valid.attr.number
    },
    tag = "chapter"
  }
  local children = {}
  for i = 1, #xmls do children[i] = {index = 1} end
  while true do
    local verse = {
      attr = {},
      tag = 'verse-section'
    }
    for i, xml in ipairs(xmls) do
      children[i] = getNextType("verse", children[i].index, xml)
      print("children[",i, "] = ", dump(children[i], 2));
    end
    valid = normalize(children)
    if not valid then break end
    if args.verse and tonumber(valid.attr.number) > args.verse then
      break
    end
    local split = {}
    for i, child in ipairs(children) do
      if child.value then
        child.index = child.index + 1
        if child.extra then
          for extraIndex, extraInsert in ipairs(child.extra) do
            table.insert(child.value, extraIndex, extraInsert)
          end
        end
        if resolution then
          table.insert(split, splitSection(child.value, buildOrder[i]))
        else
          child.value.tag = buildOrder[i]
          child.value.attr = {}
          table.insert(verse, child.value)
        end
      end
    end
    if resolution then
      for i=1, resolution do
        for _, section in ipairs(split) do
          table.insert(verse, section[i] or "")
        end
      end
    end
    table.insert(chapter, verse)
  end
  return chapter
end

-- Combine the interlinear, ssv, ssvLit, and notes onto pages
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
  if args.chapter == 1 then
    local ssvChild
    local i = 1
    while true do
      ssvChild = ssv[i]
      if ssvChild.tag == "section" then break end
      table.insert(combined, ssvChild)
      i = i + 1
    end
  end

  -- print("xmls ", dump_to_level(xmls, 3))

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
    table.insert(combined, combineChapter(sections) or "")
    for i, child in ipairs(children) do
      child.index = child.index + 1
    end
  end
  return combined
end

local ssvLit = lom.parse(base.readFile(inputDir.."/SSV_Lit.usx"))
local ssv = lom.parse(base.readFile(inputDir.."/SSV.usx"))
local inter = lom.parse(base.readFile(inputDir.."/Interlinear.xml"))

-- print("ssvlit = ", dump(ssvLit, 5));
-- print("ssv = ", dump(ssv, 5));
-- print("inter = " .. dump(inter, 5));

ssvLit = flip(ssvLit)
ssv = flip(ssv)

for _, chapter in ipairs(chapters) do
  print("chapter = ", dump(chapter,3))
  args.chapter = chapter
  base.writeFile(outputDir.."/"..chapter..".xml", base.deparse(combine({
    inter,
    ssvLit,
    ssv
  })))
  base.reset()
end