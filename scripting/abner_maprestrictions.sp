#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define MAX_MAP_NAME_LENGTH 64

enum struct Messages
{
	int lessthan;
	int morethan;
	char text[64];
}

enum struct Props
{
	int lessthan;
	int morethan;
	float origin[3];
	float angles[3];
}

Handle g_hTimer;

ArrayList g_hProps;
ArrayList g_hMessages;
ArrayList g_hSpawnedProps;

ConVar mp_freezetime;
float g_fFreezetime;

char g_sModel[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name 			= "[FIX] AbNeR Map Restrictions",
	author		    = "abnerfs, NiGHT",
	description 	= "Area restrictions in maps.",
	version 		= "2.2",
	url 			= "https://github.com/NiGHT757/maprestrictions"
}

public void OnPluginStart()
{
	mp_freezetime	 = FindConVar("mp_freezetime");
	mp_freezetime.AddChangeHook(OnSettingsChanged);

	g_hProps = new ArrayList(sizeof(Props));
	g_hMessages = new ArrayList(sizeof(Messages));
	g_hSpawnedProps = new ArrayList(ByteCountToCells(8));

	HookEvent("round_start", EventRoundStart, EventHookMode_PostNoCopy);
	RegAdminCmd("sm_props_refresh", cmd_reloadprops, ADMFLAG_ROOT);
	RegAdminCmd("sm_props_reloadconfig", cmd_reloadconfig, ADMFLAG_RCON);
}

public void OnConfigsExecuted()
{
	g_fFreezetime = mp_freezetime.FloatValue;
}

public void OnSettingsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fFreezetime = mp_freezetime.FloatValue;
}

public void OnMapStart()
{
	g_hTimer = null;
	LoadConfig();
}

public void EventRoundStart(Event event, const char[] name, bool db)
{
	delete g_hTimer;
	g_hTimer = CreateTimer(g_fFreezetime, timer_reloadprops, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action cmd_reloadprops(int client, int args){
	ReplyToCommand(client, "\x02»» \x01Props reloaded successfully");
	ClearProps();
	CreateProps();
	
	return Plugin_Handled;
}

public Action cmd_reloadconfig(int client, int args){
	ReplyToCommand(client, " \x02»» \x01Config reloaded successfully");
	LoadConfig();

	return Plugin_Handled;
}

public Action timer_reloadprops(Handle timer)
{
	ClearProps();
	CreateProps();

	g_hTimer = null;
	return Plugin_Continue;
}

void CreateProps()
{
	if(!g_hProps.Length)
		return;
	
	int iPlayerCount = GetTeamClientCount(3) + GetTeamClientCount(2);
	
	Messages data;
	char sMessage[64];
	for(int i = 0; i < g_hMessages.Length; i++)
	{
		g_hMessages.GetArray(i, data, sizeof(data));
		
		if(iPlayerCount > data.morethan && (data.lessthan == 0 || iPlayerCount < data.lessthan))
			strcopy(sMessage, sizeof(sMessage), data.text);
	}

	if(sMessage[0])
		PrintToChatAll(" \x02»» \x01Players: \x0F%d\x01 x \x0B%d\x01 - \x04%s", GetTeamClientCount(2), GetTeamClientCount(3), sMessage);
	
	int iEnt;
	Props props; 
	for(int i = 0; i < g_hProps.Length; i++)
	{
		g_hProps.GetArray(i, props, sizeof(props));
		
		if(iPlayerCount > props.morethan && (props.lessthan == 0 || iPlayerCount < props.lessthan))
		{
			iEnt = CreateEntityByName("prop_physics_override"); 
					
			DispatchKeyValue(iEnt, "physdamagescale", "0.0");
			DispatchKeyValue(iEnt, "model", g_sModel);

			DispatchSpawn(iEnt);
			SetEntityMoveType(iEnt, MOVETYPE_PUSH);
			
			TeleportEntity(iEnt, props.origin, props.angles, NULL_VECTOR);
			g_hSpawnedProps.Push(EntIndexToEntRef(iEnt));
		}
	}
}

void ClearProps()
{
	int iEnt;
	for(int i = 0; i < g_hSpawnedProps.Length; i++)
	{
		iEnt = EntRefToEntIndex(g_hSpawnedProps.Get(i));
		if (iEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEnt))
		{
			RemoveEntity(iEnt);
		}
	}
	g_hSpawnedProps.Clear();
}

void LoadConfig()
{
	g_hMessages.Clear();
	g_hProps.Clear();

	char sPath[PLATFORM_MAX_PATH];
	char sMap[MAX_MAP_NAME_LENGTH];

	GetCurrentMap(sMap, sizeof(sMap));
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/abner_maprestrictions/%s.ini", sMap);

	if(!FileExists(sPath))
		return;
	
	KeyValues kv = new KeyValues(sMap);

	if (!kv.ImportFromFile(sPath))
	{
		return;
	}

	kv.GetString("model", g_sModel, sizeof(g_sModel), "models/props_wasteland/exterior_fence001b.mdl");
	if(PrecacheModel(g_sModel, true) == 0)
		SetFailState("[MapRestrictions] - Error precaching model '%s'", g_sModel);
	
	if(kv.JumpToKey("messages") && kv.GotoFirstSubKey())
	{
		Messages data;
		do{
			data.morethan = kv.GetNum("morethan");
			data.lessthan = kv.GetNum("lessthan");

			kv.GetString("message", data.text, sizeof(data.text));

			g_hMessages.PushArray(data);
		}
		while(kv.GotoNextKey());
		kv.Rewind();
	}
	if(kv.GotoFirstSubKey())
	{
		kv.GotoNextKey();
		Props props;
		do{
			props.lessthan = kv.GetNum("lessthan");
			props.morethan = kv.GetNum("morethan");

			kv.GetVector("origin", props.origin);
			kv.GetVector("angles", props.angles);

			g_hProps.PushArray(props, sizeof(props));
		}
		while(kv.GotoNextKey());
	}

	delete kv;
}