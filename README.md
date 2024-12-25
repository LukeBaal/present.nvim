# `present.nvim`

A nvim plugin for presenting markdown files

# Features

Can execute code in lua blocks, when you have them in a slide

```lua
print("Hello, world!", 37)
```

# Usage

```lua
require("present.nvim").start_presentation {}
```

Use `n` and `p` to navigate markdown slides. Use `q` to end presentation


