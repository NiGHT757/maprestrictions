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

ArrayList g_hProps;
ArrayList g_hMessages;
ArrayList g_hSpawnedProps;

char g_sModel[PLATFORM_MAX_PATH];

int g_iPropsLength;
int g_iMessagesLength;

public Plugin myinfo =
{
	name 			= "[FIX] AbNeR Map Restrictions",
	author		    = "abnerfs, NiGHT",
	description 	= "Area restrictions in maps.",
	version 		= "2.3",
	url 			= "https://github.com/NiGHT757/maprestrictions"
}

public void OnPluginStart()
{
	g_hProps = new ArrayList(sizeof(Props));
	g_hMessages = new ArrayList(sizeof(Messages));
	g_hSpawnedProps = new ArrayList();

	HookEvent("round_freeze_end", Event_RoundFreezeEnd, EventHookMode_PostNoCopy);

	RegAdminCmd("sm_props_refresh", cmd_reloadprops, ADMFLAG_ROOT);
	RegAdminCmd("sm_props_reloadconfig", cmd_reloadconfig, ADMFLAG_RCON);
}

public void OnMapStart()
{
	LoadConfig();
}

void Event_RoundFreezeEnd(Event event, const char[] name, bool db)
{
	ClearProps();
	CreateProps();
}

Action cmd_reloadprops(int client, int args){
	ReplyToCommand(client, "\x02»» \x01Props reloaded successfully");
	ClearProps();
	CreateProps();
	
	return Plugin_Handled;
}

Action cmd_reloadconfig(int client, int args){
	ReplyToCommand(client, " \x02»» \x01Config reloaded successfully");
	LoadConfig();

	return Plugin_Handled;
}

void CreateProps()
{
	if(!g_iPropsLength || GameRules_GetProp("m_bWarmupPeriod"))
		return;
	
	int iPlayerCount = GetTeamClientCount(3) + GetTeamClientCount(2);
	
	Messages data;
	char sMessage[64];
	for(int i = 0; i < g_iMessagesLength; i++)
	{
		g_hMessages.GetArray(i, data, sizeof(data));
		
		if(iPlayerCount > data.morethan && (data.lessthan == 0 || iPlayerCount < data.lessthan))
			strcopy(sMessage, sizeof(sMessage), data.text);
	}

	if(sMessage[0])
		PrintToChatAll(" \x02»» \x01Players: \x0F%d\x01 x \x0B%d\x01 - \x04%s", GetTeamClientCount(2), GetTeamClientCount(3), sMessage);
	
	int iEnt;
	Props props; 
	for(int i = 0; i < g_iPropsLength; i++)
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
			SetEntityRenderMode(iEnt, RENDER_TRANSALPHA);
			SetEntityRenderColor(iEnt, 255, 255, 255, 0);
			g_hSpawnedProps.Push(EntIndexToEntRef(iEnt));
		}
	}
}

void ClearProps()
{
	int iEnt;
	for(int i = 0, iLength = g_hSpawnedProps.Length; i < iLength; i++)
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
	g_iPropsLength = 0;
	g_iMessagesLength = 0;

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

	g_iMessagesLength = g_hMessages.Length;
	g_iPropsLength = g_hProps.Length;

	delete kv;
}