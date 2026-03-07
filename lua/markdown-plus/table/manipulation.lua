---@module 'markdown-plus.table.manipulation'
---@brief [[
--- Table manipulation for markdown tables (re-export facade)
---
--- This module re-exports all table manipulation functions from focused sub-modules:
--- - row_ops: insert_row, delete_row, duplicate_row, move_row_up, move_row_down
--- - column_ops: insert_column, delete_column, duplicate_column, move_column_left, move_column_right
--- - cell_ops: clear_cell, toggle_cell_alignment
---@brief ]]

local row_ops = require("markdown-plus.table.row_ops")
local column_ops = require("markdown-plus.table.column_ops")
local cell_ops = require("markdown-plus.table.cell_ops")

local M = {}

-- Row operations
M.insert_row = row_ops.insert_row
M.delete_row = row_ops.delete_row
M.duplicate_row = row_ops.duplicate_row
M.move_row_up = row_ops.move_row_up
M.move_row_down = row_ops.move_row_down

-- Column operations
M.insert_column = column_ops.insert_column
M.delete_column = column_ops.delete_column
M.duplicate_column = column_ops.duplicate_column
M.move_column_left = column_ops.move_column_left
M.move_column_right = column_ops.move_column_right

-- Cell operations
M.clear_cell = cell_ops.clear_cell
M.toggle_cell_alignment = cell_ops.toggle_cell_alignment

return M
