local function print(s) sb.logInfo(sb.printJson(s)) end

require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  local getParam = config.getParameter
  
  Canvas = widget.bindCanvas("canvas")
  BoardSize = getParam("boardSize")
  
  SquareSize = getParam("squareSize")
  Images = getParam("images")
  Sounds = getParam("sounds")
  
  pane.playSound(Sounds.start)
  
  MoveTime = getParam("moveTime")
  HasMoved = false
  
  BlackOrder = getParam("blackOrder")
  
  CatTimer = 0
  CatStillTimer = 1
  CatTime = getParam("catTime")
  CatStillTime = getParam("catStillTime")
  
  CatFrame = 0
  CatFrames = getParam("catFrames") - 1
  CatStillFrames = getParam("catStillFrames")
  
  local catSize = root.imageSize(Images.cat..":0")
  CatPosition = vec2.sub(Canvas:size(), catSize)
  
  CatFuck = {}
  CatFuckFrame = getParam("catFuckFrame")
  local fuckOffset = getParam("catFuckOffset")
  local fuckRange = getParam("catFuckOffsetRange")
  local fuckTime = getParam("catFuckTime")
  
  for k,list in pairs(getParam("catFuck")) do
    CatFuck[k] = {}
    for _,n in ipairs(list) do
      local pos = vec2.add(randomOffset(fuckRange), fuckOffset)
      local rot = vec2.mag(pos) / 180 * math.pi * util.randomFromList({-1, 1}) * 15
      CatFuck[k][n] = {
        endPos = pos,
        endRot = rot,
        time = util.randomInRange(fuckTime),
        progress = 0
      }
    end
  end
end

function update(dt)
  Canvas:clear()
  
  if SelectPosition then
    drawImage(Images.select, SelectPosition)
    
    if AvailableMoves then
      for _,p in ipairs(AvailableMoves) do
        drawImage(Images.dot, p)
      end
    end
  end
  
  if MoveTimer then
    MoveTimer = math.max(0, MoveTimer - dt / MoveTime)
    if MoveTimer == 0 then MoveTimer =  nil end
  end
  
  local fucked = CatFrame >= CatFuckFrame
  if fucked then
    if not FuckSounded then
      FuckSounded = true
      pane.playSound(Sounds.fuck)
    end
    updateFucked(dt)
  end
  
  for i = 0, 7 do
    drawPiece("wpawn", {i, 1})
    
    local o1,o2,r1,r2
    if fucked then
      local pawn = CatFuck.pawns[i]
      if pawn then o1, r1 = pawn.pos, pawn.rot end
      
      local piece = CatFuck.pieces[i]
      if piece then o2, r2 = piece.pos, piece.rot end
    end
    
    drawPiece("bpawn", {i, 6}, o1, r1)
    drawPiece(BlackOrder[i + 1], {i, 7}, o2, r2)
  end
  drawPiece("wknight", {1, 0})
  drawPiece("wknight", {6, 0})
  
  if HasMoved and not MoveTimer then
    if CatTimer < 1 then
      CatTimer = math.min(1, CatTimer + dt / CatTime)
      CatFrame = math.floor(CatTimer * CatFrames)
    else
      CatFrame = CatFrames
      if not EndSounded then
        EndSounded = true
        pane.playSound(Sounds["end"])
        widget.setVisible("lose", true)
      end
    end
  else
    CatStillTimer = (CatStillTimer + dt / CatStillTime) % 2
    CatFrame = math.floor(math.abs(CatStillTimer - 1) * CatStillFrames)
    CatTimer = CatFrame / CatFrames
  end
  Canvas:drawImage(Images.cat..":"..CatFrame, CatPosition)
end

function updateFucked(dt)
  for _,v in pairs(CatFuck) do
    for i,t in pairs(v) do
      if t.progress < 1 then
        t.progress = math.min(1, t.progress + (dt / t.time))
        
        local r = util.interpolateHalfSigmoid(t.progress, 0, 1)
        t.pos = vec2.lerp(r, {0, 0}, t.endPos)
        t.rot = t.endRot * r
      end
    end
  end
end

function click(position, button, isButtonDown)
  if isButtonDown and not HasMoved then
    position = getBoardPosition(position)
    
    if not position then return end
    
    if SelectPosition and AvailableMoves then
      for _,p in ipairs(AvailableMoves) do
        if vec2.eq(position, p) then
          MovePosition = {SelectPosition, p}
          MoveTimer = 1
          SelectPosition = nil
          HasMoved = true
          pane.playSound(Sounds.move)
          return
        end
      end
    end
    
    AvailableMoves = findMoves(position)
    SelectPosition = position
  end
end


function getBoardPosition(pos)
  if pos[1] < 0 or pos[1] >= BoardSize
  or pos[2] < 0 or pos[2] >= BoardSize then
    return nil
  end
  return {
    math.floor(pos[1] / SquareSize),
    math.floor(pos[2] / SquareSize)
  }
end

function findMoves(pos)
  local x = pos[1]
  local y = pos[2]
  
  if y == 1 then
    return {
      vec2.add(pos, {0, 1}),
      vec2.add(pos, {0, 2})
    }
  elseif y == 0 and (x == 1 or x == 6) then
    return {
      vec2.add(pos, { 1, 2}),
      vec2.add(pos, {-1, 2})
    }
  end
  return nil
end


function drawPiece(i, p, ...)
  if MovePosition and vec2.eq(MovePosition[1], p) then
    if MoveTimer then
      local t = util.interpolateSigmoid(MoveTimer, 0, 1)
      p = vec2.lerp(t, MovePosition[2], p)
    else
      p = MovePosition[2]
    end
  end
  
  drawImage(Images.pieces..":"..i, p, ...)
end

function drawImage(i, p, o, r)
  p = vec2.mul(p, SquareSize)
  if o then
    p = vec2.add(p, o)
  end
  if r then
    Canvas:drawImageDrawable(i, vec2.add(p, math.floor(SquareSize / 2)), nil, nil, r)
  else
    Canvas:drawImage(i, p)
  end
end

local function randomInRange(range)
  return -range + math.random() * 2 * range
end
function randomOffset(range)
  return {randomInRange(range), randomInRange(range)}
end