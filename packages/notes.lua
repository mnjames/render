local insertions = SILE.require("packages/insertions")

SILE.registerCommand("note", function(options, content)
  SILE.typesetter:typeset('*')
  -- SILE.settings.set("typesetter.parseppattern", -1)
  -- local opts = SILE.scratch.insertions.classes.notes
  -- local f = SILE.getFrame(opts["insertInto"].frame)
  -- local oldT = SILE.typesetter
  -- SILE.typesetter = SILE.typesetter {}
  -- SILE.typesetter:init(f)
  -- SILE.typesetter.pageTarget = function () return 0xFFFFFF end
  -- SILE.settings.pushState()
  -- SILE.settings.reset()
  -- local material = SILE.Commands["vbox"]({}, function()
  --   SILE.process(content)
  --   -- SILE.Commands["footnote:font"]({}, function()
  --   --   SILE.call("footnote:atstart", options)
  --   --   SILE.call("footnote:counter", options)
  --   --   SILE.process(content)
  --   -- end)
  -- end)
  -- SILE.settings.popState()
  -- SILE.typesetter = oldT
  -- insertions.exports:insert("notes", material)
end)

-- SILE.registerCommand("notemark", function ()
--   SILE.typesetter:typeset("*")
-- end)

return {
  init = function (class, args)
    insertions.exports:initInsertionClass("notes", {
    insertInto = args.insertInto,
    stealFrom = args.stealFrom,
    maxHeight = SILE.length.new({length = SILE.toPoints("75", "%ph") }),
    topBox = SILE.nodefactory.newVglue({height = SILE.length.parse("2ex") }),
    interInsertionSkip = SILE.length.parse("1ex"),
  })
  end,
  exports = {
    outputInsertions = insertions.exports.outputInsertions
  }
}