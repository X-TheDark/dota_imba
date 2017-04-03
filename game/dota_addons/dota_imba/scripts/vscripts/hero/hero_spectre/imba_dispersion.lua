imba_spectre_dispersion = class({})

function imba_spectre_dispersion:GetIntrinsicModifierName()
	return "modifier_imba_spectre_dispersion"
end

LinkLuaModifier("modifier_imba_spectre_dispersion", "hero/hero_spectre/imba_dispersion", LUA_MODIFIER_MOTION_NONE)
modifier_imba_spectre_dispersion = class({})

function modifier_imba_spectre_dispersion:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}

	return funcs
end

function modifier_imba_spectre_dispersion:OnTakeDamage( params )
	if IsServer() then
		local caster = self:GetParent()

		if params.unit == caster and (not caster:PassivesDisabled()) then

			local ability = self:GetAbility()
			local max_radius = ability:GetSpecialValueFor("max_radius")
			local min_radius = ability:GetSpecialValueFor("min_radius")
			local reflect_pct = ability:GetSpecialValueFor("damage_reflection_pct") / 100

			if caster:IsAlive() then
				caster:SetHealth(caster:GetHealth() + (params.damage * reflect_pct) )
			end

			local enemies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, max_radius, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
			
			for _, enemy in pairs(enemies) do
				local caster_loc = caster:GetAbsOrigin()
				local enemy_loc = enemy:GetAbsOrigin()
				local particle_name = "particles/units/heroes/hero_spectre/spectre_dispersion.vpcf"

				local distance = (enemy_loc - caster_loc):Length2D()
				local distance_modifier = math.min(1, ( (max_radius - distance) / min_radius )) 
				local reflected_damage = params.original_damage * reflect_pct * distance_modifier

				if distance <= min_radius then
					particle_name = "particles/units/heroes/hero_spectre/spectre_dispersion.vpcf"
				elseif distance <= ( min_radius + (max_radius - min_radius)/2 ) then
					particle_name = "particles/units/heroes/hero_spectre/spectre_dispersion_fallback_mid.vpcf"
				else
					particle_name = "particles/units/heroes/hero_spectre/spectre_dispersion_b_fallback_low.vpcf"
				end

				local particle = ParticleManager:CreateParticle( particle_name, PATTACH_POINT_FOLLOW, caster )
					ParticleManager:SetParticleControl(particle, 0, caster_loc)
					ParticleManager:SetParticleControl(particle, 1, enemy_loc)
				ParticleManager:ReleaseParticleIndex(particle)
				ParticleManager:DestroyParticle(particle, false)

				-- Return original damage as the same type received as hp removal
				local damage_table = {
					victim = enemy,
					attacker = caster,
					damage = reflected_damage,
					damage_type = params.damage_type,
					ability = self:GetAbility(),
					damage_flags = DOTA_DAMAGE_FLAG_HPLOSS + DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL,
				}

				ApplyDamage(damage_table)
			end
		end
	end
end

function modifier_imba_spectre_dispersion:IsHidden()
	return true
end

function modifier_imba_spectre_dispersion:IsPurgable()
	return false
end