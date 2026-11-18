-- Project lists and one global list share a single data file, keyed by list name,
-- because settings.key() picks both the file and the index and takes no arguments.
local function root()
  return vim.fs.root(0, ".git") or vim.uv.cwd()
end

return {
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("harpoon"):setup({
        settings = {
          save_on_toggle = true,
          key = function()
            return "harpoon"
          end,
        },
        -- Relative to git root so :cd into a subdir doesn't drift the stored paths.
        default = { get_root_dir = root },
        -- make_relative leaves a path untouched when root isn't a prefix, which is
        -- how the global list ends up absolute.
        global = {
          get_root_dir = function()
            return "/__harpoon_global__"
          end,
        },
      })
    end,
    keys = function()
      local harpoon = require("harpoon")
      local function project()
        return harpoon:list(root())
      end
      local function global()
        return harpoon:list("global")
      end

      local keys = {
        { "<leader>hh", function() harpoon.ui:toggle_quick_menu(project()) end, desc = "Menu (project)" },
        { "<leader>ha", function() project():add() end, desc = "Add file" },
        { "<leader>hd", function() project():remove() end, desc = "Remove file" },
        { "<leader>hn", function() project():next() end, desc = "Next file" },
        { "<leader>hp", function() project():prev() end, desc = "Prev file" },
        { "<leader>hg", function() harpoon.ui:toggle_quick_menu(global()) end, desc = "Menu (global)" },
        { "<leader>hG", function() global():add() end, desc = "Add file (global)" },
      }
      for i = 1, 4 do
        table.insert(keys, {
          "<leader>h" .. i,
          function() project():select(i) end,
          desc = "Go to file " .. i,
        })
      end
      return keys
    end,
  },

  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>h", group = "harpoon", icon = "󰛢 " },
      },
    },
  },
}
