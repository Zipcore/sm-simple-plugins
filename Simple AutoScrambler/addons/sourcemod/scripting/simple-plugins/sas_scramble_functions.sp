stock SortRandom(float:array[][], numClients)
{
	// copy everything into a 1d array
	new clients[numClints];
	for (new i; i < numClients; i++)
		clients[i] = RoundFloat(array[i][0]);
	SortIntegers(clients, iCount, Sort_Random);
	// copy back to the main array
	for (new i; i<numClients; i++)
		array[i][0] = float(clients[i]);
}

stock SortScores(float:array[][], numClients)
{
	// get everyone's score
	for (new i; i < numClients; i++)
		array[i][1] = float(GetClientScore(i));
	SortCustom2D(array, numClients, SortFloatsDesc);
}

stock SortRatios(float:array[][], numClients)
{
	// get everyone's kill/death ratio
	for (new i; i < numClients; i++)
		array[i][1] = g_aPlayers[i][iFrags] / g_aPlayers[i][iDeaths];
	SortCustom2D(array, numClients, SortFloatsDesc);
}

stock bool:IsValidTarget(client)
{
	if ((PROTECT_BUDDIES && SM_IsBuddyLocked(client)) || (PROTECT_ADMINS && SM_IsValidAdmin(client, const String:flags[])))
		return false;
	if (IsClientTopPlayer(client)
		return false;
	if (g_RoundState == normal && g_currentMod == TF2) // only do specific immunity checks during a mid-round scramble
	{
		if (TF2_IsClientUbered(client))
			return false;
		if (PROTECT_ENGINEERS)
		{
			if (PROTECT_BUILDINGS && TF2_DoesClientHaveBuilding(client "obj_*");
				return false;
			if (PROTECT_ONLY_ENGINEER && TF2_IsClientOnlyClass(client, TFClass_Engineer))
				return false;
		}
		if (PROTECT_MEDICS)
		{
			if (TF2_IsClientUberCharged(client))
				return false;
			if (PROTECT_ONLY_MEDIC && TF2_IsClientOnlyClass(client, TFClass_Medic))
				return false;
		}	
	}
	return true;
}

public SortFloatsDesc(x[], y[], array[][], Handle:data)
{
    if (Float:x[1] > Float:y[1])
        return -1;
	else if (Float:x[1] < Float:y[1])
		return 1;
    return 0;
}

public SortIntsDesc(x[], y[], array[][], Handle:data)
{
	if (x[1] > y[1])
		return -1;
	else if (x[1] < y[1])
		return 1;
  return 0;
}

stock IsClientTopPlayer(client)
{
	new teamSize = GetTeamClientCount(client), 
		scores[][2],
		count;
	for (new i = i; i < teamSize; i++)
	{
		scores[count++][0] = i;
		scores[count][1] = GetClientScore(i);
	}
	SortCustom2D(scores, count, SortIntsDesc);
	for (new i; i <= PROTECTION; i++)
	{
		if (i == client)
			return true;
	}
	return false;
}
	