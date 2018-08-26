-- Copyright © 2018 Daniel Pittman <daniel@rimspace.net>
-- See LICENSE for more details.
if _G['SlippyCheezeReadItOnce'] == nil then
  SlippyCheezeReadItOnce = {
    ADDON_NAME="SlippyCheezeReadItOnce",
    DISPLAY_NAME = "|c798BD2ReadItOnce|r",
    DOUBLE_TAP_TIME = 1000,
    previousBook = {id=nil, time=0},
    -- seen holds our saved variables.
    seen = {}
  }
end

-- my local alias for the addon itself.
local M = SlippyCheezeReadItOnce

local unpack = unpack
local insert = table.insert

-- reduce consing at runtime in debug message display
local msg_prefix = M.DISPLAY_NAME..": "

local function msg(fmt, ...)
  local args = {}
  for n=1, select('#', ...) do
    insert(args, tostring(select(n, ...)))
  end

  d(msg_prefix..zo_strformat(fmt, unpack(args)))
end

-- return bool, have we seen this before.  never called before saved variables
-- are loaded and initialized.
function M:HaveSeenBookBefore(id, title, body)
  if type(id) ~= "number" then
    msg("ReadItOnce: id is <<1>> (<<2>>)", type(id), id)
    return false
  end

  -- ensure that we index by string, not number, in the table.
  -- luacheck: push noredefined
  local id = tostring(id)
  -- luacheck: pop
  local bodyHash = HashString(body)

  local record = self.seen[id]
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
  self.seen[id] = {id=id, title=title, bodyHash=bodyHash}
  return false
end

-- Called when we want to skip showing a book.  Probably going to be very
-- strange if you call it any other time!
function M:DoNotShowThisBook(title)
  PlaySound(SOUNDS.NEGATIVE_CLICK)

  local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, nil)
  params:SetText(zo_strformat("You have already read \"<<1>>\"", title))
  params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_LORE_BOOK_LEARNED)
  params:SetLifespanMS(850)
  CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)

  EndInteraction(INTERACTION_BOOK)
end

-- Sadly, we have to override the original method, which is a local anonymous
-- function, and which we have apparently no access to in order to hook nicely.
--
-- The bulk of this is a direct copy-paste from the lore reader, as of USOUI
-- 100023
--
-- The HaveSeenBook logic is my addition.
function M:OnShowBookOverride(eventCode, title, body, medium, showTitle, bookId)
  -- never block a book if we are not in the most basic state, which is the
  -- world interaction state.
  if not SCENE_MANAGER:IsShowingBaseScene() then
    return self.DoNotShowThisBook(title)
  end

  -- seen before, block unless is double-tap within the limit
  if HaveSeenBookBefore(bookId, title, body) then
    -- different book from the last time?  block.
    if self.previousBook.id ~= bookId then
      return self.DoNotShowThisBook(title)
    end

    -- last book was more than our double-tap time ago?  block.
    local now = GetGameTimeMilliseconds()
    if (now - self.previousBook.time) > DOUBLE_TAP_TIME then
      return self.DoNotShowThisBook(title)
    end

    -- otherwise record this state for the future.
    self.previousBook.id = bookId
    self.previousBook.time = now
  end

  -- meh, this is copied from the local function in the ZOS code. :(
  if LORE_READER:Show(title, body, medium, showTitle) then
    PlaySound(LORE_READER.OpenSound)
  else
    EndInteraction(INTERACTION_BOOK)
  end
end

local function OnAddonLoaded(_, name)
  if name ~= ADDON_NAME then return end
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
