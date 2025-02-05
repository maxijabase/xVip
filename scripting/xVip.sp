#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <autoexecconfig>
#include <timeparser>
#include <xVip>

#pragma newdecls required

#define PLUGIN_VERSION "1.0"

#define TABLE_VIPS "xVip_vips"
#define TABLE_LOGS "xVip_logs"
#define TABLE_WEB_ADMINS "xVip_web_admins"
#define TABLE_WEB_CONFIG "xVip_web_config"
#define TABLE_WEB_ROLES "xVip_web_roles"

char dbconfig[] = "xVip";
Database g_DB;

ConVar g_cvFlags;
char g_cFlags[20];

ConVar g_cvPrefix;
char g_cPrefix[64];

bool g_bIsVip[1024] = { false, ... };
bool g_Late;

public Plugin myinfo = 
{
  name = "xVip", 
  author = "ampere", 
  description = "An automatic VIP system, built upon tVip by Totenfluch.", 
  version = PLUGIN_VERSION, 
  url = "https://github.com/maxijabase"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
  RegPluginLibrary("xVip");
  CreateNative("xVip_IsVip", Native_IsVip);
  CreateNative("xVip_GetPrefix", Native_GetPrefix);

  g_Late = late;
  return APLRes_Success;
}

public void OnPluginStart()
{
  Database.Connect(SQL_OnConnection, dbconfig);
  
  AutoExecConfig_SetFile("xVip");
  AutoExecConfig_SetCreateFile(true);
  
  g_cvFlags = AutoExecConfig_CreateConVar("xVip_flags", "p", "Flags to assign to VIPs. I recommend using custom flags. Check https://wiki.alliedmods.net/Adding_Admins_(SourceMod)#Levels for more info.");
  g_cvPrefix = AutoExecConfig_CreateConVar("xVip_prefix", "{orange}[xVip]{default}", "Prefix for xVip messages.");
  g_cvFlags.AddChangeHook(OnCvarChanged);
  g_cvPrefix.AddChangeHook(OnCvarChanged);

  AutoExecConfig_CleanFile();
  AutoExecConfig_ExecuteFile();
  
  RegAdminCmd("sm_addvip", CMD_AddVip, ADMFLAG_GENERIC, "Adds a VIP. Usage: sm_addvip <steamid> [duration]");
  RegAdminCmd("sm_removevip", CMD_RemoveVip, ADMFLAG_GENERIC, "Removes a VIP. Usage: sm_removevip <steamid>");
  RegAdminCmd("sm_extendvip", CMD_ExtendVip, ADMFLAG_GENERIC, "Extends a VIP. Usage: sm_extendvip <steamid> [duration]");
  RegConsoleCmd("sm_vip", CMD_Vip, "Opens the Vip Menu");

  LoadTranslations("common.phrases");
}

public void OnCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
  g_cvFlags.GetString(g_cFlags, sizeof(g_cFlags));
  g_cvPrefix.GetString(g_cPrefix, sizeof(g_cPrefix));
}

public void SQL_OnConnection(Database db, const char[] error, any data)
{
  if (db == null)
  {
    SetFailState("[xVip] Error connecting to database: \"%s\"", error);
  }
  
  g_DB = db;
  g_DB.SetCharset("utf8");
  CreateTables();

  if (g_Late) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsValidClient(i)) {
        OnClientPostAdminCheck(i);
      }
    }
  }

}

void CreateTables()
{
  DataPack pack = new DataPack();
  char createTableQuery[4096] = 
  "CREATE TABLE IF NOT EXISTS `xVip_vips` ( \
 		`id` int NOT NULL AUTO_INCREMENT, \
  		`name` varchar(36) COLLATE utf8_bin NOT NULL, \
  		`steamid` varchar(20) COLLATE utf8_bin NOT NULL, \
  		`startdate` int NOT NULL DEFAULT CURRENT_TIMESTAMP, \
  		`enddate` int NOT NULL DEFAULT CURRENT_TIMESTAMP, \
  		`admin_name` varchar(36) COLLATE utf8_bin NOT NULL, \
  		`admin_steamid` varchar(20) COLLATE utf8_bin NOT NULL, \
 		 PRIMARY KEY (`id`), \
  		 UNIQUE KEY `steamid` (`steamid`)  \
  		 ) ENGINE = InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;";
  pack.WriteString("Created table 'xVip_vips'");
  g_DB.Query(SQL_OnTableCreated, createTableQuery, pack);
  
  char createVipLogsTableQuery[] = 
  "CREATE TABLE IF NOT EXISTS xVip_logs ( \
    id int NOT NULL AUTO_INCREMENT, \
    action_type ENUM('add', 'remove', 'extend', 'expire', 'payment_mp', 'payment_items') NOT NULL, \
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, \
    target_name VARCHAR(36) COLLATE utf8_bin NOT NULL, \
    target_steamid VARCHAR(20) COLLATE utf8_bin NOT NULL, \
    admin_name VARCHAR(36) COLLATE utf8_bin NOT NULL, \
    admin_steamid VARCHAR(20) COLLATE utf8_bin NOT NULL, \
    duration INT, \
    payment_id VARCHAR(50), \
    payment_amount DECIMAL(10,2), \
    payment_currency VARCHAR(3), \
    items_details TEXT, \
    transaction_status VARCHAR(20), \
    PRIMARY KEY (id)) \
    ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;";
  pack = new DataPack();
  pack.WriteString("Created table 'xVip_logs'");
  g_DB.Query(SQL_OnTableCreated, createVipLogsTableQuery, pack);

  char createRolesTableQuery[] = 
  "CREATE TABLE IF NOT EXISTS `xVip_web_roles` ( \
    `id` int NOT NULL AUTO_INCREMENT, \
    `role_name` varchar(32) COLLATE utf8_bin NOT NULL, \
    `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, \
    PRIMARY KEY (`id`), \
    UNIQUE KEY `role_name` (`role_name`) \
    ) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;";
  pack = new DataPack();
  pack.WriteString("Created table 'xVip_web_roles'");
  g_DB.Query(SQL_OnTableCreated, createRolesTableQuery, pack);

  char insertDefaultRolesQuery[] = 
  "INSERT IGNORE INTO `xVip_web_roles` (`role_name`) VALUES \
    ('admin'), \
    ('owner');";
  pack = new DataPack();
  pack.WriteString("Inserted default web roles.");
  g_DB.Query(SQL_OnTableCreated, insertDefaultRolesQuery, pack);
  
  char createAdminsTableQuery[] = 
  "CREATE TABLE IF NOT EXISTS `xVip_web_admins` ( \
    `id` int NOT NULL AUTO_INCREMENT, \
    `steamid` varchar(17) COLLATE utf8_bin NOT NULL, \
    `name` varchar(36) COLLATE utf8_bin NOT NULL, \
    `roleid` int NOT NULL, \
    `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, \
    PRIMARY KEY (`id`), \
    UNIQUE KEY `steamid` (`steamid`), \
    FOREIGN KEY (`roleid`) REFERENCES `xVip_web_roles`(`id`) ON DELETE RESTRICT \
    ) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;";
  pack = new DataPack();
  pack.WriteString("Created table 'xVip_web_admins'");
  g_DB.Query(SQL_OnTableCreated, createAdminsTableQuery, pack);
}

public void OnConfigsExecuted() {
  g_cvFlags.GetString(g_cFlags, sizeof(g_cFlags));
  g_cvPrefix.GetString(g_cPrefix, sizeof(g_cPrefix));
}

/* CHECK VIP */

public Action CMD_Vip(int client, int args) {
  if (g_DB == null)
  {
    xVip_Reply(client, "Database not connected. Try again later.");
    return Plugin_Handled;
  }

  if (client == 0)
  {
    int count;
    for (int i = 1; i <= MaxClients; i++)
    {
      if (g_bIsVip[i])
      {
        char steamid[20];
        if (!GetClientAuthId(i, AuthId_SteamID64, steamid, sizeof(steamid)))
        {
          xVip_Reply(0, "Error retrieving SteamID for %N.", i);
          continue;
        }
        count++;
        char name[MAX_NAME_LENGTH];
        GetClientName(i, name, sizeof(name));
        xVip_Reply(0, "%N (%s) is a VIP.", name, steamid);
      }
    }
    if (count == 0)
    {
      xVip_Reply(0, "No VIPs currently connected.");
    }
    return Plugin_Handled;
  }


  int userid = GetClientUserId(client);
  if (g_bIsVip[userid])
  {
    char steamid[20];
    if (!GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid)))
    {
      xVip_Reply(client, "Error retrieving your SteamID. Try again later.");
      return Plugin_Handled;
    }
    
    char query[1024];
    Format(query, sizeof(query), "SELECT startdate, enddate, enddate - UNIX_TIMESTAMP() as timeleft FROM xVip_vips WHERE steamid = '%s';", steamid);
    
    g_DB.Query(SQL_OnVipInfoReceived, query, client);
  }
  else
  {
    xVip_Reply(client, "You are not a VIP.");
  }

  return Plugin_Handled;
}

public void SQL_OnVipInfoReceived(Database db, DBResultSet results, const char[] error, any data) {
  int client = data;
  int started;
  int ends;
  int left;
  while (results.FetchRow()) {
    started = results.FetchInt(0);
    ends = results.FetchInt(1);
    left = results.FetchInt(2);
  }
  
  char duration[64];
  FormatDuration(left, duration, sizeof(duration));
  
  char startDate[64];
  FormatTime(startDate, sizeof(startDate), "%b %d, %Y - %R", started);

  char endDate[64];
  FormatTime(endDate, sizeof(endDate), "%b %d, %Y - %R", ends);

  Panel panel = new Panel();
  panel.SetTitle("Your VIP Information");
  panel.DrawText(" ");

  char start[64];
  Format(start, sizeof(start), "Start Date: %s", startDate);
  panel.DrawText(start);

  char end[64];
  Format(end, sizeof(end), "End Date: %s", endDate);
  panel.DrawText(end);

  char timeleft[64];
  Format(timeleft, sizeof(timeleft), "Time Left: %s", duration);
  panel.DrawText(timeleft);
  panel.DrawText(" ");

  panel.CurrentKey = 10;
  panel.DrawItem("Close");
  panel.Send(client, VipPanelMenuHandler, 30);
}

public int VipPanelMenuHandler(Handle menu, MenuAction action, int client, int item) {
  return 0;
}

/* ADD VIP */

public Action CMD_AddVip(int client, int args) {
  // Check arguments
  if (args < 1) {
    xVip_Reply(client, "Usage: sm_addvip <steamid|target> [duration] [name].");
    xVip_Reply(client, "Example: sm_addvip 76561198179807307 30d.");
    return Plugin_Handled;
  }
  
  // Get first argument (target)
  char arg_steamid[20];
  GetCmdArg(1, arg_steamid, sizeof(arg_steamid));
  if (SimpleRegexMatch(arg_steamid, "^7656119[0-9]{10}$") == 0) {
    int target = FindTarget(client, arg_steamid, .immunity = false);
    if (target == -1) {
      return Plugin_Handled;
    }
    if (g_bIsVip[GetClientUserId(target)]) {
      xVip_Reply(client, "%N is already a VIP.", target);
      return Plugin_Handled;
    }
    if (!GetClientAuthId(target, AuthId_SteamID64, arg_steamid, sizeof(arg_steamid)))
    {
      xVip_Reply(client, "Error retrieving target's SteamID.");
      return Plugin_Handled;
    }
  }

  // Get userid from first argument
  int user_userid = GetUserIDBySteamID(arg_steamid);
  int user_client = GetClientOfUserId(user_userid);

  // Get second argument (duration)
  char arg_duration[8];
  int enddate;
  GetCmdArg(2, arg_duration, sizeof(arg_duration));
  if (arg_duration[0] == '\0') {
    enddate = ParseTime("30d");
  } else {
    enddate = ParseTime(arg_duration);
    if (enddate <= 0)
    {
      xVip_Reply(client, "Invalid duration. Usage: [number][d|m|y] (30d, 60m, 1y).");
      return Plugin_Handled;
    }
  }

  // Get third argument (name)
  char arg_name[32];
  GetCmdArg(3, arg_name, sizeof(arg_name));
  if (arg_name[0] == '\0')
  {
    if (user_client > 0)
    {
      GetClientName(user_client, arg_name, sizeof(arg_name));
    }
    else
    {
      xVip_Reply(client, "If you manually inserted a Steam ID, you must provide a name.");
      return Plugin_Handled;
    }
  }

  // Get admin info
  char admin_name[64];
  char admin_steamid[20];
  int admin_userid;
  if (client == 0)
  {
    admin_name = "CONSOLE";
    admin_steamid = "CONSOLE";
    admin_userid = 0;
  }
  else
  {
    if (!GetClientAuthId(client, AuthId_SteamID64, admin_steamid, sizeof(admin_steamid)))
    {
      xVip_Reply(client, "Error retrieving your SteamID. Admin will only be saved with name.");
    }
    GetClientName(client, admin_name, sizeof(admin_name));
    admin_userid = GetClientUserId(client);
  }

  // Add VIP
  AddVip(user_userid, arg_steamid, arg_name, enddate, admin_userid, admin_steamid, admin_name);
  return Plugin_Handled;
}

void AddVip(int user_userid, const char[] user_steamid, const char[] user_name, int enddate, int admin_userid, const char[] admin_steamid, const char[] admin_name) {
  char query[1024];
  g_DB.Format(query, sizeof(query), 
    "INSERT INTO xVip_vips "...
    "(name, steamid, startdate, enddate, admin_name, admin_steamid) "...
    "VALUES ('%s', '%s', UNIX_TIMESTAMP(), %d, '%s', '%s');",
    user_name, user_steamid, enddate, admin_name, admin_steamid);

  DataPack pack = new DataPack();
  pack.WriteString(user_name);
  pack.WriteCell(user_userid);
  pack.WriteString(user_steamid);
  pack.WriteCell(enddate);
  pack.WriteString(admin_name);
  pack.WriteCell(admin_userid);
  pack.WriteString(admin_steamid);
  g_DB.Query(SQL_OnVipAdded, query, pack);
}

public void SQL_OnVipAdded(Database db, DBResultSet results, const char[] error, DataPack pack) {
  pack.Reset();
  char user_name[32];
  pack.ReadString(user_name, sizeof(user_name));
  int user_userid = pack.ReadCell();
  char user_steamid[20];
  pack.ReadString(user_steamid, sizeof(user_steamid));
  int enddate = pack.ReadCell();
  char admin_name[64];
  pack.ReadString(admin_name, sizeof(admin_name));
  int admin_userid = pack.ReadCell();
  char admin_steamid[20];
  pack.ReadString(admin_steamid, sizeof(admin_steamid));
  delete pack;

  int duration = enddate - GetTime();
  char durationStr[64];
  FormatDuration(duration, durationStr, sizeof(durationStr));

  char endDate[64];
  FormatTime(endDate, sizeof(endDate), "%b %d, %Y - %R", enddate);
  
  int admin_client = GetClientOfUserId(admin_userid);
  xVip_Reply(admin_client, "Added %s (%s) as VIP. Duration: %s", user_name, user_steamid, durationStr);

  LogVipAction("add", user_name, user_steamid, admin_name, admin_steamid, duration);

  SetVipFlags(user_userid);
  g_bIsVip[user_userid] = true;
}

/* REMOVE VIP */

public Action CMD_RemoveVip(int client, int args) {
  if (args != 1) {
    xVip_Reply(client, "Usage: sm_removevip <steamid|target>.");
    return Plugin_Handled;
  }
  
  char steamIdInput[20];
  GetCmdArg(1, steamIdInput, sizeof(steamIdInput));
  if (SimpleRegexMatch(steamIdInput, "^7656119[0-9]{10}$") == 0) {
    int target = FindTarget(client, steamIdInput, .immunity = false);
    if (target == -1) {
      return Plugin_Handled;
    }
    if (!GetClientAuthId(target, AuthId_SteamID64, steamIdInput, sizeof(steamIdInput)))
    {
      xVip_Reply(client, "Error retrieving target's SteamID.");
      return Plugin_Handled;
    }
  }

  int admin_userid = 0;
  if (client > 0) {
    admin_userid = GetClientUserId(client);
  }
  
  RemoveVip(admin_userid, steamIdInput);
  return Plugin_Handled;
}

public void RemoveVip(int userid, const char[] steamid) {
  char query[512];
  Format(query, sizeof(query), "SELECT name FROM xVip_vips WHERE steamid = '%s';", steamid);
  DataPack pack = new DataPack();
  pack.WriteCell(userid);
  pack.WriteString(steamid);
  g_DB.Query(SQL_OnVipSelectedForRemoval, query, pack);
}

public void SQL_OnVipSelectedForRemoval(Database db, DBResultSet results, const char[] error, DataPack pack) {
  pack.Reset();
  int userid = pack.ReadCell();
  char steamid[20];
  pack.ReadString(steamid, sizeof(steamid));

  if (results.RowCount == 0) {
    int admin_client = GetClientOfUserId(userid);
    xVip_Reply(admin_client, "No VIP found with SteamID: %s", steamid);
    return;
  }
  
  results.FetchRow();
  char name[MAX_NAME_LENGTH];
  results.FetchString(0, name, sizeof(name));
  pack.WriteString(name);

  char query[512];
  Format(query, sizeof(query), "DELETE FROM xVip_vips WHERE steamid = '%s';", steamid);
  g_DB.Query(SQL_OnVipDeleted, query, pack);
}

public void SQL_OnVipDeleted(Database db, DBResultSet results, const char[] error, DataPack pack) {
  pack.Reset();
  int admin_userid = pack.ReadCell();
  char user_steamid[20];
  pack.ReadString(user_steamid, sizeof(user_steamid));
  char user_name[MAX_NAME_LENGTH];
  pack.ReadString(user_name, sizeof(user_name));
  delete pack;

  if (error[0] != '\0') {
    LogError("Failed to delete VIP: %s", error);
    return;
  }

  char admin_name[64];
  char admin_steamid[20];

  int admin_client = GetClientOfUserId(admin_userid);
  xVip_Reply(admin_client, "Successfully removed %s's VIP (%s).", user_name, user_steamid);
  if (admin_userid == 0) {
    admin_name = "CONSOLE";
    admin_steamid = "CONSOLE";
  } else {
    if (admin_client) {
      GetClientName(admin_client, admin_name, sizeof(admin_name));
      GetClientAuthId(admin_client, AuthId_SteamID64, admin_steamid, sizeof(admin_steamid));
    }
  }

  int user_userid = GetUserIDBySteamID(user_steamid);
  if (user_userid) {
    RemoveVipFlags(user_userid);
    g_bIsVip[user_userid] = false;
  }

  LogVipAction("remove", user_name, user_steamid, admin_name, admin_steamid);
}

/* EXTEND VIP */

public Action CMD_ExtendVip(int client, int args) {
  if (args < 1) {
    xVip_Reply(client, "Usage: sm_extendvip <steamid|target> [duration]");
    return Plugin_Handled;
  }
  
  // Get first argument (target)
  char steamIdInput[20];
  GetCmdArg(1, steamIdInput, sizeof(steamIdInput));
  if (SimpleRegexMatch(steamIdInput, "^7656119[0-9]{10}$") == 0) {
    int target = FindTarget(client, steamIdInput, .immunity = false);
    if (target == -1) {
      return Plugin_Handled;
    }
    if (!g_bIsVip[GetClientUserId(target)]) {
      xVip_Reply(client, "Target is not a VIP.");
      return Plugin_Handled;
    }
    if (!GetClientAuthId(target, AuthId_SteamID64, steamIdInput, sizeof(steamIdInput)))
    {
      xVip_Reply(client, "Error retrieving target's SteamID.");
      return Plugin_Handled;
    }
  }

  // Get second argument (duration)
  char duration[8];
  GetCmdArg(2, duration, sizeof(duration));
  int extension_seconds;
  
  if (duration[0] == '\0') {
    extension_seconds = 30 * 24 * 60 * 60;  // 30 days
  } else {
    int currentTime = GetTime();
    int futureTime = ParseTime(duration);
    if (futureTime < 0) {
      xVip_Reply(client, "Invalid duration. Usage: [number][d|m|y] (30d, 60m, 1y).");
      return Plugin_Handled;
    }
    extension_seconds = futureTime - currentTime;
  }

  // Get admin info
  char admin_name[64];
  char admin_steamid[20];
  int admin_userid;
  if (client == 0)
  {
    admin_name = "CONSOLE";
    admin_steamid = "CONSOLE";
    admin_userid = 0;
  }
  else
  {
    if (!GetClientAuthId(client, AuthId_SteamID64, admin_steamid, sizeof(admin_steamid)))
    {
      xVip_Reply(client, "Error retrieving your SteamID. Admin will only be saved with name.");
    }
    GetClientName(client, admin_name, sizeof(admin_name));
    admin_userid = GetClientUserId(client);
  }

  ExtendVip(admin_userid, steamIdInput, extension_seconds, admin_steamid, admin_name);
  return Plugin_Handled;
}

void ExtendVip(int admin_userid, const char[] steamid, int extension_seconds, const char[] admin_steamid, const char[] admin_name) {
  char query[1024];
  Format(query, sizeof(query), "SELECT name, enddate FROM xVip_vips WHERE steamid = '%s';", steamid);
  DataPack pack = new DataPack();
  pack.WriteCell(admin_userid);
  pack.WriteString(steamid);
  pack.WriteCell(extension_seconds);
  pack.WriteString(admin_steamid);
  pack.WriteString(admin_name);
  g_DB.Query(SQL_OnVipSelectedForExtension, query, pack);
}

public void SQL_OnVipSelectedForExtension(Database db, DBResultSet results, const char[] error, DataPack pack) {
  pack.Reset();
  int admin_userid = pack.ReadCell();
  char steamid[20];
  pack.ReadString(steamid, sizeof(steamid));
  int extension_seconds = pack.ReadCell();
  char admin_steamid[20];
  pack.ReadString(admin_steamid, sizeof(admin_steamid));
  char admin_name[64];
  pack.ReadString(admin_name, sizeof(admin_name));
  delete pack;

  if (results.RowCount == 0) {
    int admin_client = GetClientOfUserId(admin_userid);
    xVip_Reply(admin_client, "No VIP found with SteamID: %s", steamid);
    return;
  }

  results.FetchRow();
  char name[MAX_NAME_LENGTH];
  results.FetchString(0, name, sizeof(name));
  int current_enddate = results.FetchInt(1);
  
  // Add extension_seconds to current end date
  int new_enddate = current_enddate + extension_seconds;

  char query[1024];
  Format(query, sizeof(query), "UPDATE xVip_vips SET enddate = %d WHERE steamid = '%s';", new_enddate, steamid);
  
  DataPack extendPack = new DataPack();
  extendPack.WriteCell(admin_userid);
  extendPack.WriteString(name);
  extendPack.WriteString(steamid);
  extendPack.WriteCell(new_enddate);
  extendPack.WriteCell(extension_seconds);
  extendPack.WriteString(admin_steamid);
  extendPack.WriteString(admin_name);
  g_DB.Query(SQL_OnVipExtended, query, extendPack);
}

public void SQL_OnVipExtended(Database db, DBResultSet results, const char[] error, DataPack pack) {
  pack.Reset();
  int admin_userid = pack.ReadCell();
  char name[MAX_NAME_LENGTH];
  pack.ReadString(name, sizeof(name));
  char steamid[20];
  pack.ReadString(steamid, sizeof(steamid));
  int new_enddate = pack.ReadCell();
  int duration = pack.ReadCell();
  char admin_steamid[20];
  pack.ReadString(admin_steamid, sizeof(admin_steamid));
  char admin_name[64];
  pack.ReadString(admin_name, sizeof(admin_name));
  delete pack;

  if (error[0] != '\0') {
    LogError("Failed to extend VIP: %s", error);
    return;
  }

  char durationStr[64];
  FormatDuration(duration, durationStr, sizeof(durationStr));

  char endDate[64];
  FormatTime(endDate, sizeof(endDate), "%b %d, %Y - %R", new_enddate);

  int admin_client = GetClientOfUserId(admin_userid);
  xVip_Reply(admin_client, "Successfully extended %s's VIP (%s) to %s. Duration: %s", name, steamid, endDate, durationStr);

  LogVipAction("extend", name, steamid, admin_name, admin_steamid, duration);
}

public void OnClientPostAdminCheck(int client) {
  if (g_DB == null)
  {
    return;
  }

  int userid = GetClientUserId(client);
  char steamid[20];
  if (!GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid)))
  {
    return;
  }

  char query[1024];
  Format(query, sizeof(query), "SELECT enddate FROM xVip_vips WHERE steamid = '%s';", steamid);

  DataPack pack = new DataPack();
  pack.WriteCell(userid);
  pack.WriteString(steamid);
  g_DB.Query(SQL_OnVipCheck, query, pack);
}

public void SQL_OnVipCheck(Database db, DBResultSet results, const char[] error, DataPack pack) {
  pack.Reset();
  int userid = pack.ReadCell();
  char steamid[20];
  pack.ReadString(steamid, sizeof(steamid));
  delete pack;

  if (results.RowCount == 0) {
    g_bIsVip[userid] = false;
    return;
  }

  results.FetchRow();
  int enddate = results.FetchInt(0);
  if (enddate < GetTime()) {
    RemoveVipFlags(userid);
    g_bIsVip[userid] = false;
    return;
  }

  SetVipFlags(userid);
  g_bIsVip[userid] = true;
}

public void SetVipFlags(int userid)
{
  int client = GetClientOfUserId(userid);
  for (int i = 0; i < strlen(g_cFlags); i++)
  {
    AdminFlag vipFlag;
    FindFlagByChar(g_cFlags[i], vipFlag);
    AddUserFlags(client, vipFlag);
  }
}

public void RemoveVipFlags(int userid)
{
  int client = GetClientOfUserId(userid);
  for (int i = 0; i < strlen(g_cFlags); i++)
  {
    AdminFlag vipFlag;
    FindFlagByChar(g_cFlags[i], vipFlag);
    RemoveUserFlags(client, vipFlag);
  }
}

public void SQL_OnTableCreated(Handle owner, Handle hndl, const char[] error, DataPack pack) {
  if (!StrEqual(error, ""))
  {
    LogError(error);
  }
  pack.Reset();
  char message[64];
  pack.ReadString(message, sizeof(message));
  xVip_Reply(0, "%s", message);
  delete pack;
}

void LogVipAction(const char[] action_type, const char[] target_name, const char[] target_steamid, 
  const char[] admin_name, const char[] admin_steamid, int duration = 0) {
  
  char query[1024];
  g_DB.Format(query, sizeof(query), 
    "INSERT INTO xVip_logs (action_type, target_name, target_steamid, admin_name, admin_steamid, duration) \
           VALUES ('%s', '%s', '%s', '%s', '%s', %s)", 
    action_type, target_name, target_steamid, admin_name, admin_steamid, duration == 0 ? "null" : "duration");

  g_DB.Query(SQL_ErrorCheck, query);
}

public void SQL_ErrorCheck(Database db, DBResultSet results, const char[] error, any data) {
  if (error[0] != '\0')
  {
    LogError(error);
  }
}

public any Native_IsVip(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  if (!IsValidClient(client))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
  }
  return g_bIsVip[GetClientUserId(client)];
}

public int Native_GetPrefix(Handle plugin, int numParams)
{ 
  return SetNativeString(1, g_cPrefix, sizeof(g_cPrefix));
}