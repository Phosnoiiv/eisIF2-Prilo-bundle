local const = import("const")
local dbapi = import("dbapi")
local Cachable = import("Cachable")
local ClientSettingsKey = import("ClientSettingsKey")
local LiveMenu = import("LiveMenu")
local MemberCategory = import("MemberCategory")

local LiveList = {}



function LiveList.getInstance(options) -- 12-574
  local LiveMenuAPI = import("LiveMenuAPI")
  local LiveListSort = import("LiveListSort")

  local liveList = {}

  options = totable(options)
  local livesFromAPI, badgesFromAPI = LiveMenuAPI.getLiveList()
  local allLives = nil
  local currentLives = nil
  local cacheKey = "all_live"
  local cachedAllLives = Cachable.get(cacheKey)
  local liveMenuSetting = LiveMenu.Setting.get()
  local listStatus = liveMenuSetting.list_status
  local liveTarget = liveMenuSetting.live_target
  local clientSetting = dbapi.getStoredClientSetting(ClientSettingsKey.SERIES_LIVE_MENU) or {
    current_series_id = 0,
  }
  local isSpecialTarget = liveTarget ~= const.LIVE_TARGET.NORMAL
  local targetDifficulty = LiveMenu.Setting.getTargetDiffculty(liveMenuSetting, liveTarget)
  local liveTargetName = const.LIVE_TARGET_NAME[liveTarget]
  local targetDifficultyName = const.DIFFICULTY_STRING[targetDifficulty]:lower()
  local difficulty = 1
  local normalDifficulty = 1
  local eventDifficulty = 0
  local trainingDifficulty = const.DIFFICULTY.MASTER
  local onResetFilter = tofunction(options.on_reset_filter)
  local onNoPlayableLive = tofunction(options.on_no_playable_live)



  local function reload() -- 43-46
    allLives = LiveListSort.getAllSortLiveList(livesFromAPI, listStatus)
    currentLives = allLives[liveTargetName][targetDifficultyName]
  end

  local function resetFilter() -- 48-52
    listStatus.filter = LiveListSort.getDefaultFilters()
    reload()
    liveMenuSetting.list_status = listStatus
  end

  local function saveSetting() -- 54-56
    LiveMenu.Setting.set(liveMenuSetting)
  end

  local function reloadWithMessage() -- 58-62
    onResetFilter()
    resetFilter()
    saveSetting()
  end

  reload()

  if #currentLives < 1 then
    reloadWithMessage()
  end

  if liveMenuSetting.filter_reset_possibility and liveMenuSetting.live_difficulty_id then
    local found = nil

    for index, live in ipairs(currentLives) do
      if tonumber(live.live_difficulty_id) == tonumber(liveMenuSetting.live_difficulty_id) then
        found = index
        break
      end
    end

    if not found then
      if LiveListSort.checkDefaultFilters(listStatus.filter) then
        onNoPlayableLive()
      else
        onResetFilter()
      end

      resetFilter()
    end

    liveMenuSetting.filter_reset_possibility = false
    saveSetting()
  end

  if isSpecialTarget and #currentLives < 1 then
    liveTarget = const.LIVE_TARGET.NORMAL
    isSpecialTarget = false
    targetDifficulty = liveMenuSetting.normal_difficulty
    liveTargetName = const.LIVE_TARGET_NAME[liveTarget]
    targetDifficultyName = const.DIFFICULTY_STRING[targetDifficulty]:lower()
    currentLives = allLives[liveTargetName][targetDifficultyName]
    liveMenuSetting.live_target = const.LIVE_TARGET.NORMAL
    liveMenuSetting.event_difficulty = const.DIFFICULTY.EASY
    liveMenuSetting.live_difficulty_id = nil
    saveSetting()
  end

  if liveMenuSetting.live_difficulty_id then
    Cachable.clear(cacheKey)
    cachedAllLives = Cachable.get(cacheKey)
    local liveDifficultyId = tonumber(liveMenuSetting.live_difficulty_id)
    local lives = {}
    local foundIndex = nil

    for index, live in ipairs(currentLives) do
      if tonumber(live.live_difficulty_id) == liveDifficultyId then
        foundIndex = index
      end

      if foundIndex then
        table.insert(lives, live)
      end
    end

    if not foundIndex then
      for index, live in ipairs(currentLives) do
        if tonumber(live.live_difficulty_id) == liveDifficultyId then
          foundIndex = index
        end

        if foundIndex then
          table.insert(lives, live)
        end
      end
    end

    if foundIndex then
      for index, live in ipairs(currentLives) do
        if index < foundIndex then
          table.insert(lives, live)
        end
      end
    else
      lives = currentLives
    end

    allLives[liveTargetName][targetDifficultyName] = lives
    table.insert(cachedAllLives, allLives)
    currentLives = lives
  end











  function liveList.getAllLiveList() -- 161-163
    return allLives
  end

  function liveList.getLiveList() -- 165-167
    return allLives[const.LIVE_TARGET_NAME[liveTarget]]
  end

  function liveList.getCurrentLiveList() -- 169-171
    return currentLives
  end

  function liveList.getLive(index) -- 173-175
    return currentLives[index]
  end

  function liveList.getCurrentDifficulty() -- 177-179
    return targetDifficulty
  end

  function liveList.getCurrentDifficultyString() -- 181-183
    return const.DIFFICULTY_STRING[targetDifficulty]:lower()
  end

  function liveList.getDifficultyList() -- 185-187
    return { old = difficulty, current = targetDifficulty }
  end

  function liveList.getLiveTarget() -- 189-191
    return liveTarget
  end

  function liveList.getBadgeList() -- 193-227
    if clientSetting.current_series_id == MemberCategory.Other then
      return badgesFromAPI
    end

    local badges = {}

    for _, target in pairs(const.LIVE_TARGET_NAME) do
      badges[target] = {}
    end

    local function processLive(live) -- 204-216
      if clientSetting.current_series_id ~= live.setting.live_track.member_category then
        return
      end

      for target, targetBadges in pairs(badgesFromAPI) do
        local liveDifficultyId = tonumber(live.live_difficulty_id)

        if targetBadges[liveDifficultyId] then
          table.insert(badges[target], liveDifficultyId)
        end
      end
    end

    for _, targetLives in pairs(livesFromAPI) do
      for _, difficultyLives in pairs(targetLives) do
        for _, live in ipairs(difficultyLives) do
          processLive(live)
        end
      end
    end

    return badges
  end

  function liveList.getBadge(liveDifficultyId) -- 229-231
    return badgesFromAPI[const.LIVE_TARGET_NAME[liveTarget]][liveDifficultyId]
  end

  function liveList.resetBadge(liveDifficultyId) -- 233-235
    badgesFromAPI[const.LIVE_TARGET_NAME[liveTarget]][liveDifficultyId] = nil
  end

  function liveList.isTrainingMode() -- 237-239
    return liveTarget == const.LIVE_TARGET.TRAINING
  end

  local function hasNoLive(_, theDifficulty) -- 241-249
    for difficultyId, difficultyName in ipairs(const.DIFFICULTY_STRING) do
      if theDifficulty == difficultyId then
        return #currentLives[difficultyName:lower()] < 1
      end
    end

    return false
  end

  function liveList.canChangeDifficulty(newDifficulty) -- 251-257
    if targetDifficulty == newDifficulty or hasNoLive(newDifficulty) then
      return false
    end

    return true
  end

  function liveList.updateCurrentLiveList(index) -- 259-278
    local lives = {}
    for i = index, #currentLives, 1 do
      table.insert(lives, currentLives[i])
    end

    if 1 < index then
      for i = 1, index - 1, 1 do
        table.insert(lives, currentLives[i])
      end
    end

    for _, live in ipairs(lives) do
      if not live.status then
        live.status = 1
      end
    end

    currentLives = lives
  end

  function liveList.changeDifficulty(newDifficulty, index, args) -- 280-316
    local isSelectedFirst = false
    local live = liveList.getLive(index)
    difficulty = targetDifficulty
    targetDifficulty = newDifficulty

    if liveTarget == const.LIVE_TARGET.NORMAL then
      normalDifficulty = newDifficulty
    elseif liveTarget == const.LIVE_TARGET.EVENT then
      eventDifficulty = newDifficulty
    elseif liveTarget == const.LIVE_TARGET.TRAINING then
      trainingDifficulty = newDifficulty
    end

    local difficultyName = nil
    for key, value in pairs(const.DIFFICULTY_STRING) do
      if key == targetDifficulty then
        difficultyName = value:lower()
        break
      end
    end

    currentLives = LiveListSort.getDisplayLiveList(allLives[const.LIVE_TARGET_NAME[liveTarget]][difficultyName], args)

    if not live then
      return isSelectedFirst
    end

    local lives = LiveListSort.sortSelectLiveFirst(currentLives, live)

    if lives[1] and lives[1].setting.live_track.id == live.setting.live_track.id then
      isSelectedFirst = true
      currentLives = lives
    end

    return isSelectedFirst
  end

  function liveList.changeLiveCategory(newTarget) -- 318-389
    local newTargetName = const.LIVE_TARGET_NAME[newTarget]
    local newTargetDifficulty = LiveMenu.Setting.getTargetDiffculty(liveMenuSetting, newTarget)
    local newTargetDifficultyName = const.DIFFICULTY_STRING[tonumber(newTargetDifficulty)]:lower()
    local lives = LiveListSort.getSortLiveList(newTargetName, newTargetDifficultyName, liveMenuSetting.list_status)

    local function finish() -- 324-334
      liveTarget = newTarget
      targetDifficulty = newTargetDifficulty
      isSpecialTarget = liveTarget ~= const.LIVE_TARGET.NORMAL

      local targetLiveDifficultyId = LiveMenu.Setting.getTargetLiveDiffcultyId(liveMenuSetting, liveTarget)
      currentLives = LiveListSort.sortSelectLiveDifficultyIdFirst(lives, targetLiveDifficultyId)
      liveMenuSetting.live_target = newTarget

      saveSetting()
    end

    if 0 < #lives then
      finish()
      return true, false
    end

    local function findAvailableDifficulty() -- 341-360
      for _, listDifficulty in ipairs(const.LIVE_LIST_DIFFICULTY) do
        local difficultyName = listDifficulty.difficulty_name:lower()
        if 0 < #allLives[newTargetName][difficultyName] then
          lives = allLives[newTargetName][difficultyName]
          newTargetDifficulty = listDifficulty.difficulty_id
          liveMenuSetting.live_difficulty_id = nil

          if liveTarget == const.LIVE_TARGET.NORMAL then
            liveMenuSetting.normal_difficulty = newTargetDifficulty
          elseif liveTarget == const.LIVE_TARGET.EVENT then
            liveMenuSetting.event_difficulty = newTargetDifficulty
          elseif liveTarget == const.LIVE_TARGET.TRAINING then
            liveMenuSetting.training_difficulty = newTargetDifficulty
          end

          return
        end
      end
    end

    findAvailableDifficulty()

    local isFilterReset = false

    if #lives < 1 then
      isFilterReset = true

      listStatus.filter = LiveListSort.getDefaultFilters()
      allLives = LiveListSort.getAllSortLiveList(livesFromAPI, listStatus)
      lives = allLives[newTargetName][newTargetDifficultyName]

      if #lives < 1 then
        findAvailableDifficulty()
      end
    end

    local isSuccessful = 0 < #lives

    if isSuccessful then
      finish()

      if isFilterReset then
        onResetFilter()
      end
    end

    return isSuccessful, isFilterReset
  end

  function liveList.applyFilterAndSort(isAllowChangeDifficulty) -- 391-417
    local targetName = const.LIVE_TARGET_NAME[liveTarget]
    local difficultyName = const.DIFFICULTY_STRING[targetDifficulty]:lower()
    allLives = LiveListSort.getAllSortLiveList(livesFromAPI, listStatus)
    currentLives = LiveListSort.sortSelectLiveDifficultyIdFirst(allLives[targetName][difficultyName], liveMenuSetting.live_difficulty_id)



    local function findAvailableDifficulty() -- 399-408
      for _, listDifficulty in ipairs(const.LIVE_LIST_DIFFICULTY) do
        local newDifficultyName = listDifficulty.difficulty_name:lower()
        currentLives = LiveListSort.sortSelectLiveDifficultyIdFirst(allLives[targetName][newDifficultyName], liveMenuSetting.live_difficulty_id)

        if 0 < #currentLives then
          return listDifficulty.difficulty_id
        end
      end
    end

    if #currentLives < 1 then
      if not isAllowChangeDifficulty then
        reloadWithMessage()
      else
        return findAvailableDifficulty()
      end
    end
  end

  function liveList.saveDifficulty(newDifficulty, selectedLive) -- 419-431
    targetDifficulty = newDifficulty

    if liveMenuSetting.live_target == const.LIVE_TARGET.NORMAL then
      liveMenuSetting.normal_difficulty = newDifficulty
    elseif liveMenuSetting.live_target == const.LIVE_TARGET.EVENT then
      liveMenuSetting.event_difficulty = newDifficulty
    elseif liveMenuSetting.live_target == const.LIVE_TARGET.TRAINING then
      liveMenuSetting.training_difficulty = newDifficulty
    end

    liveList.rememberSelectedLive(selectedLive)
  end

  function liveList.storeLiveDifficultyId(liveDifficultyId) -- 433-452
    local live = liveList.getLive(liveDifficultyId)

    if live then
      liveMenuSetting.live_difficulty_id = live.live_difficulty_id

      if liveMenuSetting.live_target == const.LIVE_TARGET.NORMAL then
        liveMenuSetting.normal_live_difficulty_id = live.live_difficulty_id
      elseif liveMenuSetting.live_target == const.LIVE_TARGET.EVENT then
        liveMenuSetting.event_live_difficulty_id = live.live_difficulty_id
      else
        liveMenuSetting.training_live_difficulty_id = live.live_difficulty_id
      end

      saveSetting()
    end



  end

  function liveList.rememberSelectedLive(selectedLive) -- 454-460
    if selectedLive and selectedLive.live_difficulty_id then
      liveMenuSetting.live_difficulty_id = selectedLive.live_difficulty_id
    end

    saveSetting()
  end

  function liveList.saveFilterSortSetting(filter, sortLabel) -- 462-468
    liveMenuSetting.list_status.filter = filter
    liveMenuSetting.list_status.sort.label = sortLabel

    saveSetting()
    return liveMenuSetting
  end

  function liveList.saveSortOrder(order) -- 470-475
    liveMenuSetting.list_status.sort.order = order

    saveSetting()
    return liveMenuSetting
  end

  function liveList.countBySeries() -- 477-511
    local counts = {
      [MemberCategory.All] = {},
      [MemberCategory.Muse] = {},
      [MemberCategory.Aqours] = {},
      [MemberCategory.Nijigasaki] = {},
      [MemberCategory.Liella] = {},
    }

    for memberCategory, count in pairs(counts) do
      local totalCount = 0

      for targetNameUpper, _ in pairs(const.LIVE_TARGET) do
        local targetName = targetNameUpper:lower()
        local targetCount = 0

        for _, targetLives in pairs(livesFromAPI[targetName]) do
          for _, live in ipairs(targetLives) do
            if live.setting.live_track.member_category == memberCategory or memberCategory == MemberCategory.All then
              targetCount = targetCount + 1
            end
          end
        end

        count[targetName] = targetCount
        totalCount = totalCount + targetCount
      end

      count.total_count = totalCount
    end



    return counts
  end

  function liveList.getSeriesId() -- 513-515
    return clientSetting.current_series_id
  end

  function liveList.saveSelectedSeries(seriesId) -- 517-520
    clientSetting.current_series_id = seriesId
    dbapi.storeClientSetting(ClientSettingsKey.SERIES_LIVE_MENU, clientSetting)
  end

  function liveList.adjustCategoryByCount(counts) -- 522-535
    if counts[const.LIVE_TARGET_NAME[liveTarget]] > 0 then
      return liveTarget
    end

    for targetName, targetId in pairs(const.LIVE_TARGET) do
      if counts[targetName:lower()] > 0 then
        reload()

        return targetId
      end
    end

  end

  function liveList.getSeriesBadgeList() -- 537-563
    local seriesBadges = { 0, 0, 0, 0 }
    local otherBadge = 0

    local function processLive(live) -- 541-552
      for _, targetBadges in pairs(badgesFromAPI) do
        if targetBadges[tonumber(live.live_difficulty_id)] then
          local seriesId = live.setting.live_track.member_category
          if seriesBadges[seriesId] then
            seriesBadges[seriesId] = seriesBadges[seriesId] + 1
          else
            otherBadge = otherBadge + 1
          end
        end
      end
    end

    for _, targetLives in pairs(livesFromAPI) do
      for _, difficultyLives in pairs(targetLives) do
        for _, live in ipairs(difficultyLives) do
          processLive(live)
        end
      end
    end

    return seriesBadges, otherBadge
  end

  function liveList.reload() -- 565-567
    reload()
  end

  function liveList.reloadWithMessage() -- 569-571
    reloadWithMessage()
  end

  return liveList
end


function LiveList.tryUpdateSeries(newSeriesId) -- 577-586
  local clientSetting = dbapi.getStoredClientSetting(ClientSettingsKey.SERIES_LIVE_MENU) or {
    current_series_id = 0,
  }
  if clientSetting.current_series_id == MemberCategory.Other or clientSetting == newSeriesId then
    return
  end
  clientSetting.current_series_id = newSeriesId
  dbapi.storeClientSetting(ClientSettingsKey.SERIES_LIVE_MENU, clientSetting)
end

function LiveList.updateSetting(newSetting) -- 588-597
  local setting = LiveMenu.Setting.get()
  setting.live_target = newSetting.live_target
  setting.event_difficulty = newSetting.event_difficulty
  setting.live_difficulty_id = newSetting.live_difficulty_id
  setting.filter_reset_possibility = newSetting.filter_reset_possibility
  LiveMenu.Setting.set(setting)
  LiveList.tryUpdateSeries(newSetting.member_category)

end

LiveMenu.Model.LiveList = LiveList
