---@diagnostic disable: lowercase-global, undefined-global
ignore = {
  "631", -- max_line_length
}
exclude_files = {
  ".tests",
}
globals = { "vim", "P" }
read_globals = {
  "describe",
  "it",
  "after_each",
  "assert",
}
