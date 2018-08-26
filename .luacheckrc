-- -*- lua -*-

files[".luacheckrc"].ignore = {"212"}

stds.eso = {
  read_globals = {
    HashString = {},
    PlaySound = {},
    d = {},
    zo_strformat = {},
    SOUNDS = {other_fields = true},
  },
}

std = 'lua51+eso'

new_globals = {
  'SlippyCheezeReadItOnce',
}
