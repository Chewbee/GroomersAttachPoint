--
-- winch
-- Specialization for the winch of a pistenbully
--
-- @author  MaxT35
-- @date  19/9/13
--
-- Copyright (C) MaxT35, All Rights Reserved.
-- Use only allowed in selected bullies and maps.

global_attachersLoaded = false;

-- constant
WINCH_PRECISION = 0.5;
WINCH_OVER_TERRAIN = 0.1;

-- helpers

function hlp_vector2length(vect1, vect2)
	return math.sqrt(vect1*vect1 + vect2*vect2);
end;

winch = {};

function winch:setIsAttached(isAttached, x, y, z, noEventSend)
	--SetWinchIsAttachedEvent.sendEvent(self, isAttached, x, y, z, noEventSend);
	self.winchAttached = isAttached;
	self.wa.x = x;
	self.wa.y = y;
	self.wa.z = z;
	setVisibility(self.ropeHook, not isAttached);
	if not isAttached then
		for k, v in pairs(self.ropes) do
			if v ~= 0 then
				setVisibility(v, false);
				v = 0;
			end;
		end;
	end;
end;

function winch.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Steerable, specializations);
end;

function winch:load(xmlFile)
	self.wa = {}; -- winchAttach - Koordinaten
	self.wa.x = 0;
	self.wa.y = 0;
	self.wa.z = 0;
	self.winchAttached = false;
	self.attacher = 0;
	
	self.setIsAttached = SpecializationUtil.callSpecializationsFunction("setIsAttached");

	
	self.animate = Utils.getNoNil(getXMLInt(xmlFile, "vehicle.winch#animateCount"), 0);
	self.anim = {};
	if self.animate > 0 then
		for i=1, self.animate, 1 do
			local instance = {};
			instance.id = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.winch.animate" .. i .. "#node"));
			instance.radius = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.winch.animate" .. i .. "#radius"), 0.5)
			table.insert(self.anim, instance);
		end;
	end;
	
	self.winchNode = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.winch.rotatingPart#node"));
	self.winchPos = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.winch.rotatingPart#pos"));
	self.ropeHook = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.winch.hook#node"));
	self.ropeEndNode = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.winch.rope#endNode"));
	self.rope1 = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.winch.rope#node"));
	link(getRootNode(), self.rope1);
	self.ropeCount = 0;
	self.ropes = {};
	
	self.lrl = 0; -- last rope length
	
	self.maxRl = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.winch.rope#length"), 1000);
	self.newCoordinates = false;
end;

function winch:delete()

end;

function winch:mouseEvent(posX, posY, isDown, isUp, button)

end;

function winch:keyEvent(unicode, sym, modifier, isDown)
end;

function winch:update(dt)
	if self.winchAttached then
		
		if self.newCoordinates then
			local v = winchMod.g_attachers[self.attacher]:returnCoordinates();
			self.wa.x, self.wa.y, self.wa.z = v.x, v.y, v.z;
		end;
		-- thanks to Face for this piece of code
		local rx,ry,rz = getRotation(self.winchNode);
		local wx,wy,wz = getWorldTranslation(self.winchNode); 
		local x,y,z = worldDirectionToLocal(getParent(self.winchNode), self.wa.x-wx, self.wa.y-wy, self.wa.z-wz);
		local rotW = math.atan2(x,z);
		rotW = Utils.normalizeRotationForShortestPath(rotW, ry);
		setRotation(self.winchNode, 0, rotW, 0);
		
		local  x, y, z = getWorldTranslation(self.ropeEndNode);
		local wx,wy,wz = self.wa.x, self.wa.y, self.wa.z;

		-- length of track from bully to attacher
		
		local endLoop = true;
		
		local bx, by, bz = x, y, z; -- begin X, we need this when we want to place two pieces of rope in a row
		local ex, ey, ez = wx, wy, wz;
		
		local rtp = {}; -- rtd .. ropes to place
		
		local count = 1;
		
		while endLoop do
			local track = Utils.vector3Length(wx-bx, wy-by, wz-bz);
			local angle = -math.atan2(hlp_vector2length(wx-bx, wz-bz), wy-by);
			
			local maxTrack = track;
			local maxAngle = angle;
			
			local xd, yd, zd = wx-bx, wy-by, wz-bz;
			
			for i=WINCH_PRECISION, track, WINCH_PRECISION do
				local tx, ty, tz = xd * i/track, yd * i/track, zd * i/track;
				
				ty2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, bx+tx, 3000, bz+tz) - by + WINCH_OVER_TERRAIN;
				
				local a = -math.atan2(hlp_vector2length(tx, tz), ty2);
				if a > maxAngle then
					maxAngle = a;
					maxTrack = i;
					ex, ey, ez = tx+bx, ty2+by, tz+bz;
				end;
			end;
			
			table.insert(rtp, ropeSegment(bx, by, bz, ex, ey, ez, count));
			
			if ex == wx and ey == wy and ez == wz then
				-- the last segment was calculated
				endLoop = false; -- end loop
			else
				-- we still need to calculate at least one piece of rope
				count = count + 1;
				bx, by, bz = ex, ey, ez;
				ex, ey, ez = wx, wy, wz;
			end;
			if count > 200 then
				endLoop = false;
			end;
		end;
		
		for k, v in pairs(self.ropes) do
			if v ~= 0 then
				delete(v);
				v = 0;
			end;
		end;
		
		self.ropes = {};
		
		for k, v in pairs(rtp) do
			placeRope(v, self.rope1, self.ropes);
		end;
		
		local ropeLength = 0;
		for k, v in pairs(rtp) do
			ropeLength = ropeLength + Utils.vector3Length(v.ex-v.bx, v.ey-v.by, v.ez-v.bz);
		end;
		
		local moved = ropeLength-self.lrl;
		
		for k, v in pairs(self.anim) do
			local circ = v.radius * 2 * math.pi;
			local rot = moved / circ;
			local a, b, c = getRotation(v.id);
			setRotation(v.id, a+rot, b, c);
		end;
		
		self.lrl = ropeLength;

		
		if InputBinding.isPressed(InputBinding.WINCH_unattach) and self.isEntered then
			local b = winchMod.g_attachers[self.attacher]:attach(false);
			self.winchAttached = b.c;
			if not self.winchAttached then
				self:setIsAttached(false, 0, 0, 0);
				self.newCoordinates = false;
			end;
		end;
	else
		if InputBinding.isPressed(InputBinding.WINCH_left) and self.isEntered then
			local x, y, z = getRotation(self.winchNode);
			setRotation(self.winchNode, 0, y + (math.rad(360) / 8)*dt/1000, 0);
		end;
		if InputBinding.isPressed(InputBinding.WINCH_right) and self.isEntered then
			local x, y, z = getRotation(self.winchNode);
			setRotation(self.winchNode, 0, y - (math.rad(360) / 8)*dt/1000, 0);
		end;
		local px,py,pz = getWorldTranslation(self.ropeEndNode);
		local n = 0;
		local d = 50;
		for k, v in pairs(winchMod.g_attachers) do
			if Utils.vector3Length(v.x-px, v.y-py, v.z-pz) < d then
				d = Utils.vector3Length(v.x-px, v.y-py, v.z-pz);
				n = k;
			end;
		end;
		if d <= 4.9999 and InputBinding.hasEvent(InputBinding.WINCH_attach) and self.isEntered then
			local b = winchMod.g_attachers[n]:attach(true);
			self:setIsAttached(b.c, b.x, b.y, b.z);
			self.attacher = n;
			winchMod.g_attachers[n].isAttached = true;
			if winchMod.g_attachers[n].newCoordinates ~= nil and winchMod.g_attachers[n].newCoordinates then
				self.newCoordinates = true;
			end;
		end;
	end;
end;

function winch:draw()
end;

function ropeSegment(bx, by, bz, ex, ey, ez, no)
	-- creates a segment of rope with those translations
	return {bx=bx, by=by, bz=bz, ex=ex, ey=ey, ez=ez, no=no};
end;

function placeRope(rs, ropeBase, ropeList)
	if ropeList[rs.no] == nil then
		ropeList[rs.no] = clone(ropeBase, false);
		link(getRootNode(), ropeList[rs.no]);
	end;
	
	local xd, yd, zd = rs.ex-rs.bx, rs.ey-rs.by, rs.ez-rs.bz;
	local angle1 = -math.atan2(yd, hlp_vector2length(xd, zd));
	local angle2 = math.atan2(xd, zd);
	local length = Utils.vector3Length(xd, yd, zd);
	
	setTranslation(ropeList[rs.no], rs.bx, rs.by, rs.bz);
	setRotation(ropeList[rs.no], angle1, angle2, 0);
	setScale(ropeList[rs.no], 1, 1, length);
end;