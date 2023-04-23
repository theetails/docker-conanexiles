#!/bin/bash

source /var/lib/conanexiles/redis_cmds.sh

# defaults
if [ -z $CONANEXILES_INSTANCENAME ]
then
    _config_folder="/conanexiles/ConanSandbox/Saved/Config/WindowsServer"
else
    _config_folder="/conanexiles/ConanSandbox/${CONANEXILES_INSTANCENAME}/Saved/Config/WindowsServer"
fi

_config_folder_provided="/tmp/docker-conanexiles"

_bashrc_tag_start="# >> docker-conanexiles"
_bashrc_tag_end="# << docker-conanexiles "

_env_variable_prefix="CONANEXILES"
_env_variable_filter="\
CharacterLOD|\
Compat|\
DeviceProfiles|\
EditorPerProjectUserSettings|\
Engine|\
Game|\
GameUserSettings|\
GameplayTags|\
GraniteCooked|\
GraniteCookedMod|\
Hardware|\
Input|\
Lightmass|\
Scalability|\
ServerSettings\
"

# Matchgroup 3 can be unspecific like that, because Keys have no "_" in Exiles Config
_env_regex="CONANEXILES_([a-zA-Z]+)_(.*)_(.*)=(.*)"

init_master_server_instance() {
    [[ $CONANEXILES_MASTERSERVER == 1 ]] && redis_cmd_proxy redis_set_master_server_instance
}

init_supervisor_conanexiles_cmd() {
    _target="/etc/supervisor/conf.d/conanexiles.conf"

    # set default cmdswitch
    sed -E "s/(command=wine64.*)/command=wine64 \/conanexiles\/ConanSandboxServer.exe -nosteamclient -game -server -log/" -i "${_target}"

    # add usedir switch if instancename given
    if [ -n "${CONANEXILES_INSTANCENAME}" ]; then
        sed -E "s/(command=wine64.*)/\1 -userdir=%(ENV_CONANEXILES_INSTANCENAME)s/" -i "${_target}"
    fi

    # Port Configs
    if [ -n "${CONANEXILES_PORT}" ]; then
        sed -E "s/(command=wine64.*)/\1 ${CONANEXILES_PORT}/" -i "${_target}"
    fi

    # QueryPort
    if [ -n "${CONANEXILES_QUERYPORT}" ]; then
        sed -E "s/(command=wine64.*)/\1 ${CONANEXILES_QUERYPORT}/" -i "${_target}"
    fi

    # add additional cmdline switches
    if [ -n "${CONANEXILES_CMDSWITCHES}" ]; then
        sed -E "s/(command=wine64.*)/\1 ${CONANEXILES_CMDSWITCHES}/" -i "${_target}"
    fi
}

setup_bashrc() {
    cat >> /bash.bashrc <<EOF


$_bashrc_tag_start
export wineprefix=/wine
export winearch=win64
$_bashrc_tag_end
EOF
}

setup_server_config_first_time() {

    # Check if instance name given
    [ -n "${CONANEXILES_INSTANCENAME}" ] && _config_folder="/conanexiles/ConanSandbox/${CONANEXILES_INSTANCENAME}/Saved/Config/WindowsServer"

    # config provided, don't override
    [ -d "${_config_folder_provided}" ] && [ ! -d "${_config_folder}" ] && \
	mkdir -p "${_config_folder}" && \
	(cp -rv "${_config_folder_provided}/*" "${_config_folder}" && \
	return 0 || return 1)

    # paste default config pvp
    [ ! -f "${_config_folder}/ServerSettings.ini" ] && \
	mkdir -p "${_config_folder}" && ( ([[ $CONANEXILES_SERVER_TYPE == "pve" ]] && \
					     server_settings_template_pve > "${_config_folder}/ServerSettings.ini" ) || \
						 server_settings_template_pvp > "${_config_folder}/ServerSettings.ini")
    return 0
}

server_settings_template_pvp() {
    echo """
[ServerSettings]
PVPEnabled=True
AdminPassword=ChangeMe
NPCMindReadingMode=0
MaxNudity=2
ServerCommunity=0
ConfigVersion=3
BlueprintConfigVersion=14
PlayerKnockbackMultiplier=1.000000
NPCKnockbackMultiplier=1.000000
StructureDamageMultiplier=1.000000
StructureDamageTakenMultiplier=1.000000
StructureHealthMultiplier=1.000000
NPCRespawnMultiplier=1.000000
NPCHealthMultiplier=1.000000
CraftingCostMultiplier=1.000000
PlayerDamageMultiplier=1.000000
PlayerDamageTakenMultiplier=1.000000
MinionDamageMultiplier=1.000000
MinionDamageTakenMultiplier=1.000000
NPCDamageMultiplier=1.000000
NPCDamageTakenMultiplier=1.000000
PlayerEncumbranceMultiplier=1.000000
PlayerEncumbrancePenaltyMultiplier=1.000000
PlayerMovementSpeedScale=1.000000
PlayerStaminaCostSprintMultiplier=1.000000
PlayerSprintSpeedScale=1.000000
PlayerStaminaCostMultiplier=1.000000
PlayerHealthRegenSpeedScale=1.000000
PlayerStaminaRegenSpeedScale=1.000000
PlayerXPRateMultiplier=1.000000
PlayerXPKillMultiplier=1.000000
PlayerXPHarvestMultiplier=1.000000
PlayerXPCraftMultiplier=1.000000
PlayerXPTimeMultiplier=1.000000
DogsOfTheDesertSpawnWithDogs=False
CrossDesertOnce=True
WeaponEffectBoundsShorteningFraction=0.200000
EnforceRotationRateWhenRoaming_2=True
EnforceRotationRateInCombat_2=True
ClipVelocityOnNavmeshBoundary=True
UnarmedNPCStepBackDistance=400.000000
PathFollowingAvoidanceMode=257
RotateToTargetSendsAngularVelocity=True
TargetPredictionMaxSeconds=1.000000
TargetPredictionAllowSecondsForAttack=0.400000
MaxAggroRange=9000.000000
serverRegion=256
LandClaimRadiusMultiplier=1.000000
ItemConvertionMultiplier=1.000000
PathFollowingSendsAngularVelocity=False
UnconsciousTimeSeconds=600.000000
ConciousnessDamageMultiplier=1.000000
ValidatePhysNavWalkWithRaycast=True
LocalNavMeshVisualizationFrequency=-1.000000
UseLocalQuadraticAngularVelocityPrediction=True
AvatarsDisabled=False
AvatarLifetime=60.000000
AvatarSummonTime=20.000000
IsBattlEyeEnabled=False
RegionAllowAfrica=True
RegionAllowAsia=True
RegionAllowCentralEurope=True
RegionAllowEasternEurope=True
RegionAllowWesternEurope=True
RegionAllowNorthAmerica=True
RegionAllowOceania=True
RegionAllowSouthAmerica=True
RegionBlockList=
bCanBeDamaged=True
CanDamagePlayerOwnedStructures=True
EnableSandStorm=True
ClanMaxSize=22
HarvestAmountMultiplier=1
ResourceRespawnSpeedMultiplier=1
"""
}

server_settings_template_pve() {
    echo """
[ServerSettings]
PVPEnabled=False
AdminPassword=ChangeMe
NPCMindReadingMode=0
MaxNudity=2
ServerCommunity=0
ConfigVersion=3
BlueprintConfigVersion=14
PlayerKnockbackMultiplier=1.000000
NPCKnockbackMultiplier=1.000000
StructureDamageMultiplier=1.000000
StructureDamageTakenMultiplier=1.000000
StructureHealthMultiplier=1.000000
NPCRespawnMultiplier=1.000000
NPCHealthMultiplier=1.000000
CraftingCostMultiplier=1.000000
PlayerDamageMultiplier=1.000000
PlayerDamageTakenMultiplier=1.000000
MinionDamageMultiplier=1.000000
MinionDamageTakenMultiplier=1.000000
NPCDamageMultiplier=1.000000
NPCDamageTakenMultiplier=1.000000
PlayerEncumbranceMultiplier=1.000000
PlayerEncumbrancePenaltyMultiplier=1.000000
PlayerMovementSpeedScale=1.000000
PlayerStaminaCostSprintMultiplier=1.000000
PlayerSprintSpeedScale=1.000000
PlayerStaminaCostMultiplier=1.000000
PlayerHealthRegenSpeedScale=1.000000
PlayerStaminaRegenSpeedScale=1.000000
PlayerXPRateMultiplier=1.700000
PlayerXPKillMultiplier=1.000000
PlayerXPHarvestMultiplier=1.000000
PlayerXPCraftMultiplier=1.000000
PlayerXPTimeMultiplier=1.000000
DogsOfTheDesertSpawnWithDogs=False
CrossDesertOnce=True
WeaponEffectBoundsShorteningFraction=0.200000
EnforceRotationRateWhenRoaming_2=True
EnforceRotationRateInCombat_2=True
ClipVelocityOnNavmeshBoundary=True
UnarmedNPCStepBackDistance=400.000000
PathFollowingAvoidanceMode=257
RotateToTargetSendsAngularVelocity=True
TargetPredictionMaxSeconds=1.000000
TargetPredictionAllowSecondsForAttack=0.400000
MaxAggroRange=9000.000000
serverRegion=1
LandClaimRadiusMultiplier=1.000000
ItemConvertionMultiplier=1.000000
PathFollowingSendsAngularVelocity=False
UnconsciousTimeSeconds=600.000000
ConciousnessDamageMultiplier=1.000000
ValidatePhysNavWalkWithRaycast=True
LocalNavMeshVisualizationFrequency=-1.000000
UseLocalQuadraticAngularVelocityPrediction=True
AvatarsDisabled=False
AvatarLifetime=60.000000
AvatarSummonTime=20.000000
IsBattlEyeEnabled=False
RegionAllowAfrica=True
RegionAllowAsia=True
RegionAllowCentralEurope=True
RegionAllowEasternEurope=True
RegionAllowWesternEurope=True
RegionAllowNorthAmerica=True
RegionAllowOceania=True
RegionAllowSouthAmerica=True
RegionBlockList=
bCanBeDamaged=True
CanDamagePlayerOwnedStructures=False
EnableSandStorm=True
ClanMaxSize=22
HarvestAmountMultiplier=1
ResourceRespawnSpeedMultiplier=1
EverybodyCanLootCorpse=False
"""
}

function override_config() {
    # workarround for whitespaces in env vars
    printenv | grep "$_env_variable_prefix" | grep -E "$_env_variable_filter" > /tmp/override_config.tmp
    env_arr=()
    while read -r line; do
	env_arr+=( "$line" )
    done < /tmp/override_config.tmp

    rm -f /tmp/override_config.tmp

    if [[ ${#env_arr[@]} -gt 0 ]]; then
	for env_variable in "${env_arr[@]}";do
        if [[ $env_variable =~ $_env_regex ]]
        then
            filename="${BASH_REMATCH[1]}.ini"
            section="${BASH_REMATCH[2]}"
            key="${BASH_REMATCH[3]}"
            value="${BASH_REMATCH[4]}"

            echo -e "\n>> Trying to create config in file $filename:: [$section]: $key=$value"

            # workaround for --set problem. Otherwise crudini will create multiple entries at container startup
            crudini --set --existing "${_config_folder}/${filename}" "${section}" "${key}" "${value}"
            [[ $? != 0 ]] && echo "Creating Config Entry" && crudini --set "${_config_folder}/${filename}" "${section}" "${key}" "${value}"
            fi
	done
    fi
}

init_master_server_instance
init_supervisor_conanexiles_cmd

grep "${_bashrc_tag_start}" /etc/bash.bashrc > /dev/null
[[ $? != 0 ]] && setup_bashrc

# Initial Installation
steamcmd_setup

setup_server_config_first_time

override_config

# start Xvfb
xvfb_display=0
rm -rf /tmp/.X$xvfb_display-lock
Xvfb :$xvfb_display -screen 0, 1024x768x24:32 -nolisten tcp &
export DISPLAY=:$xvfb_display

echo -n "Using WINE: "
wine --version

# TODO: Move to Dockerfile
mkdir -p /usr/share/wine/mono /usr/share/wine/gecko
test -f /usr/share/wine/mono/wine-mono-5.1.1-x86.msi || wget -q http://dl.winehq.org/wine/wine-mono/5.1.1/wine-mono-5.1.1-x86.msi -O /usr/share/wine/mono/wine-mono-5.1.1-x86.msi
test -f /usr/share/wine/gecko/wine-gecko-2.47.2-x86_64.msi || wget -q http://dl.winehq.org/wine/wine-gecko/2.47.2/wine-gecko-2.47.2-x86_64.msi -O /usr/share/wine/gecko/wine-gecko-2.47.2-x86_64.msi
test -f /usr/share/wine/gecko/wine-gecko-2.47.2-x86.msi || wget -q http://dl.winehq.org/wine/wine-gecko/2.47.2/wine-gecko-2.47.2-x86.msi -O /usr/share/wine/gecko/wine-gecko-2.47.2-x86.msi

wget http://crt.usertrust.com/USERTrustRSAAddTrustCA.crt -O /usr/local/share/ca-certificates/USERTrustRSAAddTrustCA.crt
update-ca-certificates

# start supervisord
"$@"
