/**
 * Formats a duration in seconds to a human readable string.
 * 
 * @param seconds          Time in seconds to format
 * @param buffer          Buffer to store the formatted string
 * @param maxlen          Maximum length of the buffer
 * @param short_names     Whether to use short names (e.g. "mo" vs "months")
 * 
 * Example outputs:
 * - "2 months, 5 days, 3 hours"
 * - "1 month, 12 hours, 30 minutes"
 * - "15 days, 2 hours"
 * - "30 minutes"
 */
stock void FormatDuration(int seconds, char[] buffer, int maxlen, bool short_names = false) {
    // Initialize the output buffer
    buffer[0] = '\0';
    
    // Handle negative or zero seconds
    if (seconds <= 0) {
        Format(buffer, maxlen, "0%s", short_names ? "m" : " minutes");
        return;
    }
    
    // Define time units in descending order
    int units[][] = {
        {2592000, 0, 0},  // 30 days = roughly 1 month
        {86400, 0, 0},    // 1 day
        {3600, 0, 0},     // 1 hour
        {60, 0, 0},       // 1 minute
        {1, 0, 0}         // 1 second
    };
    
    char unit_names[][][] = {
        {"month", "months", "mo"},
        {"day", "days", "d"},
        {"hour", "hours", "h"},
        {"minute", "minutes", "m"},
        {"second", "seconds", "s"}
    };
    
    // Calculate the number of each unit
    int remaining = seconds;
    int units_count = sizeof(units);
    
    for (int i = 0; i < units_count; i++) {
        if (remaining >= units[i][0]) {
            units[i][1] = remaining / units[i][0];  // Calculate count
            remaining = remaining % units[i][0];     // Calculate remainder
            units[i][2] = 1;                        // Mark as used
        }
    }
    
    // Build the output string
    bool first = true;
    char temp[32];
    int parts = 0;
    
    for (int i = 0; i < units_count; i++) {
        if (units[i][2] == 1) { // If this unit is used
            // Skip seconds if we have larger units
            if (i == units_count - 1 && parts > 0) {
                continue;
            }
            
            // Add comma if not first unit
            if (!first) {
                Format(temp, sizeof(temp), ", ");
                StrCat(buffer, maxlen, temp);
            }
            
            if (short_names) {
                // Short format: "5mo" or "3d"
                Format(temp, sizeof(temp), "%d%s", units[i][1], unit_names[i][2]);
            } else {
                // Long format: "5 months" or "3 days"
                Format(temp, sizeof(temp), "%d %s", 
                    units[i][1], 
                    units[i][1] == 1 ? unit_names[i][0] : unit_names[i][1]);
            }
            
            StrCat(buffer, maxlen, temp);
            first = false;
            parts++;
            
            // Only show up to 3 largest units
            if (parts >= 3) {
                break;
            }
        }
    }
}

/**
 * Formats a timestamp difference into a human readable duration string.
 * 
 * @param start_time     Start timestamp
 * @param end_time       End timestamp
 * @param buffer         Buffer to store the formatted string
 * @param maxlen         Maximum length of the buffer
 * @param short_names    Whether to use short names
 */
stock void FormatTimeDiff(int start_time, int end_time, char[] buffer, int maxlen, bool short_names = false) {
    int diff = end_time - start_time;
    FormatDuration(diff, buffer, maxlen, short_names);
}

stock bool IsValidClient(int client)
{
  if 
    (
    // "client" is 0 (console) or lower - nope!
    0 >= client
    // "client" is higher than MaxClients - nope!
     || MaxClients < client
    // "client" isnt in game aka their entity hasn't been created - nope!
     || !IsClientInGame(client)
    // "client" is sourcetv - nope!
     || IsClientSourceTV(client)
    // "client" is the replay bot - nope!
     || IsClientReplay(client)
    )
  {
    return false;
  }
  return true;
}

stock int GetUserIDBySteamID(const char[] steamid)
{
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidClient(i))
    {
      char steamid2[32];
      GetClientAuthId(i, AuthId_SteamID64, steamid2, sizeof(steamid2));
      if (StrEqual(steamid, steamid2))
      {
        return GetClientUserId(i);
      }
    }
  }
  return -1;
}

/**
 * Checks if a client has VIP status.
 *
 * @param client    Client index to check.
 * @return          True if client is VIP, false otherwise.
 */
native bool xVip_IsVip(int client);