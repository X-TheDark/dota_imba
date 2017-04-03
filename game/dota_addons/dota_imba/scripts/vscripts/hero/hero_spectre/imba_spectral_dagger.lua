imba_spectre_spectral_dagger = class({})

function imba_spectre_spectral_dagger:OnSpellStart()
	local proj_info
	local caster = self:GetCaster()
	local cursor_pos = self:GetCursorPosition()
	local target = self:GetCursorTarget()

	if caster == nil or ( cursor_pos == nil and target == nil ) then
		return
	end
	
	if IsServer() then
		self.vision_radius = self:GetSpecialValueFor("vision_radius")
		self.dagger_path_duration = self:GetSpecialValueFor("dagger_path_duration")
		self.hero_path_duration = self:GetSpecialValueFor("hero_path_duration")
		self.dagger_radius = self:GetSpecialValueFor("dagger_radius")
		self.path_radius = self:GetSpecialValueFor("path_radius")
		if not self.dagger_waypoints then
			self.dagger_waypoints = {}
		end
		if not self.path_creator_waypoints then
			self.path_creator_waypoints = {}
		end
		if not self.damaged_entities then
			self.damaged_entities = {}
		else
			self:CleanDamagedEntityTable()
		end
		if target then
			proj_info = {
				Target = target,
				Source = caster,
				Ability = self,	
				EffectName = "particles/units/heroes/hero_spectre/spectre_spectral_dagger_tracking.vpcf",
				iMoveSpeed = self:GetSpecialValueFor("speed"),
				vSourceLoc= caster:GetAbsOrigin(),
				bDodgeable = false,
				bVisibleToEnemies = true,
				bReplaceExisting = false,
				flExpireTime = GameRules:GetGameTime() + 10,
				bProvidesVision = true,
				iVisionRadius = vision_radius,
				iVisionTeamNumber = caster:GetTeamNumber(),
			}
			ProjectileManager:CreateTrackingProjectile( proj_info )
			EmitSoundOn("Hero_Spectre.DaggerCast", caster)
			caster:AddNewModifier(caster, self, "modifier_imba_spectral_dagger_path", {})
		elseif cursor_pos then
			proj_info = {
				Ability = self,
				EffectName = "particles/units/heroes/hero_spectre/spectre_spectral_dagger.vpcf",
				vSpawnOrigin = caster:GetAbsOrigin(),
				fDistance = 3000,
				fStartRadius = self.dagger_radius,
				fEndRadius = self.dagger_radius,
				Source = caster,
				bHasFrontalCone = false,
				bReplaceExisting = false,
				iUnitTargetTeam = self:GetAbilityTargetTeam(),
				iUnitTargetFlags = self:GetAbilityTargetFlags(),
				iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
				fExpireTime = GameRules:GetGameTime() + 10.0,
				bDeleteOnHit = false,
				vVelocity = caster:GetForwardVector() * self:GetSpecialValueFor("speed"),
				bProvidesVision = true,
				iVisionRadius = vision_radius,
				iVisionTeamNumber = caster:GetTeamNumber(),
			}
			ProjectileManager:CreateLinearProjectile( proj_info )
			EmitSoundOn("Hero_Spectre.DaggerCast", caster)
			caster:AddNewModifier(caster, self, "modifier_imba_spectral_dagger_path", {})
		end
	end
end

function imba_spectre_spectral_dagger:OnProjectileThink( vLocation )
	if IsServer() then
		local enemies = FindUnitsInRadius(self:GetCaster():GetTeamNumber(), vLocation, nil, self.dagger_radius, self:GetAbilityTargetTeam(), DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, self:GetAbilityTargetFlags(), FIND_ANY_ORDER, false)
		for _, enemy in pairs(enemies) do
			if self.damaged_entities and ( not self.damaged_entities[enemy:GetEntityIndex()] ) then
				local damage_table = {
					victim = enemy,
					attacker = self:GetCaster(),
					damage = self:GetSpecialValueFor("damage"),
					damage_type = self:GetAbilityDamageType(),
				}
				ApplyDamage(damage_table)
				self.damaged_entities[enemy:GetEntityIndex()] = true
				EmitSoundOn("Hero_Spectre.DaggerImpact", enemy)
			end
			if enemy:IsHero() then
				local modifier = enemy:FindModifierByName("modifier_imba_spectral_dagger_path_creator")
				if modifier then
					modifier:SetDuration(self.hero_path_duration, true)
				else
					enemy:AddNewModifier(self:GetCaster(), self, "modifier_imba_spectral_dagger_path_creator", {duration = self.hero_path_duration})
				end
			end
		end
		if self.last_waypoint then
			-- We create waypoints at a distance of radius of each other (compromise between coverage and minimizing the amount of points)
			if ((self.last_waypoint - vLocation):Length2D() < self.path_radius) then
				return
			end
		end
		self.last_waypoint = vLocation
		local expire_time = GameRules:GetGameTime() + self.dagger_path_duration
		local waypoint = {}
		waypoint["location"] = vLocation
		waypoint["expire"] = expire_time
		self.dagger_waypoints[#self.dagger_waypoints+1] = waypoint
		AddFOWViewer(self:GetCaster():GetTeamNumber(), vLocation, self.vision_radius, self.dagger_path_duration, false)
	end
end

function imba_spectre_spectral_dagger:OnProjectileHit( hTarget, vLocation )
	if hTarget and IsServer() then
		if hTarget:GetTeamNumber() ~= self:GetCaster():GetTeamNumber() then
			if hTarget:TriggerSpellAbsorb(self) then
				return nil
			end
		end
		if self.damaged_entities and ( not self.damaged_entities[hTarget:GetEntityIndex()] ) then
			local damage_table = {
				victim = hTarget,
				attacker = self:GetCaster(),
				damage = self:GetSpecialValueFor("damage"),
				damage_type = self:GetAbilityDamageType(),
			}
			ApplyDamage(damage_table)
			self.damaged_entities[hTarget:GetEntityIndex()] = true
			EmitSoundOn("Hero_Spectre.DaggerImpact", hTarget)
		end
		if hTarget:IsHero() then
			local modifier = hTarget:FindModifierByName("modifier_imba_spectral_dagger_path_creator")
			if modifier then
				modifier:SetDuration(self.hero_path_duration, true)
			else
				hTarget:AddNewModifier(self:GetCaster(), self, "modifier_imba_spectral_dagger_path_creator", {duration = self.hero_path_duration})
			end
		end
	end
end

-- Reserves a table for path creator and returns that table to the caller
function imba_spectre_spectral_dagger:RegisterPathCreator()
	local new_table = {}
	self.path_creator_waypoints[#self.path_creator_waypoints+1] = new_table
	return new_table
end

-- All of the arrays are 1-base index
function imba_spectre_spectral_dagger:CleanWaypointTables()
	if IsServer() then
		-- Array of tables
		for i = 1, #self.dagger_waypoints do
			self.dagger_waypoints[i]["location"] = nil
			self.dagger_waypoints[i]["expire"] = nil
			self.dagger_waypoints[i] = nil
		end

		-- Array of array of tables
		for i = 1, #self.path_creator_waypoints do
			local waypoint_table = self.path_creator_waypoints[i]
			local inner_count = #waypoint_table
			for j = 1, inner_count do
				waypoint_table[j]["location"] = nil
				waypoint_table[j]["expire"] = nil
				waypoint_table[j] = nil
			end
			self.path_creator_waypoints[i] = nil
		end
	end
end

-- Separate function because I want to clean these at the start of the cast, in case cooldown ever becomes lower than the duration
function imba_spectre_spectral_dagger:CleanDamagedEntityTable()
	-- Dictionary with integer keys
	for key, _ in pairs(self.damaged_entities) do
		self.damaged_entities[key] = nil
	end
end

-------------------------------------------------------------------------------------
-- Spectral Dagger path modifier (the path itself)
-------------------------------------------------------------------------------------
LinkLuaModifier("modifier_imba_spectral_dagger_path", "hero/hero_spectre/imba_spectral_dagger", LUA_MODIFIER_MOTION_NONE)
modifier_imba_spectral_dagger_path = class({})

function modifier_imba_spectral_dagger_path:OnCreated( kv )
	if IsServer() then
		if not self.dagger_waypoints then
			self.dagger_waypoints = self:GetAbility().dagger_waypoints
		end
		if not self.path_creator_waypoints then
			self.path_creator_waypoints = self:GetAbility().path_creator_waypoints
		end
		self.caster = self:GetCaster()
		self.radius = self:GetAbility():GetSpecialValueFor("path_radius")
		self.buff_persistence = self:GetAbility():GetSpecialValueFor("buff_persistence")
		self.dagger_grace_period = self:GetAbility():GetSpecialValueFor("dagger_grace_period")
		self:StartIntervalThink(0.1)
	end
end

function modifier_imba_spectral_dagger_path:OnIntervalThink()
	if IsServer() then
		local all_points_expired = true
		-- Dagger path contains only 1 set of waypoints, the dagger's
		for i = #self.dagger_waypoints, 1, -1 do
			local waypoint = self.dagger_waypoints[i]
			if waypoint["expire"] > GameRules:GetGameTime() then
				self:ApplyShadowPathModifierSelf(waypoint["location"])
				self:ApplyShadowPathModifierEnemy(waypoint["location"])
				all_points_expired = false
			else
				-- Points at the end expire later than those at the start, so if we find one, everything before it is expired too
				break
			end
		end
		-- Path creator waypoints contain a table of each creators (hero hit by dagger) waypoints
		for _, tableWaypoints in pairs(self.path_creator_waypoints) do
			for i = #tableWaypoints, 1, -1 do
				local waypoint = tableWaypoints[i]
				if waypoint["expire"] > GameRules:GetGameTime() then
					self:ApplyShadowPathModifierSelf(waypoint["location"])
					self:ApplyShadowPathModifierEnemy(waypoint["location"])
					all_points_expired = false
				else
					-- Points at the end expire later than those at the start, so if we find one, everything before it is expired too
					break
				end
			end
		end

		-- Remove the path modifier only when all created waypoints are expired
		if all_points_expired then
			self:StartIntervalThink(-1)
			self:GetAbility():CleanWaypointTables() -- damaged entities are reset on cast
			self:Destroy()
		end
	end
end

function modifier_imba_spectral_dagger_path:ApplyShadowPathModifierEnemy( vLocation )
	local enemies = FindUnitsInRadius(self.caster:GetTeamNumber(), vLocation, nil, self.radius, self:GetAbility():GetAbilityTargetTeam(), self:GetAbility():GetAbilityTargetType(), self:GetAbility():GetAbilityTargetFlags(), FIND_ANY_ORDER, false)
	for _, enemy in pairs(enemies) do
		local modifier = enemy:FindModifierByName("modifier_imba_spectral_dagger_in_path")
		if modifier then
			modifier:SetDuration(self.buff_persistence, true)
		else
			enemy:AddNewModifier(self.caster, self:GetAbility(), "modifier_imba_spectral_dagger_in_path", {duration = self.buff_persistence})
		end
	end
end

function modifier_imba_spectral_dagger_path:ApplyShadowPathModifierSelf( vLocation )
	local distance = (self.caster:GetAbsOrigin() - vLocation):Length2D()
	if distance < self.radius then
		-- Movespeed buff application
		local modifier = self.caster:FindModifierByName("modifier_imba_spectral_dagger_in_path")
		if modifier then
			modifier:SetDuration(self.buff_persistence, true)
		else
			self.caster:AddNewModifier(self.caster, self:GetAbility(), "modifier_imba_spectral_dagger_in_path", {duration = self.buff_persistence})
		end
		-- Phasing buff application
		modifier = self.caster:FindModifierByName("modifier_imba_spectral_dagger_path_phased")
		if modifier then
			modifier:SetDuration(self.dagger_grace_period, true)
		else
			self.caster:AddNewModifier(self.caster, self:GetAbility(), "modifier_imba_spectral_dagger_path_phased", {duration = self.dagger_grace_period})
		end
	end
end

function modifier_imba_spectral_dagger_path:IsPurgable()
	return false
end

function modifier_imba_spectral_dagger_path:IsHidden()
	return true
end

-------------------------------------------------------------------------------------
-- Spectral Dagger path buff/debuff
-------------------------------------------------------------------------------------
LinkLuaModifier("modifier_imba_spectral_dagger_in_path", "hero/hero_spectre/imba_spectral_dagger", LUA_MODIFIER_MOTION_NONE)
modifier_imba_spectral_dagger_in_path = class({})

function modifier_imba_spectral_dagger_in_path:OnCreated( kv )
	self.bonus_movespeed = self:GetAbility():GetSpecialValueFor("bonus_movespeed")
end

function modifier_imba_spectral_dagger_in_path:IsDebuff()
	if self:GetParent() == self:GetCaster() then
		return false
	else
		return true
	end
end

function modifier_imba_spectral_dagger_in_path:IsPurgable()
	return false
end

function modifier_imba_spectral_dagger_in_path:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
	return funcs
end

function modifier_imba_spectral_dagger_in_path:GetModifierMoveSpeedBonus_Percentage()
	if self:GetParent() == self:GetCaster() then
		return self.bonus_movespeed
	elseif ( not self:GetParent():IsMagicImmune() ) then
		return -self.bonus_movespeed
	else
		return 0
	end
end

-------------------------------------------------------------------------------------
-- Spectral Dagger path phasing buff
-------------------------------------------------------------------------------------
LinkLuaModifier("modifier_imba_spectral_dagger_path_phased", "hero/hero_spectre/imba_spectral_dagger", LUA_MODIFIER_MOTION_NONE)
modifier_imba_spectral_dagger_path_phased = class({})

function modifier_imba_spectral_dagger_path_phased:CheckState()
	local state = {
		[MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
	}

	return state
end

function modifier_imba_spectral_dagger_path_phased:IsHidden()
	return true
end

function modifier_imba_spectral_dagger_path_phased:IsPurgable()
	return false
end

-------------------------------------------------------------------------------------
-- Spectral Dagger path creator debuff
-------------------------------------------------------------------------------------
LinkLuaModifier("modifier_imba_spectral_dagger_path_creator", "hero/hero_spectre/imba_spectral_dagger", LUA_MODIFIER_MOTION_NONE)
modifier_imba_spectral_dagger_path_creator = class({})

function modifier_imba_spectral_dagger_path_creator:OnCreated( kv )
	if IsServer() then
		self.waypoint_table = self:GetAbility():RegisterPathCreator()
		-- 10 times per second seems reasonable enough
		self:StartIntervalThink(0.1)
	end
end

function modifier_imba_spectral_dagger_path_creator:CheckState()
	local state = {
		[MODIFIER_STATE_PROVIDES_VISION] = true,
	}

	return state
end

function modifier_imba_spectral_dagger_path_creator:IsDebuff()
	return true
end

function modifier_imba_spectral_dagger_path_creator:GetEffectName()
	return "particles/units/heroes/hero_spectre/spectre_shadow_path_owner.vpcf"
end

function modifier_imba_spectral_dagger_path_creator:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_imba_spectral_dagger_path_creator:OnIntervalThink()
	if self.waypoint_table and IsServer() then
		local current_loc = self:GetParent():GetAbsOrigin()
		-- I know this allows for multiple points if target walks back and forth, but it's not worth the effort to compare with all points
		if self.last_waypoint then
			if ((self.last_waypoint - current_loc):Length2D() < self:GetAbility().path_radius) then
				return
			end
		end
		self.last_waypoint = current_loc
		local expire_time = GameRules:GetGameTime() + self:GetAbility().dagger_path_duration
		local waypoint = {}
		waypoint["location"] = current_loc
		waypoint["expire"] = expire_time
		self.waypoint_table[#self.waypoint_table+1] = waypoint
	end
end

function modifier_imba_spectral_dagger_path_creator:IsPurgable()
	return false
end