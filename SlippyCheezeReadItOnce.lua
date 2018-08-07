-- Copyright © 2018 Daniel Pittman <daniel@rimspace.net>
-- See LICENSE for more details.

-- addon core object.
local ADDON_NAME = "SlippyCheezeReadItOnce"

-- saved var: which books have been seen.
local seen

local unpack = table.unpack or unpack
local insert = table.insert
local function dmsg(msg, ...)
   local args = {}
   for n=1, select('#', ...) do
      insert(args, tostring(select(n, ...)))
   end

   d(zo_strformat(msg, unpack(args)))
end

-- return bool, have we seen this before.  never called before saved variables
-- are loaded and initialized.
local function HaveSeenBookBefore(id, title, body)
   if type(id) ~= "number" then
      dmsg("ReadItOnce: id is <<1>> (<<2>>)", type(id), id)
      return false
   end

   -- ensure that we index by string, not number, in the table.
   local id = tostring(id)
   local bodyHash = HashString(body)

   local record = seen[id]
   if record then
      -- probably have seen it before, but check for changes
      if record.id ~= id then
         d("ReadItOnce: book id changed from <<1>> to <<2>>", record.id, id)
      end
      if record.title ~= title then
         d("ReadItOnce: book title changed from '<<1>>' to '<<2>>'", record.title, title)
      end
      if record.bodyHash ~= bodyHash then
         d("ReadItOnce: book body changed")
      end

      -- don't show.
      return true
   end

   -- have not seen, record it, and return that fact
   seen[id] = {id=id, title=title, bodyHash=bodyHash}
   return false
end

-- Sadly, we have to override the original method, which is a local anonymous
-- function, and which we have apparently no access to in order to hook nicely.
--
-- The bulk of this is a direct copy-paste from the lore reader, as of USOUI
-- 100023
--
-- The HaveSeenBook logic is my addition.
local function OnShowBookOverride(eventCode, title, body, medium, showTitle, bookId)
   if HaveSeenBookBefore(bookId, title, body) then
      ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.BOOK_ACQUIRED, "You have already read \"<<1>>\"", title)
      EndInteraction(INTERACTION_BOOK)
      return
   end

   if LORE_READER:Show(title, body, medium, showTitle) then
      PlaySound(LORE_READER.OpenSound)
   else
      EndInteraction(INTERACTION_BOOK)
   end
end

local function OnAddonLoaded(_, name)
   if name ~= ADDON_NAME then
      return
   end

   EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

   -- if the second argument, the version, changes then the data is wiped and
   -- replaced with the defaults.
   seen = ZO_SavedVars:NewAccountWide("SlippyCheezeReadItOnceData", 1)

   -- replace the original event handler with ours; sadly, we don't have
   -- access to the original implementation to do anything nicer. :/
   LORE_READER.control:UnregisterForEvent(EVENT_SHOW_BOOK)
   LORE_READER.control:RegisterForEvent(EVENT_SHOW_BOOK, OnShowBookOverride)
end

-- bootstrapping
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
