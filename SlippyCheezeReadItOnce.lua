-- Copyright © 2018 Daniel Pittman <daniel@rimspace.net>
-- See LICENSE for more details.
SlippyCheeze = SlippyCheeze or {}

if not SlippyCheeze.ReadItOnce then
  SlippyCheeze.ReadItOnce = {
    IS_RELEASE_VERSION = false,
    NAME="SlippyCheezeReadItOnce",
    DISPLAY_NAME = "|c798BD2ReadItOnce|r",
    -- for double-tap bypass of the block
    previousBook = {
      id = nil,
      time = 0,
      count = 0,
    },
    DOUBLE_TAP_TIME = 1000,
    -- used for reporting on our background achievement scan
    async = nil,
    lore = {
      added = 0,
      scanned = 0,
      start = 0,
    },
    -- seen holds our saved variables, eg, seen books.
    seen = {}
  }
end

local addon = SlippyCheeze.ReadItOnce

local unpack = unpack
local insert = table.insert

-- reduce consing at runtime in debug message display
local msg_prefix = addon.DISPLAY_NAME..": "

local function msg(fmt, ...)
  local args = {}
  for n=1, select('#', ...) do
    insert(args, tostring(select(n, ...)))
  end

  d(msg_prefix..zo_strformat(fmt, unpack(args)))
end

-- return bool, have we seen this before.  never called before saved variables
-- are loaded and initialized.
function addon:HaveSeenBookBefore(id, title, body)
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
function addon:DoNotShowThisBook(title, onlySound)
  PlaySound(SOUNDS.NEGATIVE_CLICK)

  if not onlySound then
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, nil)
    params:SetText(zo_strformat("You have already read \"<<1>>\"", title))
    params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_LORE_BOOK_LEARNED)
    params:SetLifespanMS(850)
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
  end

  EndInteraction(INTERACTION_BOOK)
end

-- Sadly, we have to override the original method, which is a local anonymous
-- function, and which we have apparently no access to in order to hook nicely.
--
-- The bulk of this is a direct copy-paste from the lore reader, as of USOUI
-- 100023
--
-- The HaveSeenBook logic is my addition.
function addon:OnShowBookOverride(eventCode, title, body, medium, showTitle, bookId)
  -- never block a book if we are not in the most basic state, which is the
  -- world interaction state.
  if not SCENE_MANAGER:IsShowingBaseScene() then
    return self:DoNotShowThisBook(title)
  end

  -- seen before, block unless is double-tap within the limit
  if self:HaveSeenBookBefore(bookId, title, body) then
    -- different book from the last time?
    local sameBook = (self.previousBook.id == bookId)

    -- last book was more than our double-tap time ago?
    local now = GetGameTimeMilliseconds()
    local timeSinceLastTap = (now - self.previousBook.time)
    local doubleTap = (timeSinceLastTap <= addon.DOUBLE_TAP_TIME)

    -- if not self.IS_RELEASE_VERSION then
    --   msg('show-p: sameBook=<<1>> doubleTap=<<2>> count=<<3>> timeSinceLastTap=<<4>>',
    --       sameBook, doubleTap, self.previousBook.count, timeSinceLastTap)
    -- end

    if sameBook then
      -- allow a double-tap after a failed double-tap
      self.previousBook.time = now
      -- remember if we are being real spammy here, but reset that tracker if
      -- they give a long enough pause.
      if timeSinceLastTap < 3000 then
        self.previousBook.count = self.previousBook.count + 1
      else
        self.previousBook.count = 1
      end

      if not doubleTap then
        -- don't keep on yelling if they spam interact too much, just beep.
        local onlySound = (self.previousBook.count > 1)
        return self:DoNotShowThisBook(title, onlySound)
      end
    else
      -- otherwise record this state for the future.
      self.previousBook.id = bookId
      self.previousBook.count = 1
      self.previousBook.time = now

      -- and block the book.
      return self:DoNotShowThisBook(title)
    end
  end

  -- meh, this is copied from the local function in the ZOS code. :(
  if LORE_READER:Show(title, body, medium, showTitle) then
    PlaySound(LORE_READER.OpenSound)
  else
    EndInteraction(INTERACTION_BOOK)
  end
end

function addon:ScanOneLoreCategory(category)
  local _, numCollections, _ = GetLoreCategoryInfo(category)
  self.async:For(1, numCollections):Do(function(collection) self:ScanOneLoreCollection(category, collection) end)
end

function addon:ScanOneLoreCollection(category, collection)
  local _, _, _, numBooks, _, _, _ = GetLoreCollectionInfo(category, collection)
  self.async:For(1, numBooks):Do(function(book) self:ScanOneLoreBook(category, collection, book) end)
end

function addon:ScanOneLoreBook(category, collection, book)
  self.lore.scanned = self.lore.scanned + 1

  local title, _, known, id = GetLoreBookInfo(category, collection, book)
  if known then
    local body = ReadLoreBook(category, collection, book)
    if not self:HaveSeenBookBefore(id, title, body) then
      self.lore.added = self.lore.added + 1
    end
  end
end

function addon:ReportAfterLoreScan()
  if self.lore.added > 0 then
    -- ZOS quirk: the number **must** be the third argument.  the plural must
    -- be a substitution of text.
    msg('added <<2>> <<m:1>> found in your achievements.', 'previously read book', self.lore.added)
  end

  if not self.IS_RELEASE_VERSION then
    local duration = FormatTimeMilliseconds(
      GetGameTimeMilliseconds() - self.lore.start,
      TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL_SHOW_TENTHS_SECS,
      TIME_FORMAT_PRECISION_TENTHS_RELEVANT,
      TIME_FORMAT_DIRECTION_NONE)
    msg('SyncFromLoreBooks: scan ran for <<1>>', duration)
  end
end

function addon:SyncFromLoreBooks()
  self.async = LibStub("LibAsync"):Create(self.NAME)

  self.lore.added = 0
  self.lore.scanned = 0
  self.lore.start = GetGameTimeMilliseconds()

  self.async:For(1, GetNumLoreCategories()):Do(function(category) self:ScanOneLoreCategory(category) end)
  self.async:Then(function() self:ReportAfterLoreScan() end)
end

function addon:OnAddonLoaded(name)
  if name ~= addon.NAME then return end
  EVENT_MANAGER:UnregisterForEvent(addon.NAME, EVENT_ADD_ON_LOADED)

  -- if the second argument, the version, changes then the data is wiped and
  -- replaced with the defaults.
  self.seen = ZO_SavedVars:NewAccountWide("SlippyCheezeReadItOnceData", 1)

  -- replace the original event handler with ours; sadly, we don't have
  -- access to the original implementation to do anything nicer. :/
  LORE_READER.control:UnregisterForEvent(EVENT_SHOW_BOOK)
  LORE_READER.control:RegisterForEvent(EVENT_SHOW_BOOK,
                                       function(...) self:OnShowBookOverride(...) end)

  -- and once we actually log in, scan the collections for missing records in
  -- our data on what we have seen, since this is the only in-game history we
  -- can use...
  local function SyncFromLoreBooksShim(...)
    EVENT_MANAGER:UnregisterForEvent(addon.NAME, EVENT_PLAYER_ACTIVATED)
    addon:SyncFromLoreBooks()
  end
  EVENT_MANAGER:RegisterForEvent(addon.NAME, EVENT_PLAYER_ACTIVATED, SyncFromLoreBooksShim)
end

-- bootstrapping
EVENT_MANAGER:RegisterForEvent(addon.NAME, EVENT_ADD_ON_LOADED, function(_, name) addon:OnAddonLoaded(name) end)
