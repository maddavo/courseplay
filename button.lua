-- #################################################################
-- courseplay.button class

courseplay.button = {};
cpButton_mt = Class(courseplay.button);

function courseplay.button:new(vehicle, hudPage, img, functionToCall, parameter, x, y, width, height, hudRow, modifiedParameter, hoverText, isMouseWheelArea, isToggleButton, toolTip)
	local self = setmetatable({}, cpButton_mt);

	if img then
		if type(img) == 'table' then
			if img[1] == 'iconSprite.png' then
				self.overlay = Overlay:new(img, courseplay.hud.iconSpritePath, x, y, width, height);
				self.spriteSection = img[2];
			end;
		else
			self.overlay = Overlay:new(img, Utils.getFilename('img/' .. img, courseplay.path), x, y, width, height);
		end;
	end;

	if hoverText == nil then
		hoverText = false;
	end;
	if isMouseWheelArea == nil then
		isMouseWheelArea = false;
	end;
	if isToggleButton == nil then
		isToggleButton = false;
	end;

	self.vehicle = vehicle;
	self.page = hudPage; 
	self.functionToCall = functionToCall; 
	self:setParameter(parameter);
	self.width = width;
	self.height = height;
	self.x_init = x;
	self.x = x;
	self.x2 = (x + width);
	self.y_init = y;
	self.y = y;
	self.y2 = (y + height);
	self.row = hudRow;
	self.hoverText = hoverText;
	self:setColor('white')
	self:setToolTip(toolTip);
	self.isMouseWheelArea = isMouseWheelArea and functionToCall ~= nil;
	self.isToggleButton = isToggleButton;
	self:setCanBeClicked(not isMouseWheelArea and functionToCall ~= nil);
	self:setShow(true);
	self:setClicked(false);
	self:setActive(false);
	self:setDisabled(false);
	self:setHovered(false);
	self:setHidden(false);
	if modifiedParameter then 
		self.modifiedParameter = modifiedParameter;
	end
	if isMouseWheelArea then
		self.canScrollUp   = true;
		self.canScrollDown = true;
	end;

	if self.spriteSection then
		self:setSpriteSectionUVs(self.spriteSection);
	else
		self:setSpecialButtonUVs();
	end;

	if vehicle.isCourseplayManager then
		table.insert(vehicle.buttons[hudPage], self);
	else
		table.insert(vehicle.cp.buttons[hudPage], self);
	end;
	return self;
end;

function courseplay.button:setSpriteSectionUVs(spriteSection)
	if not spriteSection or courseplay.hud.buttonUVsPx[spriteSection] == nil then return; end;

	self.spriteSection = spriteSection;
	courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.buttonUVsPx[spriteSection], courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y);
end;

function courseplay.button:setSpecialButtonUVs()
	if not self.overlay then return; end;

	local fn = self.functionToCall;
	local prm = self.parameter;
	local txtSizeX, txtSizeY = courseplay.hud.iconSpriteSize.x, courseplay.hud.iconSpriteSize.y;

	if fn == 'setCpMode' then
		courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.modeButtonsUVsPx[prm], txtSizeX, txtSizeY);

	elseif fn == 'setHudPage' then
		courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.pageButtonsUVsPx[prm], txtSizeX, txtSizeY);

	elseif fn == 'generateCourse' then
		courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.pageButtonsUVsPx[8], txtSizeX, txtSizeY);

	elseif fn == 'toggleDebugChannel' then
		self:setSpriteSectionUVs('recordingStop');

	-- courseplay_manager buttons
	elseif fn == 'goToVehicle' then
		courseplay.utils:setOverlayUVsPx(self.overlay, courseplay.hud.pageButtonsUVsPx[7], txtSizeX, txtSizeY);
	end;
end;

function courseplay.button:render()
	-- self = courseplay.button

	local vehicle, pg, fn, prm = self.vehicle, self.page, self.functionToCall, self.parameter;
	local hoveredButton = false;

	--mouseWheelAreas conditionals
	if self.isMouseWheelArea then
		local canScrollUp, canScrollDown;
		if pg == 1 then
			if fn == "setCustomFieldEdgePathNumber" then
				canScrollUp   = vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum < courseplay.fields.customFieldMaxNum;
				canScrollDown = vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum > 0;
			end;

		elseif pg == 2 then
			if fn == "shiftHudCourses" then
				canScrollUp   = vehicle.cp.hud.courseListPrev == true;
				canScrollDown = vehicle.cp.hud.courseListNext == true;
			end;

		elseif pg == 3 then
			if fn == "changeTurnRadius" then
				canScrollUp   = true;
				canScrollDown = vehicle.cp.turnRadius > 0;
			elseif fn == "changeFollowAtFillLevel" then
				canScrollUp   = vehicle.cp.followAtFillLevel < 100;
				canScrollDown = vehicle.cp.followAtFillLevel > 0;
			elseif fn == "changeDriveOnAtFillLevel" then
				canScrollUp   = vehicle.cp.driveOnAtFillLevel < 100;
				canScrollDown = vehicle.cp.driveOnAtFillLevel > 0;
			elseif fn == 'changeRefillUntilPct' then
				canScrollUp   = (vehicle.cp.mode == 4 or vehicle.cp.mode == 8) and vehicle.cp.refillUntilPct < 100;
				canScrollDown = (vehicle.cp.mode == 4 or vehicle.cp.mode == 8) and vehicle.cp.refillUntilPct > 1;
			end;

		elseif pg == 4 then
			if fn == 'setSearchCombineOnField' then
				canScrollUp   = courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineAutomatically and vehicle.cp.searchCombineOnField > 0;
				canScrollDown = courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineAutomatically and vehicle.cp.searchCombineOnField < courseplay.fields.numAvailableFields;
			end;

		elseif pg == 5 then
			if fn == 'changeTurnSpeed' then
				canScrollUp   = vehicle.cp.speeds.turn < vehicle.cp.speeds.max;
				canScrollDown = vehicle.cp.speeds.turn > vehicle.cp.speeds.minTurn;
			elseif fn == 'changeFieldSpeed' then
				canScrollUp   = vehicle.cp.speeds.field < vehicle.cp.speeds.max;
				canScrollDown = vehicle.cp.speeds.field > vehicle.cp.speeds.minField;
			elseif fn == 'changeMaxSpeed' then
				canScrollUp   = vehicle.cp.speeds.useRecordingSpeed == false and vehicle.cp.speeds.street < vehicle.cp.speeds.max;
				canScrollDown = vehicle.cp.speeds.useRecordingSpeed == false and vehicle.cp.speeds.street > vehicle.cp.speeds.minStreet;
			elseif fn == 'changeUnloadSpeed' then
				canScrollUp   = vehicle.cp.speeds.unload < vehicle.cp.speeds.max;
				canScrollDown = vehicle.cp.speeds.unload > vehicle.cp.speeds.minUnload;
			end;

		elseif pg == 6 then
			if fn == "changeWaitTime" then
				canScrollUp   = courseplay:getCanHaveWaitTime(vehicle);
				canScrollDown = canScrollUp and vehicle.cp.waitTime > 0;
			elseif fn == 'changeDebugChannelSection' then
				canScrollUp   = courseplay.debugChannelSection > 1;
				canScrollDown = courseplay.debugChannelSection < courseplay.numDebugChannelSections;
			end;

		elseif pg == 7 then
			if fn == "changeLaneOffset" then
				canScrollUp   = vehicle.cp.mode == 4 or vehicle.cp.mode == 6;
				canScrollDown = canScrollUp;
			elseif fn == "changeToolOffsetX" or fn == "changeToolOffsetZ" then
				canScrollUp   = vehicle.cp.mode == 3 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6 or vehicle.cp.mode == 7 or vehicle.cp.mode == 8;
				canScrollDown = canScrollUp;
			end;

		elseif pg == 8 then
			if fn == "setFieldEdgePath" then
				canScrollUp   = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum < courseplay.fields.numAvailableFields;
				canScrollDown = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
			elseif fn == "changeWorkWidth" then
				canScrollUp   = true;
				canScrollDown = vehicle.cp.workWidth > 0.1;
			end;
		end;

		if canScrollUp ~= nil then
			self:setCanScrollUp(canScrollUp);
		end;
		if canScrollDown ~= nil then
			self:setCanScrollDown(canScrollDown);
		end;

	elseif self.overlay ~= nil then
		local show = true;

		--CONDITIONAL DISPLAY
		--Global
		if pg == "global" then
			if fn == "showSaveCourseForm" and prm == "course" then
				show = vehicle.cp.canDrive and not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused and vehicle.Waypoints ~= nil and #(vehicle.Waypoints) ~= 0;
			end;

		--Page 1
		elseif pg == 1 then
			if fn == "setCpMode" then
				show = vehicle.cp.canSwitchMode and not vehicle.cp.distanceCheck;
			elseif fn == "clearCustomFieldEdge" or fn == "toggleCustomFieldEdgePathShow" then
				show = not vehicle.cp.canDrive and vehicle.cp.fieldEdge.customField.isCreated;
			elseif fn == "setCustomFieldEdgePathNumber" then
				if prm < 0 then
					show = not vehicle.cp.canDrive and vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum > 0;
				elseif prm > 0 then
					show = not vehicle.cp.canDrive and vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum < courseplay.fields.customFieldMaxNum;
				end;
			elseif fn == 'toggleFindFirstWaypoint' then
				show = vehicle.cp.canDrive and not vehicle:getIsCourseplayDriving() and not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused;
			elseif fn == 'stop_record' or fn == 'setRecordingPause' or fn == 'delete_waypoint' or fn == 'set_waitpoint' or fn == 'set_crossing' or fn == 'setRecordingTurnManeuver' or fn == 'change_DriveDirection' then
				show = vehicle.cp.isRecording or vehicle.cp.recordingIsPaused;
			end;

		--Page 2
		elseif pg == 2 then
			if fn == "reloadCoursesFromXML" then
				show = g_server ~= nil;
			elseif fn == "showSaveCourseForm" and prm == "filter" then
				show = not vehicle.cp.hud.choose_parent;
			elseif fn == "shiftHudCourses" then
				if prm < 0 then
					show = vehicle.cp.hud.courseListPrev;
				elseif prm > 0 then
					show = vehicle.cp.hud.courseListNext;
				end;
			end;
		elseif pg == -2 then
			show = vehicle.cp.hud.content.pages[2][prm][1].text ~= nil;

		--Page 3
		elseif pg == 3 then
			if fn == "changeTurnRadius" and prm < 0 then
				show = vehicle.cp.turnRadius > 0;
			elseif fn == "changeFollowAtFillLevel" then
				if prm < 0 then
					show = vehicle.cp.followAtFillLevel > 0;
				elseif prm > 0 then
					show = vehicle.cp.followAtFillLevel < 100;
				end;
			elseif fn == "changeDriveOnAtFillLevel" then 
				if prm < 0 then
					show = vehicle.cp.driveOnAtFillLevel > 0;
				elseif prm > 0 then
					show = vehicle.cp.driveOnAtFillLevel < 100;
				end;
			elseif fn == 'changeRefillUntilPct' then 
				if prm < 0 then
					show = (vehicle.cp.mode == 4 or vehicle.cp.mode == 8) and vehicle.cp.refillUntilPct > 1;
				elseif prm > 0 then
					show = (vehicle.cp.mode == 4 or vehicle.cp.mode == 8) and vehicle.cp.refillUntilPct < 100;
				end;
			end;

		--Page 4
		elseif pg == 4 then
			if fn == 'selectAssignedCombine' then
				show = not vehicle.cp.searchCombineAutomatically;
				if show and prm < 0 then
					show = vehicle.cp.selectedCombineNumber > 0;
				end;
			elseif fn == 'setSearchCombineOnField' then
				show = courseplay.fields.numAvailableFields > 0 and vehicle.cp.searchCombineAutomatically;
				if show then
					if prm < 0 then
						show = vehicle.cp.searchCombineOnField > 0;
					else
						show = vehicle.cp.searchCombineOnField < courseplay.fields.numAvailableFields;
					end;
				end;
			elseif fn == 'removeActiveCombineFromTractor' then
				show = vehicle.cp.activeCombine ~= nil;
			end;

		--Page 5
		elseif pg == 5 then
			if fn == 'changeTurnSpeed' then
				if prm < 0 then
					show = vehicle.cp.speeds.turn > vehicle.cp.speeds.minTurn;
				elseif prm > 0 then
					show = vehicle.cp.speeds.turn < vehicle.cp.speeds.max;
				end;
			elseif fn == 'changeFieldSpeed' then
				if prm < 0 then
					show = vehicle.cp.speeds.field > vehicle.cp.speeds.minField;
				elseif prm > 0 then
					show = vehicle.cp.speeds.field < vehicle.cp.speeds.max;
				end;
			elseif fn == 'changeMaxSpeed' then
				if prm < 0 then
					show = not vehicle.cp.speeds.useRecordingSpeed and vehicle.cp.speeds.street > vehicle.cp.speeds.minStreet;
				elseif prm > 0 then
					show = not vehicle.cp.speeds.useRecordingSpeed and vehicle.cp.speeds.street < vehicle.cp.speeds.max;
				end;
			elseif fn == 'changeUnloadSpeed' then
				if prm < 0 then
					show = vehicle.cp.speeds.unload > vehicle.cp.speeds.minUnload;
				elseif prm > 0 then
					show = vehicle.cp.speeds.unload < vehicle.cp.speeds.max;
				end;
			end;

		--Page 6
		elseif pg == 6 then
			if fn == "changeWaitTime" then
				show = courseplay:getCanHaveWaitTime(vehicle);
				if show and prm < 0 then
					show = vehicle.cp.waitTime > 0;
				end;
			elseif fn == "toggleDebugChannel" then
				show = prm >= courseplay.debugChannelSectionStart and prm <= courseplay.debugChannelSectionEnd;
			elseif fn == "changeDebugChannelSection" then
				if prm < 0 then
					show = courseplay.debugChannelSection > 1;
				elseif prm > 0 then
					show = courseplay.debugChannelSection < courseplay.numDebugChannelSections;
				end;
			end;

		--Page 7
		elseif pg == 7 then
			if fn == "changeLaneOffset" then
				show = vehicle.cp.mode == 4 or vehicle.cp.mode == 6;
			elseif fn == "toggleSymmetricLaneChange" then
				show = vehicle.cp.mode == 4 or vehicle.cp.mode == 6 and vehicle.cp.laneOffset ~= 0;
			elseif fn == "changeToolOffsetX" or fn == "changeToolOffsetZ" then
				show = vehicle.cp.mode == 3 or vehicle.cp.mode == 4 or vehicle.cp.mode == 6 or vehicle.cp.mode == 7;
			elseif fn == "switchDriverCopy" and prm < 0 then
				show = vehicle.cp.selectedDriverNumber > 0;
			elseif fn == "copyCourse" then
				show = vehicle.cp.hasFoundCopyDriver;
			end;

		--Page 8
		elseif pg == 8 then
			if fn == 'toggleSucHud' then
				show = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
			elseif fn == "toggleSelectedFieldEdgePathShow" then
				show = courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
			elseif fn == "setFieldEdgePath" then
				show = courseplay.fields.numAvailableFields > 0;
				if show then
					if prm < 0 then
						show = vehicle.cp.fieldEdge.selectedField.fieldNum > 0;
					elseif prm > 0 then
						show = vehicle.cp.fieldEdge.selectedField.fieldNum < courseplay.fields.numAvailableFields;
					end;
				end;
			elseif fn == "changeWorkWidth" and prm < 0 then
				show = vehicle.cp.workWidth > 0.1;
			elseif fn == "changeStartingDirection" then
				show = vehicle.cp.hasStartingCorner;
			elseif fn == 'toggleHeadlandDirection' or fn == 'toggleHeadlandOrder' then
				show = vehicle.cp.headland.numLanes > 0;
			elseif fn == 'changeHeadlandNumLanes' then
				if prm < 0 then
					show = vehicle.cp.headland.numLanes > 0;
				elseif prm > 0 then
					show = vehicle.cp.headland.numLanes < vehicle.cp.headland.maxNumLanes;
				end;
			elseif fn == "generateCourse" then
				show = vehicle.cp.hasValidCourseGenerationData;
			end;
		end;

		self:setShow(show);



		if self.show and not self.isHidden then
			-- set color
			local currentColor = self.curColor;
			local targetColor = currentColor;
			local hoverColor = 'hover';
			if fn == 'openCloseHud' then
				hoverColor = 'closeRed';
			end;

			if not self.isDisabled and not self.isActive and not self.isHovered and self.canBeClicked and not self.isClicked then
				targetColor = 'white';
			elseif self.isDisabled then
				targetColor = 'whiteDisabled';
			elseif not self.isDisabled and self.canBeClicked and self.isClicked and fn ~= 'openCloseHud' then
				targetColor = 'activeRed';
			elseif self.isHovered and ((not self.isDisabled and self.isToggleButton and self.isActive and self.canBeClicked and not self.isClicked) or (not self.isDisabled and not self.isActive and self.canBeClicked and not self.isClicked)) then
				targetColor = hoverColor;
				hoveredButton = true;
				if self.isToggleButton then
					--print(string.format('self %q (loop %d): isHovered=%s, isActive=%s, isDisabled=%s, canBeClicked=%s -> hoverColor', fn, g_updateLoopIndex, tostring(self.isHovered), tostring(self.isActive), tostring(self.isDisabled), tostring(self.canBeClicked)));
				end;
			elseif self.isActive and (not self.isToggleButton or (self.isToggleButton and not self.isHovered)) then
				targetColor = 'activeGreen';
				if self.isToggleButton then
					--print(string.format('button %q (loop %d): isHovered=%s, isActive=%s, isDisabled=%s, canBeClicked=%s -> activeGreen', fn, g_updateLoopIndex, tostring(self.isHovered), tostring(self.isActive), tostring(self.isDisabled), tostring(self.canBeClicked)));
				end;
			end;

			if currentColor ~= targetColor then
				self:setColor(targetColor);
			end;

			-- render
			self.overlay:render();
		end;
	end;	--elseif button.overlay ~= nil

	return hoveredButton;
end;

function courseplay.button:setColor(colorName)
	if self.overlay and colorName and (self.curColor == nil or self.curColor ~= colorName) and courseplay.hud.colors[colorName] and #courseplay.hud.colors[colorName] == 4 then
		self.overlay:setColor(unpack(courseplay.hud.colors[colorName]));
		self.curColor = colorName;
	end;
end;

function courseplay.button:setPosition(posX, posY)
	self.x = posX;
	self.x_init = posX;
	self.x2 = posX + self.width;

	self.y = posY;
	self.y_init = posY;
	self.y2 = posY + self.height;

	if not self.overlay then return; end;
	self.overlay:setPosition(self.x, self.y);
end;

function courseplay.button:setOffset(offsetX, offsetY)
	offsetX = offsetX or 0
	offsetY = offsetY or 0

	self.x = self.x_init + offsetX;
	self.y = self.y_init + offsetY;
	self.x2 = self.x + self.width;
	self.y2 = self.y + self.height;

	if not self.overlay then return; end;
	self.overlay:setPosition(self.x, self.y);
end

function courseplay.button:setParameter(parameter)
	if self.parameter ~= parameter then
		self.parameter = parameter;
	end;
end;

function courseplay.button:setToolTip(text)
	if self.toolTip ~= text then
		self.toolTip = text;
	end;
end;

function courseplay.button:setActive(active)
	if self.isActive ~= active then
		self.isActive = active;
	end;
end;

function courseplay.button:setCanBeClicked(canBeClicked)
	if self.canBeClicked ~= canBeClicked then
		self.canBeClicked = canBeClicked;
	end;
end;

function courseplay.button:setClicked(clicked)
	if self.isClicked ~= clicked then
		self.isClicked = clicked;
	end;
end;

function courseplay.button:setDisabled(disabled)
	if self.isDisabled ~= disabled then
		self.isDisabled = disabled;
	end;
end;

function courseplay.button:setHovered(hovered)
	if self.isHovered ~= hovered then
		self.isHovered = hovered;
	end;
end;

function courseplay.button:setCanScrollUp(canScrollUp)
	if self.canScrollUp ~= canScrollUp then
		self.canScrollUp = canScrollUp;
	end;
end;

function courseplay.button:setCanScrollDown(canScrollDown)
	if self.canScrollDown ~= canScrollDown then
		self.canScrollDown = canScrollDown;
	end;
end;

function courseplay.button:setShow(show)
	if self.show ~= show then
		self.show = show;
	end;
end;

function courseplay.button:setHidden(hidden)
	if self.isHidden ~= hidden then
		self.isHidden = hidden;
	end;
end;

function courseplay.button:setAttribute(attribute, value)
	if self[attribute] ~= value then
		self[attribute] = value;
	end;
end;

function courseplay.button:deleteOverlay()
	if self.overlay ~= nil and self.overlay.overlayId ~= nil and self.overlay.delete ~= nil then
		self.overlay:delete();
	end;
end;

function courseplay.button:getHasMouse(mouseX, mouseY)
	-- return mouseX > self.x and mouseX < self.x2 and mouseY > self.y and mouseY < self.y2;
	return courseplay:mouseIsInArea(mouseX, mouseY, self.x, self.x2, self.y, self.y2);
end;



-- #################################################################
-- courseplay.buttons

function courseplay.buttons:renderButtons(vehicle, page)
	-- self = courseplay.buttons

	local hoveredButton;

	for _,button in pairs(vehicle.cp.buttons.global) do
		if button:render() then
			hoveredButton = button;
		end;
	end;

	for _,button in pairs(vehicle.cp.buttons[page]) do
		if button:render() then
			hoveredButton = button;
		end;
	end;

	if page == 2 then 
		for _,button in pairs(vehicle.cp.buttons[-2]) do
		if button:render() then
				hoveredButton = button;
			end;
		end;
	end;

	if vehicle.cp.suc.active then
		if vehicle.cp.suc.fruitNegButton:render() then
			hoveredButton = vehicle.cp.suc.fruitNegButton;
		end;
		if vehicle.cp.suc.fruitPosButton:render() then
			hoveredButton = vehicle.cp.suc.fruitPosButton;
		end;
	end;

	-- set currently hovered button in vehicle
	self:setHoveredButton(vehicle, hoveredButton);
end;

function courseplay.buttons:setHoveredButton(vehicle, button)
	if vehicle.cp.buttonHovered == button then
		return;
	end;
	vehicle.cp.buttonHovered = button;

	self:onHoveredButtonChanged(vehicle);
end;

function courseplay.buttons:onHoveredButtonChanged(vehicle)
	-- set toolTip in vehicle
	if vehicle.cp.buttonHovered ~= nil and vehicle.cp.buttonHovered.toolTip ~= nil then
		courseplay:setToolTip(vehicle, vehicle.cp.buttonHovered.toolTip);
	elseif vehicle.cp.buttonHovered == nil then
		courseplay:setToolTip(vehicle, nil);
	end;
end;

function courseplay.buttons:deleteButtonOverlays(vehicle)
	for k,buttonSection in pairs(vehicle.cp.buttons) do
		for i,button in pairs(buttonSection) do
			button:deleteOverlay();
		end;
	end;
end;
