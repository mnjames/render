local base = {}

package.path = package.path..";../?.lua"

base.readFile = function (file)
  local ret = ""
  for line in io.lines(file) do 
    ret = ret .. line
  end
  return ret
end

base.writeFile = function (file, data)
  file = io.open(file, "w")
  file:write(data)
  file:close()
end

base.getChild = function (xml, tag)
  for i, child in ipairs(xml) do
    if child.tag == tag then return child end
  end
  return nil
end

return base