imba_spectre_desolate = class({})

function imba_spectre_desolate:GetIntrinsicModifierName()
	return "modifier_imba_spectre_desolate"
end

LinkLuaModifier("modifier_imba_spectre_desolate", "hero/hero_spectre/imba_desolate", LUA_MODIFIER_MOTION_NONE)
modifier_imba_spectre_desolate = class({})

function modifier_imba_spectre_desolate:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_ATTACK,
	}
	return funcs
end

function modifier_imba_spectre_desolate:OnAttack( params )
	if IsServer() then
		local caster = self:GetParent()
		if params.attacker == caster and not caster:PassivesDisabled() then
			local target = params.target
			local radius = self:GetAbility():GetSpecialValueFor("radius")

			local enemies = FindUnitsInRadius(caster:GetTeamNumber(), target:GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NO_INVIS, FIND_ANY_ORDER, false)
			local target_is_alone = true

			for _,unit in pairs(enemies) do
				if unit:GetTeam() == target:GetTeam() and unit ~= target then
					target_is_alone = false
				end
			end

			if target_is_alone and ( not target:IsMagicImmune() ) then
				EmitSoundOn("Hero_Spectre.Desolate", target)

				local desolate_fx = ParticleManager:CreateParticle("particles/units/heroes/hero_spectre/spectre_desolate.vpcf", PATTACH_POINT, target)
				ParticleManager:SetParticleControl(desolate_fx, 0, Vector(
					target:GetAbsOrigin().x,
					target:GetAbsOrigin().y, 
					GetGroundPosition(target:GetAbsOrigin(), target).z + 140)
				)
				ParticleManager:SetParticleControlForward(desolate_fx, 0, caster:GetForwardVector())
				ParticleManager:ReleaseParticleIndex(desolate_fx)

				local damage_table = {
					victim = target,
					attacker = caster,
					damage = self:GetAbility():GetSpecialValueFor("bonus_damage"),
					damage_type = self:GetAbility():GetAbilityDamageType(),
					ability = self:GetAbility(),
				}
							
				ApplyDamage(damage_table)
			end
		end
	end
end

function modifier_imba_spectre_desolate:IsHidden()
	return true
end

function modifier_imba_spectre_desolate:RemoveOnDeath()
	return false
end