--
-- attacher
-- integration of winch attachers
--
-- @author  MaxT35
-- @date  19/9/13
--
-- Copyright (C) MaxT35, All Rights Reserved.
-- Use only allowed in selected bullies and maps.

g_attachers = {};


winchAttacher = {};
winchAttacher_mt = Class(winchAttacher);

function winchAttacher:new(id)
	local instance = {};
	setmetatable(instance, winchAttacher_mt);
	
	instance:load(id);
	
	return instance;
end;



function winchAttacher:load(id)
	self.parentId = id;
	self.isAttached = false;
	self.hook = getChildAt(id, 19);
	self.ropePos = getChildAt(id, 20);
	setVisibility(self.hook, false);
	self.x, self.y, self.z = getWorldTranslation(self.ropePos);
	print("Attacher winchAttacher:load called ");
end;

function winchAttacher:attach(newState)
	if self.isAttached then
		if newState then
			return {c=false, x=0, y=0, z=0};
		else
			self.isAttached = false;
			setVisibility(self.hook, false);
			return {c=false};
		end;
	else
		if newState then
			self.isAttached = true;
			local x, y, z = getWorldTranslation(self.ropePos);
			setVisibility(self.hook, true);
			return {c=true, x=x, y=y, z=z};
		else
			print("Error: (WinchMod) unattached vehicle wants to unattach!");
			return {c=false, x=-1, y=-1, z=-1};
		end;
	end;
end;

function winchAttacher:returnCoordinates()
	local x, y, z = getWorldTranslation(self.ropePos);
	return {c=not self.isAttached, x=x, y=y, z=z};
end;

function createAttacher(self, id)
	local attacher = winchAttacher:new(id);
	print("Attacher Create Attacher called ");
	table.insert(g_attachers, attacher);
end;
