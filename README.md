# `present.nvim`

A nvim plugin for presenting markdown files

# Features

Can execute code in lua blocks, when you have them in a slide

```lua
print("Hello, world!", 37)
```
# Other Features

Can execute code in js blocks, when you have them in a slide

```javascript
console.log({ myfield: true, other: 23 });
```

# Even More Features

Can execute code in js blocks, when you have them in a slide

```python
language = "python"
print(f"Hello, from {language}")
```

# Usage

```lua
require("present.nvim").start_presentation {}
```

Use `n` and `p` to navigate markdown slides. Use `q` to end presentation


