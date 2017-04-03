imba_spectre_shadow_dome = class({})

function imba_spectre_shadow_dome:CastFilterResultTarget( hTarget )
	if self:GetCaster() == hTarget then
		return UF_FAIL_CUSTOM
	end

	if ( hTarget:IsCreep() and ( not self:GetCaster():HasScepter() ) ) or hTarget:IsAncient() then
		return UF_FAIL_CUSTOM
	end

	local nResult = UnitFilter( hTarget, DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP, DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, self:GetCaster():GetTeamNumber() )
	if nResult ~= UF_SUCCESS then
		return nResult
	end

	return UF_SUCCESS
end

function imba_spectre_shadow_dome:GetCustomCastErrorTarget( hTarget )
	if self:GetCaster() == hTarget then
		return "#dota_hud_error_cant_cast_on_self"
	end

	if hTarget:IsAncient() then
		return "#dota_hud_error_cant_cast_on_ancient"
	end

	if hTarget:IsCreep() and ( not self:GetCaster():HasScepter() ) then
		return "#dota_hud_error_cant_cast_on_creep"
	end

	return ""
end

function imba_spectre_shadow_dome:OnSpellStart()
end