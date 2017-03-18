--	Author: Firetoad
--	Date: 			15.08.2015
--	Last Update:	18.03.2017

-----------------------------------------------------------------------------------------------------------
--	Orchid definition
-----------------------------------------------------------------------------------------------------------

if item_imba_orchid == nil then item_imba_orchid = class({}) end
LinkLuaModifier( "modifier_item_imba_orchid", "items/item_orchid.lua", LUA_MODIFIER_MOTION_NONE )			-- Owner's bonus attributes, stackable
LinkLuaModifier( "modifier_item_imba_orchid_debuff", "items/item_orchid.lua", LUA_MODIFIER_MOTION_NONE )	-- Active debuff

function item_imba_orchid:GetIntrinsicModifierName()
	return "modifier_item_imba_orchid" end

function item_imba_orchid:OnSpellStart()
	if IsServer() then

		-- Parameters
		local caster = self:GetCaster()
		local target = self:GetCursorTarget()
		local silence_duration = self:GetSpecialValueFor("silence_duration")

		-- If the target possesses a ready Linken's Sphere, do nothing
		if target:GetTeam() ~= caster:GetTeam() then
			if target:TriggerSpellAbsorb(ability) then
				return nil
			end
		end

		-- Play the cast sound
		target:EmitSound("DOTA_Item.Orchid.Activate")

		-- Apply the Orchid debuff
		target:AddNewModifier(caster, self, "modifier_item_imba_orchid_debuff", {duration = silence_duration})
	end
end

-----------------------------------------------------------------------------------------------------------
--	Orchid owner bonus attributes (stackable)
-----------------------------------------------------------------------------------------------------------

if modifier_item_imba_orchid == nil then modifier_item_imba_orchid = class({}) end
function modifier_item_imba_orchid:IsHidden() return true end
function modifier_item_imba_orchid:IsDebuff() return false end
function modifier_item_imba_orchid:IsPurgable() return false end
function modifier_item_imba_orchid:IsPermanent() return true end
function modifier_item_imba_orchid:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end

-- Attribute bonuses
function modifier_item_imba_orchid:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_MANA_REGEN_PERCENTAGE,
		MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
	}
	return funcs
end

function modifier_item_imba_orchid:GetModifierBonusStats_Intellect()
	return self:GetAbility():GetSpecialValueFor("bonus_intellect") end

function modifier_item_imba_orchid:GetModifierAttackSpeedBonus_Constant()
	return self:GetAbility():GetSpecialValueFor("bonus_attack_speed") end

function modifier_item_imba_orchid:GetModifierPreAttack_BonusDamage()
	return self:GetAbility():GetSpecialValueFor("bonus_damage") end

function modifier_item_imba_orchid:GetModifierPercentageManaRegen()
	return self:GetAbility():GetSpecialValueFor("bonus_mana_regen") end

function modifier_item_imba_orchid:GetModifierSpellAmplify_Percentage()
	return self:GetAbility():GetSpecialValueFor("spell_power") end

-----------------------------------------------------------------------------------------------------------
--	Orchid active debuff
-----------------------------------------------------------------------------------------------------------

if modifier_item_imba_orchid_debuff == nil then modifier_item_imba_orchid_debuff = class({}) end
function modifier_item_imba_orchid_debuff:IsHidden() return false end
function modifier_item_imba_orchid_debuff:IsDebuff() return true end
function modifier_item_imba_orchid_debuff:IsPurgable() return true end

-- Modifier particle
function modifier_item_imba_orchid_debuff:GetEffectName()
		return "particles/items2_fx/orchid.vpcf"
end

function modifier_item_imba_orchid_debuff:GetEffectAttachType()
		return PATTACH_OVERHEAD_FOLLOW
end

-- Reset damage storage tracking
function modifier_item_imba_orchid_debuff:OnCreated()
	if IsServer() then
		local owner = self:GetParent()
		if not owner.orchid_damage_storage then
			owner.orchid_damage_storage = 0
		end
	end
end

-- Declare modifier events/properties
function modifier_item_imba_orchid_debuff:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
	return funcs
end

-- Declare modifier states
function modifier_item_imba_orchid_debuff:CheckState()
	local states = {
		[MODIFIER_STATE_SILENCED] = true,
	}
	return states
end

-- Track damage taken
function modifier_item_imba_orchid_debuff:OnTakeDamage(keys)
	if IsServer() then
		local owner = self:GetParent()
		local target = keys.unit

		-- If this unit is the one suffering damage, store it
		if owner == target then
			owner.orchid_damage_storage = owner.orchid_damage_storage + keys.damage
		end
	end
end

-- When the debuff ends, deal damage
function modifier_item_imba_orchid_debuff:OnDestroy()
	if IsServer() then

		-- Parameters
		local owner = self:GetParent()
		local ability = self:GetAbility()
		local caster = ability:GetCaster()
		local damage_factor = ability:GetSpecialValueFor("silence_damage_percent")

		-- If damage was taken, play the effect and damage the owner
		if owner.orchid_damage_storage > 0 then
			
			-- Calculate and deal damage
			local damage = owner.orchid_damage_storage * damage_factor * 0.01
			ApplyDamage({attacker = caster, victim = owner, ability = ability, damage = damage, damage_type = DAMAGE_TYPE_MAGICAL})

			-- Fire damage particle
			local orchid_end_pfx = ParticleManager:CreateParticle("particles/items2_fx/orchid_pop.vpcf", PATTACH_OVERHEAD_FOLLOW, owner)
			ParticleManager:SetParticleControl(orchid_end_pfx, 0, owner:GetAbsOrigin())
			ParticleManager:SetParticleControl(orchid_end_pfx, 1, Vector(100, 0, 0))
			ParticleManager:ReleaseParticleIndex(orchid_end_pfx)
		end

		-- Clear damage taken variable
		self:GetParent().orchid_damage_storage = nil
	end
end

-----------------------------------------------------------------------------------------------------------
--	Bloodthorn definition
-----------------------------------------------------------------------------------------------------------

if item_imba_bloodthorn == nil then item_imba_bloodthorn = class({}) end
LinkLuaModifier( "modifier_item_imba_bloodthorn", "items/item_orchid.lua", LUA_MODIFIER_MOTION_NONE )			-- Owner's bonus attributes, stackable
--LinkLuaModifier( "modifier_item_imba_bloodthorn_unique", "items/item_orchid.lua", LUA_MODIFIER_MOTION_NONE )	-- Crit chance, unstackable
--LinkLuaModifier( "modifier_item_imba_bloodthorn_crit", "items/item_orchid.lua", LUA_MODIFIER_MOTION_NONE )		-- Passive crit buff
LinkLuaModifier( "modifier_item_imba_bloodthorn_attacker_crit", "items/item_orchid.lua", LUA_MODIFIER_MOTION_NONE )		-- Active attackers' crit buff
LinkLuaModifier( "modifier_item_imba_bloodthorn_debuff", "items/item_orchid.lua", LUA_MODIFIER_MOTION_NONE )	-- Active debuff

function item_imba_bloodthorn:GetIntrinsicModifierName()
	return "modifier_item_imba_bloodthorn" end

function item_imba_bloodthorn:OnSpellStart()
	if IsServer() then

		-- Parameters
		local caster = self:GetCaster()
		local target = self:GetCursorTarget()
		local silence_duration = self:GetSpecialValueFor("silence_duration")

		-- If the target possesses a ready Linken's Sphere, do nothing
		if target:GetTeam() ~= caster:GetTeam() then
			if target:TriggerSpellAbsorb(ability) then
				return nil
			end
		end

		-- Play the cast sound
		target:EmitSound("DOTA_Item.Orchid.Activate")

		-- Apply the Orchid debuff
		target:AddNewModifier(caster, self, "modifier_item_imba_bloodthorn_debuff", {duration = silence_duration})
	end
end

-----------------------------------------------------------------------------------------------------------
--	Bloodthorn owner bonus attributes (stackable)
-----------------------------------------------------------------------------------------------------------

if modifier_item_imba_bloodthorn == nil then modifier_item_imba_bloodthorn = class({}) end
function modifier_item_imba_bloodthorn:IsHidden() return true end
function modifier_item_imba_bloodthorn:IsDebuff() return false end
function modifier_item_imba_bloodthorn:IsPurgable() return false end
function modifier_item_imba_bloodthorn:IsPermanent() return true end
function modifier_item_imba_bloodthorn:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end

-- Adds the unique modifier when created
function modifier_item_imba_bloodthorn:OnCreated(keys)
	if IsServer() then
		local parent = self:GetParent()
		if not parent:HasModifier("modifier_item_imba_bloodthorn_unique") then
			parent:AddNewModifier(parent, self:GetAbility(), "modifier_item_imba_bloodthorn_unique", {})
		end
	end
end

-- Removes the aura emitter from the caster if this is the last vladmir's offering in its inventory
function modifier_item_imba_bloodthorn:OnDestroy(keys)
	if IsServer() then
		local parent = self:GetParent()
		Timers:CreateTimer(0.03, function()
			if not parent:HasModifier("modifier_item_imba_bloodthorn") then
				parent:RemoveModifierByName("modifier_item_imba_bloodthorn_unique")
			end
		end)
	end
end

-- Attribute bonuses
function modifier_item_imba_bloodthorn:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_MANA_REGEN_PERCENTAGE,
		MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
	}
	return funcs
end

function modifier_item_imba_bloodthorn:GetModifierBonusStats_Intellect()
	return self:GetAbility():GetSpecialValueFor("bonus_intellect") end

function modifier_item_imba_bloodthorn:GetModifierAttackSpeedBonus_Constant()
	return self:GetAbility():GetSpecialValueFor("bonus_attack_speed") end

function modifier_item_imba_bloodthorn:GetModifierPreAttack_BonusDamage()
	return self:GetAbility():GetSpecialValueFor("bonus_damage") end

function modifier_item_imba_bloodthorn:GetModifierPercentageManaRegen()
	return self:GetAbility():GetSpecialValueFor("bonus_mana_regen") end

function modifier_item_imba_bloodthorn:GetModifierSpellAmplify_Percentage()
	return self:GetAbility():GetSpecialValueFor("spell_power") end

-----------------------------------------------------------------------------------------------------------
--	Bloodthorn active debuff
-----------------------------------------------------------------------------------------------------------

if modifier_item_imba_bloodthorn_debuff == nil then modifier_item_imba_bloodthorn_debuff = class({}) end
function modifier_item_imba_bloodthorn_debuff:IsHidden() return false end
function modifier_item_imba_bloodthorn_debuff:IsDebuff() return true end
function modifier_item_imba_bloodthorn_debuff:IsPurgable() return true end

-- Modifier particle
function modifier_item_imba_bloodthorn_debuff:GetEffectName()
	return "particles/items2_fx/orchid.vpcf"
end

function modifier_item_imba_bloodthorn_debuff:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end

-- Reset damage storage tracking
function modifier_item_imba_bloodthorn_debuff:OnCreated()
	if IsServer() then
		local owner = self:GetParent()
		if not owner.orchid_damage_storage then
			owner.orchid_damage_storage = 0
		end
	end
end

-- Declare modifier events/properties
function modifier_item_imba_bloodthorn_debuff:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_TAKEDAMAGE,
		MODIFIER_EVENT_ON_ATTACK_START,
	}
	return funcs
end

-- Declare modifier states
function modifier_item_imba_bloodthorn_debuff:CheckState()
	local states = {
		[MODIFIER_STATE_SILENCED] = true,
		[MODIFIER_STATE_EVADE_DISABLED] = true,
	}
	return states
end

-- Grant the crit modifier to attackers
function modifier_item_imba_bloodthorn_debuff:OnAttackStart(keys)
	if IsServer() then
		local owner = self:GetParent()

		-- If this unit is the target, grant the attacker a crit buff
		if owner == keys.target then
			local attacker = keys.attacker
			attacker:AddNewModifier(owner, ability, "modifier_item_imba_bloodthorn_attacker_crit", {duration = 1.0})
		end
	end
end

-- Track damage taken
function modifier_item_imba_bloodthorn_debuff:OnTakeDamage(keys)
	if IsServer() then
		local owner = self:GetParent()
		local target = keys.unit

		-- If this unit is the one suffering damage, amplify and store it
		if owner == target then
			owner.orchid_damage_storage = owner.orchid_damage_storage + keys.damage
			print("storing "..keys.damage..", total: "..owner.orchid_damage_storage)
		end
	end
end

-- When the debuff ends, deal damage
function modifier_item_imba_bloodthorn_debuff:OnDestroy()
	if IsServer() then

		-- Parameters
		local owner = self:GetParent()
		local ability = self:GetAbility()
		local caster = ability:GetCaster()
		local damage_factor = ability:GetSpecialValueFor("silence_damage_percent")

		-- If damage was taken, play the effect and damage the owner
		if owner.orchid_damage_storage > 0 then
			
			-- Calculate and deal damage
			local damage = owner.orchid_damage_storage * damage_factor * 0.01
			ApplyDamage({attacker = caster, victim = owner, ability = ability, damage = damage, damage_type = DAMAGE_TYPE_MAGICAL})

			-- Fire damage particle
			local orchid_end_pfx = ParticleManager:CreateParticle("particles/items2_fx/orchid_pop.vpcf", PATTACH_OVERHEAD_FOLLOW, owner)
			ParticleManager:SetParticleControl(orchid_end_pfx, 0, owner:GetAbsOrigin())
			ParticleManager:SetParticleControl(orchid_end_pfx, 1, Vector(100, 0, 0))
			ParticleManager:ReleaseParticleIndex(orchid_end_pfx)
		end

		-- Clear damage taken variable
		self:GetParent().orchid_damage_storage = nil
	end
end

-----------------------------------------------------------------------------------------------------------
--	Bloodthorn active attacker crit buff
-----------------------------------------------------------------------------------------------------------

if modifier_item_imba_bloodthorn_attacker_crit == nil then modifier_item_imba_bloodthorn_attacker_crit = class({}) end
function modifier_item_imba_bloodthorn_attacker_crit:IsHidden() return true end
function modifier_item_imba_bloodthorn_attacker_crit:IsDebuff() return false end
function modifier_item_imba_bloodthorn_attacker_crit:IsPurgable() return false end

-- Declare modifier events/properties
function modifier_item_imba_bloodthorn_attacker_crit:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
	return funcs
end

-- Grant the crit damage multiplier
function modifier_item_imba_bloodthorn_attacker_crit:GetModifierPreAttack_CriticalStrike()
	if IsServer() then
		--return self:GetAbility():GetSpecialValueFor("target_crit_multiplier")
	end
end

-- Remove the crit modifier when the attack is concluded
function modifier_item_imba_bloodthorn_attacker_crit:OnAttackLanded(keys)
	if IsServer() then
		-- If this unit is the attacker, remove its crit modifier
		if self:GetParent() == keys.attacker then
			self:GetParent():RemoveModifierByName("modifier_item_imba_bloodthorn_attacker_crit")
		end
	end
end

function BloodthornCritRoll( keys )
	local caster = keys.caster
	local ability = keys.ability
	local ability_level = ability:GetLevel() - 1
	local modifier_crit = keys.modifier_crit

	-- Parameters
	local crit_chance = ability:GetLevelSpecialValueFor("crit_chance", ability_level)

	-- Remove crit modifier
	caster:RemoveModifierByName(modifier_crit)

	-- Roll for a crit
	if RandomInt(1, 100) <= crit_chance then
		ability:ApplyDataDrivenModifier(caster, caster, modifier_crit, {})
	end
end

function BloodthornCritHit( keys )
	local caster = keys.caster
	local modifier_crit = keys.modifier_crit

	-- Remove crit modifier
	caster:RemoveModifierByName(modifier_crit)
end