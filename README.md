


<div align="center">

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/yousefhadder/markdown-plus.nvim?style=flat-square&logo=github&color=blue)](https://github.com/yousefhadder/markdown-plus.nvim/releases)
[![LuaRocks](https://img.shields.io/luarocks/v/yousefhadder/markdown-plus.nvim?style=flat-square&logo=lua&color=purple)](https://luarocks.org/modules/yousefhadder/markdown-plus.nvim)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)

[![Tests](https://img.shields.io/github/actions/workflow/status/yousefhadder/markdown-plus.nvim/ci.yml?branch=main&style=flat-square&logo=github&label=Tests)](https://github.com/yousefhadder/markdown-plus.nvim/actions/workflows/tests.yml)
[![Neovim](https://img.shields.io/badge/Neovim%200.11+-green.svg?style=flat-square&logo=neovim&label=Neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua%205.1+-blue.svg?style=flat-square&logo=lua&label=Lua)](https://www.lua.org/)

[![GitHub stars](https://img.shields.io/github/stars/yousefhadder/markdown-plus.nvim?style=flat-square&logo=github)](https://github.com/yousefhadder/markdown-plus.nvim/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/yousefhadder/markdown-plus.nvim?style=flat-square&logo=github)](https://github.com/yousefhadder/markdown-plus.nvim/issues)
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-11-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->
![507DBB8A-996C-44B7-88BE-ABB7BC1BFD92_1_201_a](https://github.com/user-attachments/assets/8f6b9adf-13ce-4418-b6cf-1196784bda45)

</div>

A comprehensive Neovim plugin that provides modern markdown editing capabilities, implementing features found in popular editors like Typora, Mark Text, and Obsidian.

**Key Features:** Zero dependencies • Works with any filetype • Full test coverage (85%+) • Extensively documented

## Examples features

https://github.com/user-attachments/assets/493361af-f191-4faf-ac1c-4da01222e37d

https://github.com/user-attachments/assets/5ddbc02c-68ba-44f0-8cc0-41807a23e788

## Similar plugins

- [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim) - A Neovim plugin for writing and navigating Obsidian vaults with features like autocompletion for notes/tags, link navigation, image pasting, and daily notes.
- [markdown.nvim](https://github.com/tadmccorkle/markdown.nvim) - Configurable tools for markdown editing including inline style toggling (bold/italic/code), table of contents generation, list management, link handling, and heading navigation.
- [mkdnflow.nvim](https://github.com/jakewvincent/mkdnflow.nvim) - A comprehensive markdown notebook/wiki plugin for fluent navigation with features like link following, to-do lists, table editing, section folding, buffer history navigation, and citation support.
- [mdnotes.nvim](https://github.com/ymich9963/mdnotes.nvim) - A Markdown note-taking plugin with WikiLink support, hyperlink management, asset cleanup, sequential buffer history, table creation, and automatic list continuation.

## Table of Contents

- [Installation](https://github.com/yousefhadder/markdown-plus.nvim/wiki/1.Installation)
- [Features](https://github.com/yousefhadder/markdown-plus.nvim/wiki/2.Features)
- [Configuration](https://github.com/yousefhadder/markdown-plus.nvim/wiki/3.Configuration)
- [Usage](https://github.com/yousefhadder/markdown-plus.nvim/wiki/4.Usage)
- [Keymaps Reference](https://github.com/yousefhadder/markdown-plus.nvim/wiki/5.Keymaps)
- [Customizing Keymaps](https://github.com/yousefhadder/markdown-plus.nvim/wiki/6.Customizing-Keymaps)
- [Contributing](https://github.com/yousefhadder/markdown-plus.nvim/wiki/7.Contributing)
- [Troubleshooting](https://github.com/yousefhadder/markdown-plus.nvim/wiki/8.Troubleshooting)

## Quick Start

**Using lazy.nvim:**

```lua
{
  "yousefhadder/markdown-plus.nvim",
  ft = "markdown",
  opts = {},
}
```

That's it! The plugin will automatically activate with default keymaps when you open a markdown file.

**Want to customize?**

```lua
{
  "yousefhadder/markdown-plus.nvim",
  ft = "markdown",
  opts = {
    -- Your custom configuration here
  },
}
```

See [Configuration](https://github.com/YousefHadder/markdown-plus.nvim/wiki/3.Configuration) for all available options.

## License

MIT License - see [LICENSE](./LICENSE) file for details.

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/neo451"><img src="https://avatars.githubusercontent.com/u/111681693?v=4?s=100" width="100px;" alt="neo451"/><br /><sub><b>neo451</b></sub></a><br /><a href="#ideas-neo451" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/SuniRein"><img src="https://avatars.githubusercontent.com/u/64690248?v=4?s=100" width="100px;" alt="SuniRein"/><br /><sub><b>SuniRein</b></sub></a><br /><a href="https://github.com/YousefHadder/markdown-plus.nvim/issues?q=author%3ASuniRein" title="Bug reports">🐛</a> <a href="https://github.com/YousefHadder/markdown-plus.nvim/commits?author=SuniRein" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Jaehaks"><img src="https://avatars.githubusercontent.com/u/26200835?v=4?s=100" width="100px;" alt="Jaehaks"/><br /><sub><b>Jaehaks</b></sub></a><br /><a href="#ideas-Jaehaks" title="Ideas, Planning, & Feedback">🤔</a> <a href="https://github.com/YousefHadder/markdown-plus.nvim/issues?q=author%3AJaehaks" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/VectorZeroAI"><img src="https://avatars.githubusercontent.com/u/222407581?v=4?s=100" width="100px;" alt="Null"/><br /><sub><b>Null</b></sub></a><br /><a href="https://github.com/YousefHadder/markdown-plus.nvim/issues?q=author%3AVectorZeroAI" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://www.buaa.edu.cn/"><img src="https://avatars.githubusercontent.com/u/151506788?v=4?s=100" width="100px;" alt="赵泽文(Zhao Zev)"/><br /><sub><b>赵泽文(Zhao Zev)</b></sub></a><br /><a href="#ideas-Zevan770" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/coglinks"><img src="https://avatars.githubusercontent.com/u/103402972?v=4?s=100" width="100px;" alt="coglinks"/><br /><sub><b>coglinks</b></sub></a><br /><a href="https://github.com/YousefHadder/markdown-plus.nvim/issues?q=author%3Acoglinks" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/levYatsishin"><img src="https://avatars.githubusercontent.com/u/58232690?v=4?s=100" width="100px;" alt="Leo Yatsishin"/><br /><sub><b>Leo Yatsishin</b></sub></a><br /><a href="#ideas-levYatsishin" title="Ideas, Planning, & Feedback">🤔</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/jemag"><img src="https://avatars.githubusercontent.com/u/7985687?v=4?s=100" width="100px;" alt="Alexandre Desjardins"/><br /><sub><b>Alexandre Desjardins</b></sub></a><br /><a href="#ideas-jemag" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/j-steinbach"><img src="https://avatars.githubusercontent.com/u/69524139?v=4?s=100" width="100px;" alt="J. Steinbach"/><br /><sub><b>J. Steinbach</b></sub></a><br /><a href="https://github.com/YousefHadder/markdown-plus.nvim/issues?q=author%3Aj-steinbach" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/ambaradan"><img src="https://avatars.githubusercontent.com/u/87865413?v=4?s=100" width="100px;" alt="ambaradan"/><br /><sub><b>ambaradan</b></sub></a><br /><a href="https://github.com/YousefHadder/markdown-plus.nvim/commits?author=ambaradan" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/webdavis"><img src="https://avatars.githubusercontent.com/u/23553256?v=4?s=100" width="100px;" alt="Stephen A. Davis"/><br /><sub><b>Stephen A. Davis</b></sub></a><br /><a href="#ideas-webdavis" title="Ideas, Planning, & Feedback">🤔</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!
