#pragma semicolon 1

#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

#define DEBUG 1

public Plugin myinfo = 
{
	name = 			"[TF2] Money Vote",
	author = 			"Whai",
	description = 		"Vote the amount of money wanted to earn",
	version = 		PLUGIN_VERSION,
	url = 			"https://github.com/Wh4i/TF2MvM-MoneyVote/blob/master"
};

float g_fTimerInterval, g_fCountdownSec;

int	g_iFailRow, 
	g_iAmountGained, 
	g_iWaveFailedStart;
	
bool g_bCAnVote;
	
ArrayList g_hNumberItems;
ConVar g_hStartMoneyVote, g_hStartVoteInterval;


//int g_iTimer;
Handle g_hTimer[2];

public void OnPluginStart()
{
	RegConsoleCmd("sm_votemoney", Command_VoteMoney, "Initiate money vote panel");
	
	CreateConVar("sm_votemoney_version", PLUGIN_VERSION, "The plugin version", FCVAR_NOTIFY | FCVAR_SPONLY);
	
	g_hStartMoneyVote = CreateConVar("sm_votemoney_wavefailed", "3", "Start money vote once failed x times in row", FCVAR_NONE, true, 0.0);
	g_hStartMoneyVote.AddChangeHook(ConVarChanged);
	
	g_hStartVoteInterval = CreateConVar("sm_votemoney_interval", "10", "Start money vote in x seconds", FCVAR_NONE, true, 0.0);
	g_hStartVoteInterval.AddChangeHook(ConVarChanged);
	
	HookEvent("mvm_wave_complete", Event_WaveCompleted);
	HookEvent("mvm_wave_failed", Event_Wavefailed);
	HookEvent("mvm_reset_stats", Event_ResetStats);
}

public void ConVarChanged(ConVar hConVar, const char[] oldValue, const char[] newValue)
{
	if(hConVar == g_hStartMoneyVote)
		g_iWaveFailedStart = StringToInt(newValue);
		
	if(hConVar == g_hStartVoteInterval)
		g_fTimerInterval = StringToFloat(newValue);
}

public void OnConfigsExecuted()
{
	g_iWaveFailedStart = g_hStartMoneyVote.IntValue;
	g_fTimerInterval = g_hStartVoteInterval.FloatValue;
}

public void OnMapStart()
{
	g_iFailRow = 0;
	g_hNumberItems = new ArrayList();
	g_hNumberItems.Clear();
	g_iAmountGained = 0;
	g_bCAnVote = false;
	
	char strPath[PLATFORM_MAX_PATH], strMaps[256], strValue[10];
	int iSubKey = 0;
	bool bMapFound = false;
	
	BuildPath(Path_SM, strPath, sizeof(strPath), "configs/moneyvote_amount.txt");
	GetCurrentMap(strMaps, sizeof(strMaps));
	
	KeyValues kv = new KeyValues("MoneyAmount");
	if(!kv.ImportFromFile(strPath))
	{
		PrintToChatAll("[SM] Cannot read file to get value of the amount of the money");
		return;
	}
	
	if(!kv.GotoFirstSubKey(false))
	{
		delete kv;
		return;
	}
	
	char strBuffer[255];
	do
	{
		kv.GetSectionName(strBuffer, sizeof(strBuffer));
		#if DEBUG
		PrintToServer("[SECTION] : %s", strBuffer);
		#endif
		if(StrEqual(strBuffer, strMaps))
		{
			bMapFound = true;
			if(kv.JumpToKey("1"))
			{
				iSubKey = 0;
				do 
					iSubKey++;
				while(kv.GotoNextKey(false));
				
				kv.GoBack();
						
				
				#if DEBUG
				PrintToServer("{\n");
				#endif
				for(int i = 1; i <= iSubKey; i++)
				{
	
					IntToString(i, strValue, sizeof(strValue));
					g_hNumberItems.Push(kv.GetNum(strValue));
					
					#if DEBUG
					kv.GetSectionName(strBuffer, sizeof(strBuffer));
					PrintToServer("\t[1][MAP] : %s", strBuffer);
					PrintToServer("\t[1][INDEX] : %d --> VALUE : %d", i, kv.GetNum(strValue));
					#endif
				}
				#if DEBUG
				PrintToServer("}");
				#endif
				break;
			}
			else
			{
				kv.Rewind();
				kv.GotoFirstSubKey(false);
				do
				{
					kv.GetSectionName(strBuffer, sizeof(strBuffer));
					
					if(StrEqual(strBuffer, "*"))
					{
						if(kv.JumpToKey("1"))
						{
							iSubKey = 0;
							
							do 
								iSubKey++;
							while(kv.GotoNextKey(false));
							
							kv.GoBack();
							
							#if DEBUG
							PrintToServer("{\n");
							#endif
							for(int i = 1; i <= iSubKey; i++)
							{
								IntToString(i, strValue, sizeof(strValue));
								g_hNumberItems.Push(kv.GetNum(strValue));
								
								
								#if DEBUG
								kv.GetSectionName(strBuffer, sizeof(strBuffer));
								PrintToServer("\t[2][MAP] : %s", strBuffer);
								PrintToServer("\t[2][INDEX] : %d --> VALUE : %d", i, kv.GetNum(strValue));
								#endif
							}
							#if DEBUG
							PrintToServer("}");
							#endif
							break;
						}
					}
					else
					{
						PrintToServer("[SM] Cannot read the \"*\" section, ths may be corrupt or doesn't even exist");
						delete kv;
						return;
					}
				}
				while(kv.GotoNextKey());
				kv.GoBack();
			}
		}
	}
	while(kv.GotoNextKey(false));
	
	if(!bMapFound)
	{
		kv.Rewind();
		kv.GotoFirstSubKey(false);
		
		do 
		{
			kv.GetSectionName(strBuffer, sizeof(strBuffer));
			if(StrEqual(strBuffer, "*"))
			{
				if(kv.JumpToKey("1"))
				{
					iSubKey = 0;
					
					do 
						iSubKey++;
					while(kv.GotoNextKey(false));
						
					kv.GoBack();
					
					#if DEBUG
					PrintToServer("{\n");
					#endif
					for(int i = 1; i <= iSubKey; i++)
					{
						IntToString(i, strValue, sizeof(strValue));
						g_hNumberItems.Push(kv.GetNum(strValue));
						
						#if DEBUG
						kv.GetSectionName(strBuffer, sizeof(strBuffer));
						PrintToServer("\t[3][MAP] : %s", strBuffer);
						PrintToServer("\t[3][INDEX] : %d --> VALUE : %d", i, kv.GetNum(strValue));
						#endif
					}
					#if DEBUG
					PrintToServer("}");
					#endif
					break;
				}
			}
			else
			{
				PrintToServer("[SM] Cannot read the \"*\" section, ths may be corrupt or doesn't even exist");
				delete kv;
				return;
			}
		}
		while(kv.GotoNextKey(false));
	}
	#if DEBUG
	PrintToServer("[Array Size] : %d", g_hNumberItems.Length);
	#endif
	delete kv;
}

public void OnMapEnd()
{
	g_iFailRow = 0;
	g_hNumberItems.Clear();
	g_iAmountGained = 0;
	g_bCAnVote = false;
	
	for(int i; i < 2; i++)
	{
		if(g_hTimer[i] != INVALID_HANDLE)
		{
			delete g_hTimer[i];
			g_hTimer[i] = INVALID_HANDLE;
		}
	}
}

public void Event_WaveCompleted(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	g_iFailRow = 0;
	g_bCAnVote = false;
}

public void Event_Wavefailed(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	g_iFailRow++;
	
	if(g_iFailRow >= g_iWaveFailedStart)
	{
		PrintToChatAll("\x01[SM] The \x04money vote \x01is now available : !votemoney");
		g_bCAnVote = true;
		g_iFailRow = 0;
	}
}

public void Event_ResetStats(Event hEvent, const char[] strName, bool bDontBroadcast)	// Vote to restart the mission
{
	g_iFailRow = 0;
	g_bCAnVote = false;
	for(int i; i < 2;i++)
	{
		if(g_hTimer[i] != INVALID_HANDLE)
		{
			delete g_hTimer[i];
			g_hTimer[i] = INVALID_HANDLE;
		}
	}
}

public Action Command_VoteMoney(int iClient, int iArgs)
{
	if(!iArgs)
	{
		if(g_bCAnVote)
		{
			for(int i; i < 2;i++)
			{
				if(g_hTimer[i] != INVALID_HANDLE)
				{
					delete g_hTimer[i];
					g_hTimer[i] = INVALID_HANDLE;
				}
			}
			PrintCenterTextAll("The money vote will begin in : %0.f", g_fTimerInterval);
			g_hTimer[0] = CreateTimer(g_fTimerInterval, MoneyVoteTimer);
			g_hTimer[1] = CreateTimer(1.0, MoneyVoteTimerCountdown, _, TIMER_REPEAT);
			//g_iTimer = GetEngineTime();
			g_bCAnVote = false;
		}
	}
	else
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_votemoney");
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action MoneyVoteTimer(Handle hTimer)
{
	DisplayMoneyVote();
	
	g_hTimer[0] = INVALID_HANDLE;
}

public Action MoneyVoteTimerCountdown(Handle hTimer)
{
	if(g_fCountdownSec >= g_fTimerInterval)
	{
		g_fCountdownSec = 0.0;
		g_hTimer[1] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	g_fCountdownSec++;
	
	if(g_fTimerInterval > g_fCountdownSec)
		PrintCenterTextAll("The money vote will begin in : %0.f", g_fTimerInterval - g_fCountdownSec);
	
	return Plugin_Continue;
}

void DisplayMoneyVote()
{
	if(IsVoteInProgress())
		return;

	char strItemIndex[10];
	Menu menu = new Menu(MenuHandle);
	menu.VoteResultCallback = Handle_VoteResults;
	menu.SetTitle("Vote the amount of cash (you have 30s):");
	for(int iItem; iItem < g_hNumberItems.Length; iItem++)
	{
		IntToString(g_hNumberItems.Get(iItem) , strItemIndex, sizeof(strItemIndex));
		menu.AddItem(strItemIndex, strItemIndex);
	}
	menu.AddItem("0", "0 - No, thanks");
	menu.ExitButton = false;
	menu.DisplayVoteToAll(30);
}

public int MenuHandle(Menu hMenu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End: delete hMenu;
	}
}

public void Handle_VoteResults(Menu hMenu, int iNumVotes, int iNumClients, const int[][] iClientInfo, int iNumItems, const int[][] iItemInfo)
{
	int i2 = 0;
	if(iNumItems > 1)
	{
		for(int i = 1; i < iNumItems; i++)
		{
			if(iItemInfo[0][VOTEINFO_ITEM_VOTES] == iItemInfo[i][VOTEINFO_ITEM_VOTES]) // Note: iItemInfo[0][VOTEINFO_ITEM_VOTES] means the winner item's number of vote
			{
				i2 = i;
			}
		}
	}
	
	i2 = GetRandomInt(0, i2);
		
	char strBuffer[10];
	int iBuffer;
	hMenu.GetItem(iItemInfo[i2][VOTEINFO_ITEM_INDEX], strBuffer, sizeof(strBuffer));
	iBuffer = StringToInt(strBuffer);
	
	for(int iPlayers = 1; iPlayers <= MaxClients; iPlayers++)
	{
		if(IsValidClient(iPlayers, true))
			AddClientCash(iPlayers, iBuffer);
	}
	g_iAmountGained +=  iBuffer;
	PrintHintTextToAll("You earned : \n%i cash", iBuffer);
}

void AddClientCash(int iClient, int iAmount)
{
	SetEntProp(iClient, Prop_Send, "m_nCurrency", GetClientCash(iClient) + iAmount);
}

int GetClientCash(int iClient)
{
	return GetEntProp(iClient, Prop_Send, "m_nCurrency");
}

stock bool IsEntityClient(int iEntity)
{
	if(1 <= iEntity <= MaxClients)
		return true;
	
	return false;
}

stock bool IsValidClient(int iEntity, bool bFilterBots = false, bool bFilterSourceTV = true, bool bFilterAlive = true)
{
	if(!IsEntityClient(iEntity))
		return false;
	
	if(!IsClientInGame(iEntity))
		return false;
	
	if(bFilterAlive)
	{
		if(!IsPlayerAlive(iEntity))
			return false;
	}
	
	if(bFilterSourceTV)
	{
		if(IsClientSourceTV(iEntity) || IsClientReplay(iEntity))
			return false;
	}
	
	if(bFilterBots)
	{
		if(IsFakeClient(iEntity))
			return false;
	}
		
	return true;
}
