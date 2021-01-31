# RZS Simple Image Cleaning Utility

This project started with a small Python script that applied a threshold effect to an image using the PIL library. Since then, it has grown into a larger "library" I often use to clean up images produced by a printer's scanner. Note that I hesitate to even call it a library, as it's really small and rudimentary.

The reason I'm publishing it to GitHub is so that I have source control, so that I can use it with a personal [Discord bot (link TBA)]() and to try out publishing something to [LuaRocks](https://luarocks.org) and [lit](https://github.com/luvit/lit).

In other words, this is mostly meant to be a private module for personal projects. This means no docs and sparse support. Still, feel free to use this yourself.

## What it does

RSICU is simple - it has a list of predefined "operations" it can perform on images. These are individual tasks (thresholds, brightness, etc). You give the library a list of operation names (well, they're more like string "keys") and related arguments, which in turn uses the input to apply the specified operations. Additionally, it has a handful of extra utility functions related to user input handling and data verification for the operation keys.

## `RSICUCommandLine`

Inside this repository you will also find a second program, `RSICUCommandLine`. This program is a command line REPL interface for RSICU, designed to be used to edit an image using a trial-and-error process. In other words, it firsts asks for an image and the wanted operations. Then, it repeatedly takes parameters, applying edits, until a satisfactory image is produced. Again, it's all very simple.

## Installation

RSICU depends on [lua-vips](https://github.com/libvips/lua-vips), which in turn depends on [libvips](http://libvips.github.io/libvips) and [LuaJIT](https://luajit.org/).

At the moment, there are no options other than downloading this repo, but my goal is to publish this package to both LuaRocks and lit.

Once installed, you should be able to just call
```lua
local rsicu = require("rsicu")
```

