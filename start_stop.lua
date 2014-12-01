local curFile = 'start_stop.lua';

-- starts driving the course
function courseplay:start(self)
	self.maxnumber = #(self.Waypoints)
	if self.maxnumber < 1 then
		return
	end
	courseplay:setEngineState(self, true);
	--print(tableShow(self.attachedImplements[1].object,tableShow(self.attachedImplements[1].object.name,nil,nil,2)))
	--local id = self.attachedImplements[1].object.unloadTrigger.triggerId
	--courseplay:findInTables(g_currentMission ,"g_currentMission", id)

	
	if self.cp.orgRpm == nil then
		self.cp.orgRpm = {}
		self.cp.orgRpm[1] = self.motor.maxRpm
		self.cp.orgRpm[2] = self.motor.maxRpm
		self.cp.orgRpm[3] = self.motor.maxRpm
	end
	--[[if self.ESLimiter ~= nil and self.ESLimiter.maxRPM[5] ~= nil then
		self.cp.ESL = {}
		self.cp.ESL[1] = self.ESLimiter.percentage[2]
		self.cp.ESL[2] = self.ESLimiter.percentage[3]
		self.cp.ESL[3] = self.ESLimiter.percentage[4]
	end;
	if self.isRealistic then
		self.cp.mrOrigSpeed = {
			[1] = self.motor.realSpeedLevelsAI[1],
			[2] = self.motor.realSpeedLevelsAI[2],
			[3] = self.motor.realSpeedLevelsAI[3]
		};
	end;]]

	self.CPnumCollidingVehicles = 0;
	self.cp.collidingVehicleId = nil
	courseplay:debug(string.format("%s: Start/Stop: deleting \"self.cp.collidingVehicleId\"", nameNum(self)), 3);
	--self.numToolsCollidingVehicles = {};
	self:setIsCourseplayDriving(false);
	courseplay:setIsRecording(self, false);
	courseplay:setRecordingIsPaused(self, false);
	self.cp.calculatedCourseToCombine = false

	AITractor.addCollisionTrigger(self, self);
		
	if self.attachedCutters ~= nil then
		for cutter, implement in pairs(self.attachedCutters) do
			--remove cutter atTrafficCollisionTrigger in case of having changed or removed it while not in CP
			if self.cp.trafficCollisionTriggers[0] ~= nil then
				removeTrigger(self.cp.trafficCollisionTriggers[0])
				self.cp.trafficCollisionTriggerToTriggerIndex[self.cp.trafficCollisionTriggers[0]] = nil
			end	
			--set cutter aiTrafficCollisionTrigger to cp.aiTrafficCollisionTrigger's list
			if cutter.aiTrafficCollisionTrigger ~= nil then
				if cutter.cpTrafficCollisionTrigger == nil then
					cutter.cpTrafficCollisionTrigger = clone(cutter.aiTrafficCollisionTrigger, true);
					self.cp.trafficCollisionTriggers[0] = cutter.cpTrafficCollisionTrigger
				else
					self.cp.trafficCollisionTriggers[0] = cutter.cpTrafficCollisionTrigger
				end
				addTrigger(self.cp.trafficCollisionTriggers[0], 'cpOnTrafficCollisionTrigger', self);
				self.cp.trafficCollisionTriggerToTriggerIndex[self.cp.trafficCollisionTriggers[0]] = 0
				self.cp.collidingObjects[0] = {};
				courseplay:debug(string.format("%s: Start/Stop: cutter.aiTrafficCollisionTrigger present -> adding %s to self.cp.trafficCollisionTriggers[0]",nameNum(self),tostring(self.cp.trafficCollisionTriggers[0])),3)
				--self.cp.numCollidingObjects[0] = 0;
			else
				courseplay:debug(string.format('## Courseplay: %s: aiTrafficCollisionTrigger in cutter missing. Traffic collision prevention will not work!', nameNum(self)),3);
			end
		end
	end
	
	-- adapt collis height to vehicles height , its a runonce
	if self.cp.ColliHeightSet == nil then
		local height = 0;
		local step = self.sizeLength/2;
		local distance = self.sizeLength;
		local nx, ny, nz = localDirectionToWorld(self.rootNode, 0, -1, 0);	
		self.cp.HeightsFound = 0;
		self.cp.HeightsFoundColli = 0;			
		for i=-step,step,0.5 do				
			local x,y,z = localToWorld(self.rootNode, 0, distance, i);
			raycastAll(x, y, z, nx, ny, nz, "findVehicleHeights", distance, self);
			--print("drive raycast "..tostring(i).." end");
			--drawDebugLine(x, y, z, 1, 0, 0, x+(nx*distance), y+(ny*distance), z+(nz*distance), 1, 0, 0);
		end
		local difference = self.cp.HeightsFound - self.cp.HeightsFoundColli;
		local trigger = self.cp.trafficCollisionTriggers[1];
		local Tx,Ty,Tz = getTranslation(trigger,self.rootNode);
		setTranslation(trigger, Tx,Ty+difference,Tz);
		self.cp.ColliHeightSet = true;
	end
	
	--calculate workwidth for combines in mode7
	if self.cp.mode == 7 then
		courseplay:calculateWorkWidth(self)
	end
	-- set default modeState if not in mode 2 or 3
	if self.cp.mode ~= 2 and self.cp.mode ~= 3 then
		courseplay:setModeState(self, 0);
	end;

	if self.recordnumber < 1 then
		courseplay:setRecordNumber(self, 1);
	end

	-- add do working players if not already added
	if self.cp.coursePlayerNum == nil then
		self.cp.coursePlayerNum = courseplay:addToTotalCoursePlayers(self)
	end;
	--add to activeCoursePlayers
	courseplay:addToActiveCoursePlayers(self);

	self.cp.backMarkerOffset = nil
	self.cp.aiFrontMarker = nil

	courseplay:reset_tools(self)
	-- show arrow
	self.cp.distanceCheck = true
	-- current position
	local ctx, cty, ctz = getWorldTranslation(self.cp.DirectionNode);
	-- position of next waypoint
	local cx, cz = self.Waypoints[self.recordnumber].cx, self.Waypoints[self.recordnumber].cz
	-- distance
	local dist = courseplay:distance(ctx, ctz, cx, cz)
	

	local setLaneNumber = false;
	for k,workTool in pairs(self.cp.workTools) do    --TODO temporary solution (better would be Tool:getIsAnimationPlaying(animationName))
		if courseplay:isFolding(workTool) then
			if  self.setAIImplementsMoveDown ~= nil then
				self:setAIImplementsMoveDown(true)
			elseif self.setFoldState ~= nil then
				self:setFoldState(-1, true)
			end
		end;

		--DrivingLine spec: set lane numbers
		if self.cp.mode == 4 and not setLaneNumber and workTool.cp.hasSpecializationDrivingLine and not workTool.manualDrivingLine then
			setLaneNumber = true;
		end;
	end;


	local numWaitPoints = 0
	local numCrossingPoints = 0
	self.cp.waitPoints = {};
	self.cp.shovelFillStartPoint = nil
	self.cp.shovelFillEndPoint = nil
	self.cp.shovelEmptyPoint = nil
	local nearestpoint = dist
	local recordNumber = 0
	local curLaneNumber = 1;
	local hasReversing = false;
	local lookForNearestWaypoint = self.cp.startAtPoint == courseplay.START_AT_NEAREST_POINT and (self.cp.modeState == 0 or self.cp.modeState == 99); --or self.cp.modeState == 1
	for i,wp in pairs(self.Waypoints) do
		local cx, cz = wp.cx, wp.cz;
		if lookForNearestWaypoint then
			dist = courseplay:distance(ctx, ctz, cx, cz)
			if dist <= nearestpoint then
				nearestpoint = dist
				recordNumber = i
			end;
		end;

		if wp.wait then
			numWaitPoints = numWaitPoints + 1;
			self.cp.waitPoints[numWaitPoints] = i;
		end;
		if wp.crossing then
			numCrossingPoints = numCrossingPoints + 1;
			self.cp.crossingPoints[numCrossingPoints] = i;
		end;

		-- has reversing part
		if self.cp.mode ~= 9 and wp.rev then
			hasReversing = true;
		end;

		-- specific Workzone
		if self.cp.mode == 4 or self.cp.mode == 6 or self.cp.mode == 7 then
			if numWaitPoints == 1 and (self.cp.startWork == nil or self.cp.startWork == 0) then
				self.cp.startWork = i
			end
			if numWaitPoints > 1 and (self.cp.stopWork == nil or self.cp.stopWork == 0) then
				self.cp.stopWork = i
			end

		--unloading point for transporter
		elseif self.cp.mode == 8 then
			--

		--work points for shovel
		elseif self.cp.mode == 9 then
			if numWaitPoints == 1 and self.cp.shovelFillStartPoint == nil then
				self.cp.shovelFillStartPoint = i;
			end;
			if numWaitPoints == 2 and self.cp.shovelFillEndPoint == nil then
				self.cp.shovelFillEndPoint = i;
			end;
			if numWaitPoints == 3 and self.cp.shovelEmptyPoint == nil then
				self.cp.shovelEmptyPoint = i;
			end;
		end;

		-- laneNumber (for seeders)
		if setLaneNumber and wp.generated ~= nil and wp.generated == true then
			if wp.turnEnd ~= nil and wp.turnEnd == true then
				curLaneNumber = curLaneNumber + 1;
				courseplay:debug(string.format('%s: waypoint %d: turnEnd=true -> new curLaneNumber=%d', nameNum(self), i, curLaneNumber), 12);
			end;
			wp.laneNum = curLaneNumber;
		end;
	end;


	-- modes 4/6 without start and stop point, set them at start and end, for only-on-field-courses
	if (self.cp.mode == 4 or self.cp.mode == 6) then
		if numWaitPoints == 0 or self.cp.startWork == nil then
			self.cp.startWork = 1;
		end;
		if numWaitPoints == 0 or self.cp.stopWork == nil then
			self.cp.stopWork = self.maxnumber;
		end;
	end;
	self.cp.numWaitPoints = numWaitPoints;
	self.cp.numCrossingPoints = numCrossingPoints;
	courseplay:debug(string.format("%s: numWaitPoints=%d, waitPoints[1]=%s, numCrossingPoints=%d", nameNum(self), self.cp.numWaitPoints, tostring(self.cp.waitPoints[1]), numCrossingPoints), 12);

	-- set waitTime to 0 if necessary
	if not courseplay:getCanHaveWaitTime(self) and self.cp.waitTime > 0 then
		courseplay:changeWaitTime(self, -self.cp.waitTime);
	end;


	if lookForNearestWaypoint then
		local changed = false
		for i=recordNumber,recordNumber+3 do
			if self.Waypoints[i]~= nil and self.Waypoints[i].turn ~= nil then
				courseplay:setRecordNumber(self, i + 2);
				changed = true
				break
			end	
		end
		if changed == false then
			courseplay:setRecordNumber(self, recordNumber);
		end

		if self.recordnumber > self.maxnumber then
			courseplay:setRecordNumber(self, 1);
		end
	end --END if modeState == 0

	if self.recordnumber > 2 and self.cp.mode ~= 4 and self.cp.mode ~= 6 then
		courseplay:setIsLoaded(self, true);
	elseif self.cp.mode == 4 or self.cp.mode == 6 then
		courseplay:setIsLoaded(self, false);
		self.cp.hasUnloadingRefillingCourse = self.maxnumber > self.cp.stopWork + 7;
		if  self.Waypoints[self.cp.stopWork].cx == self.Waypoints[self.cp.startWork].cx 
		and self.Waypoints[self.cp.stopWork].cz == self.Waypoints[self.cp.startWork].cz then -- TODO: VERY unsafe, there could be LUA float problems (e.g. 7 + 8 = 15.000000001)
			self.cp.finishWork = self.cp.stopWork-5
		else
			self.cp.finishWork = self.cp.stopWork
		end

		if self.cp.startAtPoint == courseplay.START_AT_NEAREST_POINT and self.cp.finishWork ~= self.cp.stopWork and self.recordnumber > self.cp.finishWork and self.recordnumber <= self.cp.stopWork then
			courseplay:setRecordNumber(self, 2);
		end
		courseplay:debug(string.format("%s: maxnumber=%d, stopWork=%d, finishWork=%d, hasUnloadingRefillingCourse=%s, recordnumber=%d", nameNum(self), self.maxnumber, self.cp.stopWork, self.cp.finishWork, tostring(self.cp.hasUnloadingRefillingCourse), self.recordnumber), 12);
	end

	if self.cp.mode == 9 or self.cp.startAtPoint == courseplay.START_AT_FIRST_POINT then
		courseplay:setRecordNumber(self, 1);
		self.cp.shovelState = 1;
		for i,_ in pairs(self.attachedImplements) do
			local object = self.attachedImplements[i].object
			if object.ignoreVehicleDirectionOnLoad ~= nil then
				object.ignoreVehicleDirectionOnLoad = true
			end	
			if object.attachedImplements ~= nil then
				for k,_ in pairs(object.attachedImplements) do
					if object.attachedImplements[k].object.ignoreVehicleDirectionOnLoad ~= nil then
						object.attachedImplements[k].object.ignoreVehicleDirectionOnLoad = true
					end
				end
			end				
		end	
	end;

	courseplay:updateAllTriggers();

	self.cp.forceIsActiveBackup = self.forceIsActive;
	self.forceIsActive = true;
	self.cp.stopMotorOnLeaveBackup = self.stopMotorOnLeave;
	self.stopMotorOnLeave = false;
	self.cp.deactivateOnLeaveBackup = deactivateOnLeave;
	self.deactivateOnLeave = false;

	if self.cp.hasDriveControl then
		local changed = false;
		if self.cp.driveControl.hasFourWD then
			self.cp.driveControl.fourWDBackup = self.driveControl.fourWDandDifferentials.fourWheel;
		end;
		if self.cp.driveControl.hasHandbrake then
			if self.driveControl.handBrake.isActive == true then
				self.driveControl.handBrake.isActive = false;
				changed = true;
			end;
		end;
		if self.cp.driveControl.hasShuttleMode and self.driveControl.shuttle.isActive then
			if self.driveControl.shuttle.direction < 1.0 then
				self.driveControl.shuttle.direction = 1.0;
				changed = true;
			end;
		end;

		if changed and driveControlInputEvent ~= nil then
			driveControlInputEvent.sendEvent(self);
		end;
	end;

	self.steeringEnabled = false;
	self.disableCharacterOnLeave = false

	-- ok i am near the waypoint, let's go
	self.checkSpeedLimit = false
	self.cp.runOnceStartCourse = true;
	self:setIsCourseplayDriving(true);
	courseplay:setIsRecording(self, false);
	self.cp.distanceCheck = false;

	self.cp.totalLength, self.cp.totalLengthOffset = courseplay:getTotalLengthOnWheels(self);

	courseplay:validateCanSwitchMode(self);
	--print("startStop "..debug.getinfo(1).currentline)
end;

function courseplay:getCanUseAiMode(vehicle)
	if not vehicle.isMotorStarted or (vehicle.motorStartTime and vehicle.motorStartTime > g_currentMission.time) then
		return false;
	end;

	local mode = vehicle.cp.mode;

	if mode ~= 5 and mode ~= 6 and mode ~= 7 and not vehicle.cp.workToolAttached then
		courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_WRONG_TRAILER'));
		return false;
	end;

	local minWait, maxWait;

	if mode == 3 or mode == 7 or mode == 8 then
		minWait, maxWait = 1, 1;
		if vehicle.cp.numWaitPoints < minWait then
			courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_WAITING_POINTS_TOO_FEW'):format(minWait));
			return false;
		elseif vehicle.cp.numWaitPoints > maxWait then
			courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_WAITING_POINTS_TOO_MANY'):format(maxWait));
			return false;
		end;
		if mode == 3 then
			if vehicle.cp.workTools[1] == nil or vehicle.cp.workTools[1].cp == nil or not vehicle.cp.workTools[1].cp.isAugerWagon then
				courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_WRONG_TRAILER'));
				return false;
			end;
		elseif mode == 7 then
			if vehicle.isAutoCombineActivated ~= nil and vehicle.isAutoCombineActivated then
				courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_NO_AUTOCOMBINE_MODE_7'));
				return false;
			end;
		elseif mode == 8 then
			if vehicle.cp.workTools[1] == nil then
				courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_WRONG_TRAILER'));
				return false;
			end;
		end;

	elseif mode == 4 or mode == 6 then
		if vehicle.cp.startWork == nil or vehicle.cp.stopWork == nil then
			courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_NO_WORK_AREA'));
			return false;
		end;
		if mode == 6 then
			if vehicle.cp.hasBaleLoader then
				minWait, maxWait = 2, 3;
				if vehicle.cp.numWaitPoints < minWait then
					courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_WAITING_POINTS_TOO_FEW'):format(minWait));
					return false;
				elseif vehicle.cp.numWaitPoints > maxWait then
					courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_WAITING_POINTS_TOO_MANY'):format(maxWait));
					return false;
				end;
			end;
		end;

	elseif mode == 9 then
		minWait, maxWait = 3, 3;
		if vehicle.cp.numWaitPoints < minWait then
			courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_WAITING_POINTS_TOO_FEW'):format(minWait));
			return false;
		elseif vehicle.cp.numWaitPoints > maxWait then
			courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_WAITING_POINTS_TOO_MANY'):format(maxWait));
			return false;
		elseif vehicle.cp.shovelStatePositions == nil or vehicle.cp.shovelStatePositions[2] == nil or vehicle.cp.shovelStatePositions[3] == nil or vehicle.cp.shovelStatePositions[4] == nil or vehicle.cp.shovelStatePositions[5] == nil then
			courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_SHOVEL_POSITIONS_MISSING'));
			return false;
		elseif vehicle.cp.shovelFillStartPoint == nil or vehicle.cp.shovelFillEndPoint == nil or vehicle.cp.shovelEmptyPoint == nil then
			courseplay:setInfoText(vehicle, courseplay:loc('COURSEPLAY_NO_VALID_COURSE'));
			return false;
		end;
	end;

	return true;
end;

-- stops driving the course
function courseplay:stop(self)
	self.forceIsActive = self.cp.forceIsActiveBackup;
	self.stopMotorOnLeave = self.cp.stopMotorOnLeaveBackup;
	self.deactivateOnLeave = self.cp.deactivateOnLeaveBackup;

	if self.cp.hasDriveControl then
		local changed = false;
		if self.cp.driveControl.hasFourWD and self.driveControl.fourWDandDifferentials.fourWheel ~= self.cp.driveControl.fourWDBackup then
			self.driveControl.fourWDandDifferentials.fourWheel = self.cp.driveControl.fourWDBackup;
			self.driveControl.fourWDandDifferentials.diffLockFront = false;
			self.driveControl.fourWDandDifferentials.diffLockBack = false;
			changed = true;
		end;

		if changed and driveControlInputEvent ~= nil then
			driveControlInputEvent.sendEvent(self);
		end;
	end;

	self.steeringEnabled = true;
	self.disableCharacterOnLeave = true
	self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
	self.cruiseControl.minSpeed = 1
	self.cp.forcedToStop = false
	self.cp.waitingForTrailerToUnload = false
	courseplay:setIsRecording(self, false);
	courseplay:setRecordingIsPaused(self, false);
	if self.cp.modeState > 4 then
		courseplay:setModeState(self, 1);
	end
	self.cp.turnStage = 0
	self.cp.isTurning = nil
	self.aiTractorTargetX = nil
	self.aiTractorTargetZ = nil
	self.aiTractorTargetBeforeTurnX = nil
	self.aiTractorTargetBeforeTurnZ = nil
	self.cp.backMarkerOffset = nil
	self.cp.aiFrontMarker = nil
	self.cp.aiTurnNoBackward = false
	self.cp.noStopOnEdge = false
	if self.isRealistic then
		self.motor.speedLevel = 0 
		self:realSetAwdActive(self.cp.realAWDModeOnBackup)
		if self.realForceAiDriven then
			self.realForceAiDriven = false
		end
	end
	self.cp.fillTrigger = nil;
	self.cp.hasMachineToFill = false;
	self.cp.unloadOrder = false
	AITractor.removeCollisionTrigger(self, self);
	self.cpTrafficCollisionIgnoreList = {}
	self.cp.foundColli = {}
	self.cp.inTraffic = false
	self.cp.bypassWaypointsSet = false
	--deactivate beacon lights
	if self.beaconLightsActive then
		self:setBeaconLightsVisibility(false);
	end;

	--open all covers
	if self.cp.workToolAttached and self.cp.tipperHasCover and self.cp.mode == 1 or self.cp.mode == 2 or self.cp.mode == 5 or self.cp.mode == 6 then
		courseplay:openCloseCover(self, nil, false);
	end;

	-- resetting variables
	courseplay:setMinHudPage(self, nil);
	self.cp.attachedCombineIdx = nil;
	self.cp.tempCollis = {}
	self.checkSpeedLimit = true
	courseplay:resetTipTrigger(self);
	self:setIsCourseplayDriving(false);
	self.cp.canDrive = true
	self.cp.distanceCheck = false
	self.cp.mode7GoBackBeforeUnloading = false
	if self.cp.checkReverseValdityPrinted then
		self.cp.checkReverseValdityPrinted = false

	end
	self.cp.lastMode8UnloadTriggerId = nil

	self.cp.curSpeed = 0;

	self.motor.maxRpmOverride = nil;
	self.cp.startWork = nil
	self.cp.stopWork = nil
	self.cp.hasUnloadingRefillingCourse = false;
	courseplay:setStopAtEnd(self, false);
	self.cp.isUnloaded = false;
	self.cp.prevFillLevelPct = nil;
	self.cp.isInRepairTrigger = nil;
	self.cp.curMapWeightStation = nil;

	courseplay:setSlippingStage(self, 0);
	courseplay:resetCustomTimer(self, 'slippingStage1');
	courseplay:resetCustomTimer(self, 'slippingStage2');

	self.cp.hasBaleLoader = false;
	self.cp.hasPlough = false;
	self.cp.hasSowingMachine = false;
	self.cp.hasSprayer = false;
	if self.cp.tempToolOffsetX ~= nil then
		courseplay:changeToolOffsetX(self, nil, self.cp.tempToolOffsetX, true);
		self.cp.tempToolOffsetX = nil
	end;
	self.cp.totalLength, self.cp.totalLengthOffset = 0, 0;
	self.cp.numWorkTools = 0;

	self.cp.timers.slippingWheels = 0;

	self.cp.movingToolsPrimary, self.cp.movingToolsSecondary = nil, nil;
	self.cp.attachedFrontLoader = nil
	
	--remove any local and global info texts
	if g_server ~= nil then
		courseplay:setInfoText(self, nil);

		for refIdx,_ in pairs(courseplay.globalInfoText.msgReference) do
			if self.cp.activeGlobalInfoTexts[refIdx] ~= nil then
				courseplay:setGlobalInfoText(self, refIdx, true);
			end;
		end;
	end

	--remove from activeCoursePlayers
	courseplay:removeFromActiveCoursePlayers(self);

	--validation: can switch mode?
	courseplay:validateCanSwitchMode(self);
end


function courseplay:findVehicleHeights(transformId, x, y, z, distance)
		local height = self.sizeLength - distance
		local vehicle = false
		if self.cp.trafficCollisionTriggerToTriggerIndex[transformId] ~= nil then
			if self.cp.HeightsFoundColli < height then
				self.cp.HeightsFoundColli = height
			end	
		elseif transformId == self.rootNode then
			vehicle = true
		elseif getParent(transformId) == self.rootNode and self.aiTrafficCollisionTrigger ~= transformId then
			vehicle = true
		end
		if vehicle and self.cp.HeightsFound < height then
			self.cp.HeightsFound = height
		end	
		
		return true
end