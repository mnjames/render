local book = arg[1]

if not book then
  print "The 'book' argument is required"
  os.exit()
end

--- -------------------------------------------------------------------
-- This is called by dump() to handle the recursive nature of tables.
-- @param o the object
-- @param level the level of recursive nesting
-- @param max_level the max number of nested sub-tables to display
-- @return string that described the object
function dump_recursive(o, level, max_level)
  local indent = string.rep("   ", (max_level - level + 1))

  -- values are of type: nil, number, string, function, CFunction, userdata, and table
  if type(o) == 'string' then
    return '"' .. o .. '"'
  elseif type(o) == 'table' and level >= 0 then
    local s = '\n' .. indent .. '{\n'
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. indent .. '['..k..'] = ' .. dump_recursive(v, level-1, max_level) .. ',\n'
    end
    return s .. indent .. '}'
  else
    return tostring(o)
  end
end

--- -------------------------------------------------------------------
-- Given an object, including a table, build a string that described the
-- object. If a table has sub-tables, the max_level will stop recursion.
-- @param o the object
-- @param max_level the max number of nested sub-tables to display
-- @return string that described the object
function dump(o, max_level)
  return dump_recursive(o, max_level, max_level)
end

--- -------------------------------------------------------------------
-- Pause execution for console input. Used for debugging.
function pause()
  io.stdin:read'*l'
end

--- -------------------------------------------------------------------
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

-- print("cmd line args = ", dump(args, 2))

--- -------------------------------------------------------------------
-- Local, module wide, parameters
local chapters = {}
local firstPage = tonumber(args.firstPage) or 1
local startSide = firstPage % 2 == 0 and "left" or "right"
if args.verse then args.verse = tonumber(args.verse) end
if args.chapter then args.chapter = tonumber(args.chapter) end
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

-- print("managed cmd line args = ", dump(args, 2))

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

--- -------------------------------------------------------------------
-- Given a ???, insert it into the hierarchy
-- @param parent
-- @param child
-- @param tag
-- @param index
-- @return the length of the parent table
-- @return a new node that ???
function createNested (parent, child, tag, index)
  local nodesToAdd = {}
  local sectionNumber
  if string.match(child.attr.number, "-") then
    local gen = string.gmatch(child.attr.number, "%d+")
    sectionNumber = gen()
    local lastVerse = tonumber(gen())
    local extraVerses = lastVerse - tonumber(sectionNumber)
    for i=tonumber(sectionNumber) + 1,lastVerse do
      table.insert(nodesToAdd, {
        attr = {
          "number",
          "type",
          number = tostring(i),
          type = tag
        },
        tag = "section"
      })
    end
  else
    sectionNumber = child.attr.number
  end
  -- Generic nested node
  local nested = {
    attr = {
      "number",
      "type",
      number = sectionNumber,
      type = tag
    },
    tag = "section"
  }
  table.insert(nodesToAdd, 1, nested)
  local blanksToAdd
  if tag == "verse" then
    table.insert(nested, { attr = child.attr,  tag = child.tag } )
  end

  for i = index, #parent do
    if parent[i].tag == tag or parent[i].tag == "chapter" then
      return i - 1, nodesToAdd
    end
    table.insert(nested, parent[i])  -- append to nested
  end

  -- Return the length of the parent and the nested node
  return #parent, nodesToAdd
end

--- -------------------------------------------------------------------
-- Given a table representation of an xml document,
-- @param xml
-- @param tag
-- @return ???
function nest (xml, tag)
  -- tag = tag or "verse"  -- not needed because the call always specifies the tag!
  local nested = {
    attr = xml.attr,
    tag = xml.tag
  }

  local child
  local children
  local i = 0
  local length = #xml
  while i < length do
    i = i + 1
    child = xml[i]
    if child.tag == tag then
      i, children = createNested(xml, child, tag, i + 1)
      for _, node in ipairs(children) do
        table.insert(nested, node)
      end
    else
      table.insert(nested, child)
    end
    -- table.insert(nested, child[1])
    -- table.insert(nested, child[2])
  end

  return nested
end

--- -------------------------------------------------------------------
-- Given a table representation of an xml document, any sub-nodes of
-- a paragraph are raised one level in the hierarchy and the start and
-- end of a paragraph are delimiated with new nodes.
-- @param xml a table representing xml nodes
-- @return a new table whose hierarcy level is one less and paragraph
--         delimiters have been added.
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
      if child.attr.style ~= "h" and
         child.attr.style ~= "toc1" and
         child.attr.style ~= "toc2" then
        if child.attr.style ~= "p" then
          table.insert(flattened, child)
        else
          table.insert(flattened, {
            attr = child.attr,
            tag = child.tag .. "-start"
          })
          for j, paraChild in ipairs(child) do
            table.insert(flattened, paraChild)
          end
          table.insert(flattened, {
            attr = {},
            tag = child.tag .. "-end"
          })
        end
      end
    else
      table.insert(flattened, child)
    end
  end
  return flattened
end

--- -------------------------------------------------------------------
-- Given a table representation of an xml document, "flatten the hierarchy"
-- and then organize the hierarchy by verse and then by chapter.
-- based on bible chapters.
-- @param xml a table (really an array of tables)
-- @return a new table organized by verse and then by chapter
function flip (xml)
  return nest( nest(flatten(xml), "verse"), "chapter")
end

--- -------------------------------------------------------------------
-- Given an xml node that is
-- @param tag
-- @param index
-- @param xml
-- @return ???
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

--- -------------------------------------------------------------------
-- Given a xml node attribute type (type) and a starting index into the xml data,
-- search for the next node that matches the specified type.
-- @param type the type of node to search for (either "verse" or "chapter")
-- @param index where to start the search in the xml array
-- @param xml the array to search
-- @return an object that contains the location of the found node (index),
--         the node itself (value), and all the nodes that were skipped
--         over during the search (extra)
function getNextType (type, index, xml)
  local not_found = {
    index = index,
    value = nil
  }

  if not xml then
    return not_found
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

  return not_found
end

--- -------------------------------------------------------------------
-- Given an array of nodes,
-- @param children an array of xml nodes
-- @return false if no values can be found in the array, or the value
--         associated with the minumum attr.number
function normalize (children)

  -- Create an array of verse numbers
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
      if extractNumber(child.value.attr.number) > min then
        child.value = nil
        child.index = child.index - 1
      else
        validChild = child.value
      end
    end
  end

  return validChild
end

--- -------------------------------------------------------------------
-- Given a string, extract an integer number
-- @param str the string
-- @return number
function extractNumber (str)
  return tonumber(string.gmatch(str, '%d+')())
end

--- -------------------------------------------------------------------
-- Given an array, return the first element at an indexed position.
-- @param array the array to search
-- @return value at the first defined index, or nil if the array contains no values.
function getFirst (array)
  for i, value in ipairs(array) do
    if value then return value end
  end
  return nil
end

--- -------------------------------------------------------------------
-- Given an object, determine how many values are in the object (never called)
-- @param item the object to examine
-- @return the number of values in the object.
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

--- -------------------------------------------------------------------
-- Add "tag" and "attr" keys to a table object.
-- @param array the existing table.
-- @param tag a string that labels the table
-- @return the table object that was modified.
function createTag (array, tag)
  array.tag = tag
  array.attr = {}
  return array
end

--- -------------------------------------------------------------------
-- Given a string and a table, break the string into individual words
-- and insert each word as a separate sub-table.
-- @param str the input string
-- @param obj the table to add the words to.
-- @return (nothing), but the input obj has been modified.
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

--- -------------------------------------------------------------------
-- ??? (Not called if resolution is not defined.)
-- @param section the input string
-- @param tag the table to add the words to.
-- @return split,
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

-- Check to see if an object is something the verse number should be input BEFORE (e.g. whitespace, a para-end tag)
function verseShouldPrecede (item)
  if not item then return false end
  if (type(item) == "string") then
    return item:match("%S") == nil
  else
    return item.tag and item.tag:match("para")
  end
end

--- -------------------------------------------------------------------
-- Organize the interlinear, ssvLit, and ssv (including notes) onto pages.
-- Processes one verse at a time.
-- @param xmls the 3 xml tables - { inter, ssvLit, ssv }
-- @return chapter - one table that contains the nodes defining multiple pages.
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
  for i = 1, #xmls do
    children[i] = {index = 1}
  end

  while true do
    local verse = {
      attr = {},
      tag = 'verse-section'
    }
    for i, xml in ipairs(xmls) do
      children[i] = getNextType("verse", children[i].index, xml)
      -- print("children[" .. tostring(i) .. "] = ", dump(children[i], 5))
    end

    valid = normalize(children)
    if not valid then break end
    if args.verse and extractNumber(valid.attr.number) > args.verse then
      break
    end

    local split = {}
    local verse_number;
    for i, child in ipairs(children) do
      if child.value then
        -- print("i = ", i, "    child = ", dump(child, 5))

        if child.value[1] and child.value[1].attr.style == 'v' then -- this is a verse number
          -- Move the verse number to the end of the child.value array

          -- remove the verse number from the first element of the array
          verse_number = table.remove(child.value, 1)

          -- if the last element is a paragraph break ("para-end"), then insert the verse before it; otherwise, append it to the end
          local insertIndex = #child.value + 1
          while verseShouldPrecede(child.value[insertIndex - 1]) do
            insertIndex = insertIndex - 1
          end
          table.insert(child.value, insertIndex, verse_number)
          -- print("found verse number\n", dump(child.value, 5))
        end

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

--- -------------------------------------------------------------------
-- Organize the interlinear, ssvLit, and ssv (including notes) onto pages.
-- Processes one chapter at a time.
-- @param xmls the 3 xml tables - { inter, ssvLit, ssv }
-- @return combined - one table that contains the nodes defining multiple pages.
function combine (xmls)
  local ssv = xmls[3]
  local combined = {
    attr = {
      "version",
      version = "1.0"
    },
    tag = "sections"
  }
  if not args.chapter or args.chapter == 1 then
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
  for i = 1, #xmls do
    children[i] = {index = 1}
  end

  -- Processing one chapter at a time
  while true do
    for i, xml in ipairs(xmls) do
      children[i] = getNextType("chapter", children[i].index, xml)
    end

    if not normalize(children) then break end

    local sections = {}
    for i, child in ipairs(children) do
      table.insert(sections, child.value)
    end

    table.insert(combined, combineChapter(sections) or "")

    for i, child in ipairs(children) do
      child.index = child.index + 1
    end
  end

  return combined
end

--- -------------------------------------------------------------------
-- Main program

-- Get the xml data and parse it into lua tables
local inter  = lom.parse(base.readFile(inputDir .. "/Interlinear.xml"))
local ssvLit = lom.parse(base.readFile(inputDir .. "/SSV_Lit.usx"))
local ssv    = lom.parse(base.readFile(inputDir .. "/SSV.usx"))

-- lua table structure:
-- inter: inter[j]       is chapter j
--        inter[j][k]    is verse k of chapter j
--        inter[j][k][m] is word m of verse k of chapter j
--        inter[j][k][m].tag == 'item'
--        inter[j][k][m].attr.greek is one greek word
--        inter[j][k][m].attr.vernacular is one Urdo word
--
-- ssvlit: ssvLit[x] is node x from the original xml
--         ssvlit[x][y] is verse information in verse order, metadata followed by text
--         (not nested by chapter and verse; linear order)
--
-- ssv: contains verses in numerical order; verses have notes interspersed inside them

-- print("inter = " .. dump(inter, 5));
-- print("ssvlit = ", dump(ssvLit, 5));
-- print("ssv = ", dump(ssv, 5));
-- pause()

-- Organize the data by verse and then by chapter
ssvLit = flip(ssvLit)
ssv = flip(ssv)

if #chapters > 0 then
  for _, chapter in ipairs(chapters) do
    args.chapter = chapter

    local together = combine({ inter, ssvLit, ssv })
    local xml = base.deparse(together)

    base.writeFile(outputDir .. "/" .. string.format("%03d", chapter) .. ".xml", xml)
    base.reset()
  end
else
  local together = combine({ inter, ssvLit, ssv })
  local xml = base.deparse(together)

  base.writeFile(outputDir .. "/" .. book .. ".xml", xml)
end
base.writeFile(outputDir .. "/" .. "context.lua", "return {side=\""..startSide.."\",page="..firstPage.."}")