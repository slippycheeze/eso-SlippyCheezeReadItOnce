# SlippyCheeze's Read It Once

Reduce the effort and memorization required to read books throughout the
world. When you encounter a book you have previously seen, it will display an
alert informing you of that, rather than opening the book for reading.

The very first time you encounter a book, however, it will be shown as normal.

I prefer this to blocking all books, all the time, as I enjoy the lore ... I
just don't want to be trying to remember if I read the book, and dislike the
time taken to close it again when searching a bazillion bookshelves in
a delve.

## Inventory and Journal books are displayed normally

Anything in your inventory, or accessed through the Lore Journal, will display
normally.  Accessing books through non-standard book collecting addons should
work normally, but has not been tested.  Please report issues appropriately.

## Configuration

There is no configuration for the addon.

This is an account-wide addon, so any book seen on any character will count as
"read". You should, however, still receive full credit for skill
points regardless.

## Help!  I have a problem!

### I need to read a book again, for a quest!

If you try and read the exact same book twice within one second, you bypass
the block.  We still play the alert sound and display the warning the first
time you interact, but the second will open it as it would without the
addon installed.

I use this for the occasional quest note that I need to reference more than
once, and found that one second was more than enough time to make this
work smoothly.

### I found a different problem, what should I do?

Please report bugs [through the GitHub issue tracker][gh-bugs].  You can also
post them in the comments section here, if you must, though I'm less likely to
notice and fix them that way.

## Can I contribute?

I'm happy to accept contributions, though I strongly prefer keeping addons
small, and very single purpose, so do try and stick with the single theme.

Please also stick to one change per submission: if you make multiple,
unrelated changes, I'm not going to be very enthusiastic about adding that,
compared to someone who sent them separately.

The [code is available on GitHub][gh-repo], and git patches and/or GitHub pull
requests are the best possible way to contribute.

Sending, or linking, modified files, is much more difficult, but if you must,
you must.  If you go this path, please make absolutely certain that you tell
me which version the change was made against, so that I can integrate
it safely.

[gh-bugs]: https://github.com/slippycheeze/eso-SlippyCheezeReadItOnce/issues/new
[gh-repo]: https://github.com/slippycheeze/eso-SlippyCheezeReadItOnce
