imba_spectre_haunt = class({})

function imba_spectre_haunt:OnSpellStart()
	local caster = self:GetCaster()
	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, 25000, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, FIND_ANY_ORDER, false)
	
	for _, enemy in pairs(enemies) do
		if enemy:IsRealHero() and enemy:IsAlive() then
			enemy:AddNewModifier(caster, self, "modifier_imba_spectre_haunt", {duration = self:GetSpecialValueFor("duration")})
			EmitSoundOn("Hero_Spectre.Haunt", enemy)
		end
	end

	EmitSoundOn("Hero_Spectre.HauntCast", caster)
end

LinkLuaModifier("modifier_imba_spectre_haunt", "hero/hero_spectre/imba_haunt", LUA_MODIFIER_MOTION_NONE)
modifier_imba_spectre_haunt = class({})

if IsServer() then
	function modifier_imba_spectre_haunt:OnCreated( params )
		self.aura_linger = 0.5
		self.hits_per_second = 1
		self.time_since_last_attack = 0
		self.caster_items = {}
		self.attack_delay = 1 / self.hits_per_second
		self.tick_rate = 0.03
		self.caster = self:GetCaster()
		self.target = self:GetParent()
		self.damage_outgoing = self:GetAbility():GetSpecialValueFor("damage_outgoing")
		self.velocity = self.caster:GetBaseMoveSpeed() * self.tick_rate
		self.radius = 200
		if self.shadow_dome_fx == nil then -- In case we Refresh+Cast
			self.dome_position = self.target:GetAbsOrigin()
			self.shadow_dome_fx = ParticleManager:CreateParticle("particles/units/heroes/hero_faceless_void/faceless_void_chronosphere.vpcf", PATTACH_ABSORIGIN, self.target)
				ParticleManager:SetParticleControl(self.shadow_dome_fx, 0, self.dome_position)
				ParticleManager:SetParticleControl(self.shadow_dome_fx, 1, Vector(self.radius, self.radius, 0))
		end
		-- Check through Spectre's active inventory for items
		for i = 0, 5 do
			local current_item = self.caster:GetItemInSlot(i)
			if current_item then
				self.caster_items[current_item:GetName()] = current_item
			end
		end
		self:StartIntervalThink(self.tick_rate)
	end

	-- On refresh, re-check inventory items + update velocity/attack delay
	function modifier_imba_spectre_haunt:OnRefresh( params )
		self.hits_per_second = 1
		self.caster_items = {}
		self.attack_delay = 1 / self.hits_per_second
		self.velocity = self.caster:GetBaseMoveSpeed() * self.tick_rate
		-- Check through Spectre's active inventory for items
		for i = 0, 5 do
			local current_item = self.caster:GetItemInSlot(i)
			if current_item then
				self.caster_items[current_item:GetName()] = current_item
			end
		end
	end

	function modifier_imba_spectre_haunt:OnDestroy()
		if self.shadow_dome_fx then
			ParticleManager:DestroyParticle(self.shadow_dome_fx, false)
			ParticleManager:ReleaseParticleIndex(self.shadow_dome_fx)
			self.shadow_dome_fx = nil
		end
	end

	function modifier_imba_spectre_haunt:OnIntervalThink()
		if self.shadow_dome_fx then
			-- Movement Code
			local distance = (self.target:GetAbsOrigin() - self.dome_position):Length2D()
			local in_range = false

			if distance > 0 then
				if distance <= self.velocity then
					self.dome_position = self.target:GetAbsOrigin()
					in_range = true
				else
					local direction = (self.target:GetAbsOrigin() - self.dome_position):Normalized()
					self.dome_position = self.dome_position + direction * self.velocity
					ParticleManager:SetParticleControl(self.shadow_dome_fx, 0, self.dome_position)

					if ( (self.target:GetAbsOrigin() - self.dome_position):Length2D() <= self.radius ) then
						in_range = true
					end
				end
			else
				in_range = true
			end
			----------------

			-- Attack and Aura Code
			if in_range then
				-- Perform attack, if in range and enough time passed since last attack
				if self.time_since_last_attack >= self.attack_delay then
					local ranged_attacker = self.caster:IsRangedAttacker() -- This is for Rubick
					local original_pos = self.caster:GetAbsOrigin()
					self.caster:SetAbsOrigin(self.target:GetAbsOrigin())
					-- Place outgoing damage debuff
					self.caster:AddNewModifier(self.caster, self, "modifier_imba_spectre_haunt_dmg_reduction", {duration = 0.1, damage_outgoing = self.damage_outgoing})
					self.caster:PerformAttack(self.target, true, true, true, false, ranged_attacker, false, false)
					self.caster:SetAbsOrigin(original_pos)
					self.time_since_last_attack = 0
				end

				-- Apply all auras that are carried by Spectre
				local item_aura_list = {
					["item_imba_radiance"] = {"modifier_item_imba_radiance_aura"},
					["item_imba_assault"] = {"modifier_item_imba_assault_negative_aura"},
					["item_imba_siege_cuirass"] = {"modifier_item_imba_siege_cuirass_negative_aura"},
					["item_imba_shivas_guard"] = {"modifier_item_imba_shivas_aura_slow_stack"},
					["item_imba_veil_of_discord"] = {"modifier_item_imba_veil_of_discord_aura_debuff"}
				}

				for item_name, itemref in pairs(self.caster_items) do
					if item_aura_list[item_name] then
						for _, aura in pairs(item_aura_list) do
							local skip_aura = false
							-- Don't apply Assault Cuirass aura if we have a Siege Cuirass in our inventory
							if ( item_name == "item_imba_assault" ) and self.caster_items["item_imba_siege_cuirass"] then
								skip_aura = true
							end
							if not skip_aura then
								self.target:AddNewModifier(self.caster, itemref, aura, {duration = self.aura_linger})
							end
						end
					end
				end
			end
			-----------------------
			self.time_since_last_attack = self.time_since_last_attack + self.tick_rate
		end
	end
end

function modifier_imba_spectre_haunt:IsDebuff()
	return true
end

function modifier_imba_spectre_haunt:IsPurgable()
	return false
end

----------------------------------------------------------
-- Spectre Haunt Damage Reduction Aura
----------------------------------------------------------
LinkLuaModifier("modifier_imba_spectre_haunt_dmg_reduction", "hero/hero_spectre/imba_haunt", LUA_MODIFIER_MOTION_NONE)
modifier_imba_spectre_haunt_dmg_reduction = class({})

if IsServer() then
	function modifier_imba_spectre_haunt_dmg_reduction:OnCreated( kv )
		self.damage_outgoing = kv.damage_outgoing
	end

	function modifier_imba_spectre_haunt_dmg_reduction:OnRefresh( kv )
		self.damage_outgoing = kv.damage_outgoing
	end
end

function modifier_imba_spectre_haunt_dmg_reduction:IsDebuff()
	return true
end

function modifier_imba_spectre_haunt_dmg_reduction:IsHidden()
	return true
end

function modifier_imba_spectre_haunt_dmg_reduction:IsPurgable()
	return false
end

function modifier_imba_spectre_haunt_dmg_reduction:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE,
	}
	return funcs
end

function modifier_imba_spectre_haunt_dmg_reduction:GetModifierDamageOutgoing_Percentage()
	return -(100 - self.damage_outgoing)
end