#include "ogmp_common.as"

uint connect_try_countdown = 5;
string level_name = "";
int player_id = -1;
int initial_sequence_id;
IMGUI imGUI;
Chat chat;
Inputfield username_field;

enum ClientUIState {
	UsernameUI = 0,
	ServerListUI = 1,
	LevelListUI = 2,
	PlayerListUI = 3
}

ClientUIState currentUIState = ServerListUI;

string username = "";
string team = "";
string welcome_message = "";
string character = "";

int ragdoll_counter = 0;
float dir_x = 0.0f;
float dir_z = 0.0f;

bool MPWantsToCrouch = false;
bool MPWantsToJump = false;
bool MPWantsToAttack = false;
bool MPWantsToGrab = false;
bool MPWantsToItem = false;
bool MPWantsToDrop = false;
bool MPWantsToRoll = false;
bool MPWantsToJumpOffWall = false;
bool MPActiveBlock = false;
bool MPIsConnected = false;
float blood_damage = 0.0f;
float blood_health = 1.0f;
float block_health = 1.0f;
float temp_health = 1.0f;
float permanent_health = 1.0f;
int knocked_out = 0;
int lives = 1;
float blood_amount = 10.0f;
float recovery_time = 1.0f;
float roll_recovery_time = 1.0f;
int ragdoll_type = 0;
int blood_delay = 0;
bool cut_throat = false;
int state = 0;

bool connected_to_server = false;
bool post_init_run = false;
bool trying_to_connect = false;
bool showing_playerlist = false;
bool cc_ui_added = false;
bool start_adding_cc_ui = false;

float update_timer = 0.0f;
float interval = 1.0f;
int refresh_rate = 30;

bool TCPReceived = false;
bool connected_icon_state = false;

array<RemotePlayer@> remote_players;
IMDivider@ main_divider;
array<uint8>@ data_collection = {};
ServerConnectionInfo@ current_server;
IMDivider@ error_divider;

void Init(string p_level_name) {
    level_name = GetCurrLevel();
	imGUI.setFooterHeight(350);
	imGUI.setHeaderHeight(100);
	imGUI.setup();
	imGUI.getHeader().setAlignment(CALeft, CACenter);
	chat.Initialize();
}

void IncomingTCPData(uint socket, array<uint8>@ data) {
	if(socket == retriever_socket){
		Log(info, "Some sata came in from the retriever socket");
	}
	Log(info, "Data in size " + data.length() );
    for( uint i = 0; i < data.length(); i++ ) {
		data_collection.insertLast(data[i]);
        /*Print(data[i] + " ");*/
    }
	/*Print("\n");
	PrintByteArray(data);*/
}

void ReadServerList(){
	for(uint i = 0; i < server_list.size(); i++){
		if( retriever_socket == SOCKET_ID_INVALID ) {
            Log( info, "Trying to connect" );
			retriever_socket = CreateSocketTCP(server_list[i].address, server_list[i].port);
            if( retriever_socket != SOCKET_ID_INVALID ) {
                Log( info, "Connected " + server_list[i].address );
            } else {
                Log( warning, "Unable to connect" );
            }
        }
		if( !IsValidSocketTCP(retriever_socket) ){
			Log(info, "invalid");
			retriever_socket = SOCKET_ID_INVALID;
		}else{
			Log(info, "valid");
			retriever_socket = SOCKET_ID_INVALID;
		}
	}
}

void ProcessIncomingMessage(array<uint8>@ data){
	uint8 message_type = data[0];
	Log(info, "Message type : " + message_type);
	int data_index = 1;
	if(message_type == SignOn){
		Log(info, "Incoming: " + "SignOn Command");
		float refresh_rate = GetFloat(data, data_index);
		Log(info, "refresh_rate: " + refresh_rate);
		string username = GetString(data, data_index);
		Log(info, "username: " + username);
		string welcome_message = GetString(data, data_index);
		Log(info, "welcome_message: " + welcome_message);
		string team = GetString(data, data_index);
		Log(info, "team: " + team);
		string character = GetString(data, data_index);
		Log(info, "character: " + character);
		connected_to_server = true;
		interval = 1.0 / refresh_rate;
		Log(info, "interval: " + interval);
		RemoveUI();
	}
	else if(message_type == Message){
		Log(info, "Incoming: " + "Message Command");
		string message_source = GetString(data, data_index);
		string message_text = GetString(data, data_index);
		bool notif = GetBool(data, data_index);
		
		chat.AddMessage(message_text, message_source, notif);
	}
	else if (message_type == SpawnCharacter){
		Log(info, "Incoming: " + "SpawnCharacter Command");
		string username = GetString(data, data_index);
		string team = GetString(data, data_index);
		string character = GetString(data, data_index);
		float pos_x = GetFloat(data, data_index);
		float pos_y = GetFloat(data, data_index);
		float pos_z = GetFloat(data, data_index);
		CreateRemotePlayer(username, team, character, vec3(pos_x, pos_y, pos_z));
	}
	else if (message_type == RemoveCharacter){
		Log(info, "Incoming: " + "RemoveCharacter Command");
		string username = GetString(data, data_index);
		RemoveRemotePlayer(username);
	}
	else if (message_type == UpdateGame){
		Log(info, "Incoming: " + "Update Command");
	}
	else if (message_type == UpdateSelf){
		Log(info, "Incoming: " + "UpdateSelf Command");
	}
	else if (message_type == UpdateCharacter){
		Log(info, "Incoming: " + "UpdateCharacter Command");
		
		string remote_username = GetString(data, data_index);
		float remote_posx = GetFloat(data, data_index);
		float remote_posy = GetFloat(data, data_index);
		float remote_posz = GetFloat(data, data_index);
		float remote_dirx = GetFloat(data, data_index);
		float remote_dirz = GetFloat(data, data_index);
		
		bool remote_crouch = GetBool(data, data_index);
		bool remote_jump = GetBool(data, data_index);
		bool remote_attack = GetBool(data, data_index);
		bool remote_grab = GetBool(data, data_index);
		bool remote_item = GetBool(data, data_index);
		bool remote_drop = GetBool(data, data_index);
		bool remote_roll = GetBool(data, data_index);
		bool remote_jumpoffwall = GetBool(data, data_index);
		bool remote_activateblock = GetBool(data, data_index);
		
		float remote_blooddamage = GetFloat(data, data_index);
		float remote_bloodhealth = GetFloat(data, data_index);
		float remote_blockhealth = GetFloat(data, data_index);
		float remote_temphealth = GetFloat(data, data_index);
		float remote_permanenthealth = GetFloat(data, data_index);
		
		int remote_knockedout = GetInt(data, data_index);
		int remote_lives = GetInt(data, data_index);
		
		float remote_bloodamount = GetFloat(data, data_index);
		float remote_recoverytime = GetFloat(data, data_index);
		float remote_rollrecoverytime = GetFloat(data, data_index);
		
		bool remote_removeblood = GetBool(data, data_index);
		int remote_blooddelay = GetInt(data, data_index);
		bool remote_cutthroat = GetBool(data, data_index);
		int remote_state = GetInt(data, data_index);
		
		MovementObject@ remote_player = GetRemotePlayer(remote_username);
		if(remote_player !is null){
			remote_player.position = vec3(remote_posx, remote_posy, remote_posz);
			remote_player.Execute("dir_x = " + remote_dirx + ";");
			remote_player.Execute("dir_z = " + remote_dirz + ";");
			remote_player.Execute("MPWantsToCrouch = " + remote_crouch + ";");
			remote_player.Execute("MPWantsToJump = " + remote_jump + ";");
			remote_player.Execute("MPWantsToAttack = " + remote_attack + ";");
			remote_player.Execute("MPWantsToGrab = " + remote_grab + ";");
			remote_player.Execute("MPWantsToItem = " + remote_item + ";");
			remote_player.Execute("MPWantsToDrop = " + remote_drop + ";");
			remote_player.Execute("MPWantsToRoll = " + remote_roll + ";");
			remote_player.Execute("MPWantsToJumpOffWall = " + remote_jumpoffwall + ";");
			remote_player.Execute("MPActiveBlock = " + remote_activateblock + ";");
			remote_player.Execute("MPActiveBlock = " + remote_activateblock + ";");
			
			remote_player.Execute("blood_damage = " + remote_blooddamage + ";");
			remote_player.Execute("blood_health = " + remote_bloodhealth + ";");
			remote_player.Execute("block_health = " + remote_blockhealth + ";");
			remote_player.Execute("temp_health = " + remote_temphealth + ";");
			remote_player.Execute("permanent_health = " + remote_permanenthealth + ";");
			remote_player.Execute("blood_amount = " + remote_bloodamount + ";");
			remote_player.Execute("recovery_time = " + remote_recoverytime + ";");
			remote_player.Execute("roll_recovery_time = " + remote_rollrecoverytime + ";");
			
			remote_player.Execute("knocked_out = " + remote_knockedout + ";");
			remote_player.Execute("blood_delay = " + remote_blooddelay + ";");
			remote_player.Execute("state = " + remote_state + ";");
			
		}else{
			Print("Can't find the user " + remote_username);
		}
	}
	else if (message_type == Error){
		Log(info, "Incoming: " + "Error Command");
		if(cc_ui_added){
			error_divider.clear();
			IMText error_message(GetString(data, data_index), error_font);
			error_divider.append(error_message);
		}
	}
	else if(message_type == LoadPosition){
		Log(info, "Incoming: " + "LoadPosition");
		MovementObject@ player = ReadCharacter(player_id);
		player.position.x = GetFloat(data, data_index);
		player.position.y = GetFloat(data, data_index);
		player.position.z = GetFloat(data, data_index);
	}
	else if(message_type == ServerInfo){
		Log(info, "Incoming: " + "ServerInfo");
		string server_name = GetString(data, data_index);
		int nr_players = GetInt(data, data_index);
		Log(info, "Server name: " + server_name);
		Log(info, "Number of players: " + nr_players);
		server_retriever.SetServerInfo(server_name, nr_players);
	}
	else if(message_type == LevelList){
		Log(info, "Incoming: " + "LevelList");
		array<LevelInfo@> levels;
		while(data_index < int(data.size() - 1)){
			string level_name = GetString(data, data_index);
			string level_path = GetString(data, data_index);
			int nr_players = GetInt(data, data_index);
			Log(info, "name " + level_name + " path " + level_path + " nr_p " + nr_players);
			levels.insertLast(LevelInfo(level_name, level_path, nr_players));
		}
		server_retriever.SetLevelList(levels);
	}
	else{
		//DisplayError("Unknown Message", "Unknown incomming message: " + message_type);
		PrintByteArray(data);
	}
}

MovementObject@ GetRemotePlayer(string username){
	for(uint i = 0; i < remote_players.size(); i++){
		if(remote_players[i].username == username){
			MovementObject@ found_remote_player = ReadCharacterID(remote_players[i].object_id);
			return found_remote_player;
		}
	}
	return null;
}

void CreateRemotePlayer(string username, string team, string character, vec3 position){
	int obj_id = CreateObject(turner);
	remote_players.insertLast(RemotePlayer(username, team, obj_id));
	MovementObject@ remote_player = ReadCharacterID(obj_id);
	Object@ object = ReadObjectFromID(obj_id);
	ScriptParams@ params = object.GetScriptParams();
	params.SetString("Teams", team);
	remote_player.position = position;
}

void RemoveRemotePlayer(string username){
	for(uint i = 0; i < remote_players.size(); i++){
		MovementObject@ remote_player = ReadCharacterID(remote_players[i].object_id);
		remote_player.Execute("situation.clear();");
		if(remote_players[i].username == username){
			DeleteObjectID(remote_players[i].object_id);
			remote_players.removeAt(i);
		}
	}
}

void PrintByteArray(array<uint8> data){
	array<string> complete;
    for( uint i = 0; i < data.length(); i++ ) {
        string s('0');
        s[0] = data[i];
        complete.insertLast(s);
		Print(s);
    }
	Print("\n");
    /*Log(info, "Incoming: " + join(complete, ""));*/
}

void ReceiveMessage(string msg) {
}

void DrawGUI() {
	imGUI.render();
}

void AddUI(){
	Print("AddUI\n");
	switch(currentUIState){
		case UsernameUI:
			AddUsernameUI();
			break;
		case ServerListUI:
			AddServerListUI();
			break;
		case LevelListUI:
			AddLevelListUI();
			break;
		case PlayerListUI:
			AddPlayerListUI();
			break;
		default:
			DisplayError("UIState", "The UIState is invalid!");
			break;
	}
}

void RemoveUI(){
	Print("RemoveUI\n");
	cc_ui_added = false;
	level.Execute("has_gui = false;");
	imGUI.getMain().clear();
}

void RefreshUI(){
	Print("RefreshUI\n");
	RemoveUI();
	AddUI();
}

void AddUsernameUI(){
	cc_ui_added = true;
	level.Execute("has_gui = true;");
	vec2 menu_size(1000, 500);
	vec4 background_color(0,0,0,0.5);
	vec2 button_size(1000, 60);
	float button_size_offset = 10.0f;
	
	IMContainer menu_container(menu_size.x, menu_size.y);
	menu_container.setAlignment(CACenter, CACenter);
	IMDivider menu_divider("menu_divider", DOVertical);
	menu_container.setElement(menu_divider);
	
	//Username input field.
	IMContainer username_container(button_size.x / 2.0f, button_size.y);
	username_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("activate_search"), "");
	IMDivider username_divider("username_divider", DOHorizontal);
	IMContainer username_parent_container(button_size.x / 2.0f, button_size.y);
	IMDivider username_parent("username_parent", DOHorizontal);
	username_parent_container.setElement(username_parent);
	username_container.setElement(username_divider);
	
	IMText description_label("Username: ", client_connect_font);
	description_label.setZOrdering(3);
	username_divider.append(description_label);
	
	username_divider.appendSpacer(25);
	
	IMText username_label(username, client_connect_font);
	username_label.setZOrdering(3);
	username_parent.append(username_label);
	username_divider.append(username_parent_container);
	
	IMImage username_background(white_background);
	username_background.setZOrdering(0);
	username_background.setSize(button_size - button_size_offset);
	username_background.setColor(vec4(0,0,0,0.75));
	username_parent_container.addFloatingElement(username_background, "username_background", vec2(button_size_offset / 2.0f));
	
	username_field.SetInputField(@username_label, @username_parent);
	
	menu_divider.append(username_container);
	
	//The main background
	IMImage background(white_background);
	background.setColor(background_color);
	background.setSize(menu_size);
	menu_container.addFloatingElement(background, "background", vec2(0));
	imGUI.getMain().setSize(vec2(2560, 1000));
	/*imGUI.getMain().setAlignment(CACenter, CACenter);*/
	imGUI.getMain().setElement(menu_container);
}

void AddServerListUI(){
	cc_ui_added = true;
	level.Execute("has_gui = true;");
	vec2 menu_size(1000, 500);
	vec4 background_color(0,0,0,0.5);
	vec2 connect_button_size(1000, 60);
	float button_size_offset = 10.0f;
	int server_name_width = 500;
	int latency_width = 200;
	int nr_players_width = 200;
	
	server_retriever.CheckOnlineServers();
	
	IMContainer menu_container(menu_size.x, menu_size.y);
	menu_container.showBorder();
	menu_container.setAlignment(CACenter, CATop);
	IMDivider menu_divider("menu_divider", DOVertical);
	menu_container.setElement(menu_divider);
	
	menu_divider.appendSpacer(10);
	
	//Pick a server titlebar
	IMContainer pick_server_container(connect_button_size.x, connect_button_size.y);
	menu_divider.append(pick_server_container);
	IMDivider pick_server_divider("pick_server_divider", DOHorizontal);
	pick_server_divider.setZOrdering(4);
	pick_server_container.setElement(pick_server_divider);
	IMText pick_server("Pick a server", client_connect_font);
	pick_server_divider.append(pick_server);
	//Title background
	IMImage pick_server_background(brushstroke_background);
	pick_server_background.setZOrdering(2);
	pick_server_background.setClip(false);
	pick_server_background.setSize(vec2(500, 60));
	pick_server_background.setAlpha(0.85f);
	pick_server_container.addFloatingElement(pick_server_background, "pick_server_background", vec2(pick_server_container.getSizeX() / 2.0f - pick_server_background.getSizeX() / 2.0f,0));
	
	//Server browser titlebar
	IMContainer titlebar_container(connect_button_size.x, connect_button_size.y);
	menu_divider.append(titlebar_container);
	IMDivider titlebar_divider("titlebar_divider", DOHorizontal);
	titlebar_divider.setZOrdering(4);
	titlebar_container.setElement(titlebar_divider);
	
	IMContainer servername_label_container(server_name_width);
	IMText servername_label("Server name", client_connect_font);
	servername_label.setZOrdering(4);
	servername_label_container.setElement(servername_label);
	titlebar_divider.append(servername_label_container);
	
	IMContainer latency_label_container(latency_width);
	IMText latency_label("Latency", client_connect_font);
	latency_label.setZOrdering(4);
	latency_label_container.setElement(latency_label);
	titlebar_divider.append(latency_label_container);
	
	IMContainer nr_players_label_container(nr_players_width);
	IMText nr_players_label("Nr players", client_connect_font);
	nr_players_label.setZOrdering(4);
	nr_players_label_container.setElement(nr_players_label);
	titlebar_divider.append(nr_players_label_container);
	
	for(uint i = 0; i < server_retriever.online_servers.size(); i++){
		//Connect button
		IMContainer button_container(connect_button_size.x, connect_button_size.y);
		button_container.sendMouseOverToChildren(true);
		IMDivider button_divider("button_divider", DOHorizontal);
		button_container.setElement(button_divider);
		
		button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("server_chosen", i), "");
		menu_divider.append(button_container);
		
		Print("name " + server_retriever.online_servers[i].server_name + "\n");
		
		//The server name
		IMContainer servername_container(server_name_width);
		IMText server_name(server_retriever.online_servers[i].server_name, client_connect_font_small);
		server_name.setZOrdering(4);
		server_name.addMouseOverBehavior(mouseover_fontcolor, "");
		servername_container.setElement(server_name);
		button_divider.append(servername_container);
		
		//The latency
		IMContainer latency_container(latency_width);
		IMText latency(server_retriever.online_servers[i].latency + " ms", client_connect_font_small);
		latency.setZOrdering(4);
		latency.addMouseOverBehavior(mouseover_fontcolor, "");
		latency_container.setElement(latency);
		button_divider.append(latency_container);
		
		//The number of players
		IMContainer nr_players_container(nr_players_width);
		IMText nr_players(server_retriever.online_servers[i].nr_players + "", client_connect_font_small);
		nr_players.setZOrdering(4);
		nr_players.addMouseOverBehavior(mouseover_fontcolor, "");
		nr_players_container.setElement(nr_players);
		button_divider.append(nr_players_container);
		
		IMImage button_background(white_background);
		button_background.setZOrdering(0);
		button_background.setSize(connect_button_size - button_size_offset);
		button_background.setColor(vec4(0,0,0,0.75));
		button_container.addFloatingElement(button_background, "button_background", vec2(button_size_offset / 2.0f));
	}
	
	IMDivider info_divider("info_divider", DOHorizontal);
	menu_divider.append(info_divider);
	if(server_retriever.checking_servers){
		Print("Getting more servers...\n");
		IMText info("Getting more servers...", client_connect_font_small);
		//info_divider.append(info);
	}else if(server_retriever.online_servers.size() == 0){
		IMText info("No online servers found.", client_connect_font_small);
		//info_divider.append(info);
	}
	
	//The errors are put in this divider
	@error_divider = IMDivider("error_divider", DOVertical);
	menu_divider.append(error_divider);
	
	//The main background
	IMImage background(white_background);
	background.setColor(background_color);
	background.setSize(menu_size);
	menu_container.addFloatingElement(background, "background", vec2(0));
	imGUI.getMain().setSize(vec2(2560, 1000));
	/*imGUI.getMain().setAlignment(CACenter, CACenter);*/
	imGUI.getMain().setElement(menu_container);
}

void AddLevelListUI(){
	cc_ui_added = true;
	level.Execute("has_gui = true;");
	vec2 menu_size(1000, 500);
	vec4 background_color(0,0,0,0.5);
	vec2 connect_button_size(1000, 60);
	float button_size_offset = 10.0f;
	int level_name_width = 500;
	int nr_players_width = 200;
	
	server_retriever.GetLevelList();
	
	IMContainer menu_container(menu_size.x, menu_size.y);
	menu_container.showBorder();
	menu_container.setAlignment(CACenter, CATop);
	IMDivider menu_divider("menu_divider", DOVertical);
	menu_container.setElement(menu_divider);
	
	menu_divider.appendSpacer(10);
	
	//Pick a level titlebar
	IMContainer pick_level_container(connect_button_size.x, connect_button_size.y);
	menu_divider.append(pick_level_container);
	IMDivider pick_level_divider("pick_level_divider", DOHorizontal);
	pick_level_divider.setZOrdering(4);
	pick_level_container.setElement(pick_level_divider);
	IMText pick_server("Pick a level", client_connect_font);
	pick_level_divider.append(pick_server);
	//Title background
	IMImage pick_level_background(brushstroke_background);
	pick_level_background.setZOrdering(2);
	pick_level_background.setClip(false);
	pick_level_background.setSize(vec2(500, 60));
	pick_level_background.setAlpha(0.85f);
	pick_level_container.addFloatingElement(pick_level_background, "pick_level_background", vec2(pick_level_container.getSizeX() / 2.0f - pick_level_background.getSizeX() / 2.0f,0));
	
	//Server browser titlebar
	IMContainer titlebar_container(connect_button_size.x, connect_button_size.y);
	menu_divider.append(titlebar_container);
	IMDivider titlebar_divider("titlebar_divider", DOHorizontal);
	titlebar_divider.setZOrdering(3);
	titlebar_container.setElement(titlebar_divider);
	
	IMContainer levelname_label_container(level_name_width);
	IMText levelname_label("Level name", client_connect_font);
	levelname_label.setZOrdering(3);
	levelname_label_container.setElement(levelname_label);
	titlebar_divider.append(levelname_label_container);
	
	IMContainer nr_players_label_container(nr_players_width);
	IMText nr_players_label("Nr players", client_connect_font);
	nr_players_label.setZOrdering(3);
	nr_players_label_container.setElement(nr_players_label);
	titlebar_divider.append(nr_players_label_container);
	
	bool server_includes_this_level = false;
	
	for(uint i = 0; i < current_server.levels.size(); i++){
		if(current_server.levels[i].level_path == level_name){
			server_includes_this_level = true;
		}
	}
	if(!server_includes_this_level){
		//Add the current level always to the top of the list.
		IMContainer button_container(connect_button_size.x, connect_button_size.y);
		button_container.sendMouseOverToChildren(true);
		IMDivider button_divider("button_divider", DOHorizontal);
		button_container.setElement(button_divider);
		
		button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("level_chosen", level_name), "");
		menu_divider.append(button_container);
		
		//The level name
		IMContainer levelname_container(level_name_width);
		IMText level_name_label("Current level: " + level_name, client_connect_font_small);
		level_name_label.setZOrdering(4);
		level_name_label.addMouseOverBehavior(mouseover_fontcolor, "");
		levelname_container.setElement(level_name_label);
		button_divider.append(levelname_container);
		
		//The number of players
		IMContainer nr_players_container(nr_players_width);
		IMText nr_players("0", client_connect_font_small);
		nr_players.setZOrdering(4);
		nr_players.addMouseOverBehavior(mouseover_fontcolor, "");
		nr_players_container.setElement(nr_players);
		button_divider.append(nr_players_container);
		
		IMImage button_background(white_background);
		button_background.setZOrdering(0);
		button_background.setSize(connect_button_size - button_size_offset);
		button_background.setColor(vec4(0,0,0,0.75));
		button_container.addFloatingElement(button_background, "button_background", vec2(button_size_offset / 2.0f));
	}
	
	{
		for(uint i = 0; i < current_server.levels.size(); i++){
			IMContainer button_container(connect_button_size.x, connect_button_size.y);
			button_container.sendMouseOverToChildren(true);
			IMDivider button_divider("button_divider", DOHorizontal);
			button_container.setElement(button_divider);
			
			button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("level_chosen", level_name), "");
			menu_divider.append(button_container);
			
			//The level name
			IMContainer levelname_container(level_name_width);
			IMText level_name_label("", client_connect_font_small);
			if(current_server.levels[i].level_path == level_name){
				level_name_label.setText("Current level: " + current_server.levels[i].level_name);
			}else{
				level_name_label.setText(current_server.levels[i].level_name);
			}
			level_name_label.setZOrdering(4);
			level_name_label.addMouseOverBehavior(mouseover_fontcolor, "");
			levelname_container.setElement(level_name_label);
			button_divider.append(levelname_container);
			
			//The number of players
			IMContainer nr_players_container(nr_players_width);
			IMText nr_players(current_server.levels[i].nr_players + "", client_connect_font_small);
			nr_players.setZOrdering(4);
			nr_players.addMouseOverBehavior(mouseover_fontcolor, "");
			nr_players_container.setElement(nr_players);
			button_divider.append(nr_players_container);
			
			IMImage button_background(white_background);
			button_background.setZOrdering(0);
			button_background.setSize(connect_button_size - button_size_offset);
			button_background.setColor(vec4(0,0,0,0.75));
			button_container.addFloatingElement(button_background, "button_background", vec2(button_size_offset / 2.0f));
		}
	}
	
	{
		menu_divider.appendSpacer(10);
		//The previous button
		IMContainer button_container(connect_button_size.x, connect_button_size.y);
		button_container.setAlignment(CALeft, CACenter);
		IMDivider button_divider("button_divider", DOHorizontal);
		button_divider.setZOrdering(4);
		button_container.setElement(button_divider);
		button_divider.appendSpacer(50);
		IMText previous("Previous", client_connect_font);
		previous.addMouseOverBehavior(mouseover_fontcolor, "");
		button_divider.append(previous);
		
		IMImage button_background(white_background);
		button_background.setZOrdering(0);
		button_background.setSize(vec2(200, connect_button_size.y - button_size_offset));
		button_background.setColor(vec4(0,0,0,0.75));
		button_container.addFloatingElement(button_background, "button_background", vec2(button_size_offset / 2.0f));
		
		button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("previous_ui"), "");
		menu_divider.append(button_container);
	}
	
	//The errors are put in this divider
	@error_divider = IMDivider("error_divider", DOVertical);
	menu_divider.append(error_divider);
	
	//The main background
	IMImage background(white_background);
	background.setColor(background_color);
	background.setSize(menu_size);
	menu_container.addFloatingElement(background, "background", vec2(0));
	imGUI.getMain().setSize(vec2(2560, 1000));
	/*imGUI.getMain().setAlignment(CACenter, CACenter);*/
	imGUI.getMain().setElement(menu_container);
}

void AddPlayerListUI(){
	
}

void PostInit(){
	player_id = GetPlayerCharacterID();
	//Create a random username from an adjactive and a noun.
	username = adjectives[rand() % adjectives.length()] + nouns[rand() % nouns.length()];
}

void Update(int paused) {
	imGUI.update();
	server_retriever.Update();
	UpdateConnectedIcon();
	username_field.Update();
    if(!post_init_run){
		PostInit();
        post_init_run = true;
    }

    if(connected_to_server){
		if(update_timer > interval){
			UpdatePlayerVariables();
	        SendPlayerUpdate();
			update_timer = 0;
	    }
	    update_timer += time_step;
        ReceiveServerUpdate();
		KeyChecks();
    }else{
        PreConnectedKeyChecks();
        ConnectToServer();
    }
	// process any messages produced from the update
    while( imGUI.getMessageQueueSize() > 0 ) {
        IMMessage@ message = imGUI.getNextMessage();
		Log( info, "Got processMessage " + message.name );
		if( message.name == "" ){return;}
		else if( message.name == "server_chosen" ){
			int index = message.getInt(0);
			@current_server = server_retriever.online_servers[index];
			currentUIState++;
	        RefreshUI();
		}
		else if( message.name == "previous_ui" ){
			if(currentUIState > 0){
				currentUIState--;
		        RefreshUI();
			}
		}
		else if( message.name == "disconnect" ){
			Log(info, "Received message to disconnect from server");
	        DisconnectFromServer();
			RemoveUI();
		}
		else if( message.name == "activate_search" ){
			username_field.Activate();
		}
	}
	SeparateMessages();
	if(GetInputPressed(0, "p")){
		/*chat.AddMessage("Content" + rand(), "server", true);
		chat.AddMessage("Content" + rand(), "Person", false);*/
		/*chat.AddMessage("Content" + rand(), username, false);*/
		/*ReadServerList();*/
		array<uint8> new_data = {ServerInfo};
		SendData(new_data);
	}
	UpdateInput();
}

void UpdateConnectedIcon(){
	if(connected_icon_state && !connected_to_server){
		Print("Adding icon\n");
		IMImage icon(disconnected_icon);
		icon.setSize(vec2(100, 100));
		imGUI.getHeader().setElement(icon);
		connected_icon_state = false;
	}else if(!connected_icon_state && connected_to_server){
		Print("Adding icon\n");
		IMImage icon(connected_icon);
		icon.setSize(vec2(100, 100));
		imGUI.getHeader().setElement(icon);
		connected_icon_state = true;
	}
}

void SeparateMessages(){
	if(data_collection.size() < 1){
		return;
	}
	uint message_size = data_collection[0];
	if( data_collection.size() <= message_size ){
		return;
	}
	array<uint8> message;
	for(uint i = 1; i <= message_size; i++){
		message.insertLast(data_collection[i]);
	}
	data_collection.removeRange(0, message_size + 1);
	/*Print("Message size " + message.size() + "\n");*/
	ProcessIncomingMessage(message);
}

void SetWindowDimensions(int w, int h)
{
	imGUI.doScreenResize();
}

void PreConnectedKeyChecks(){
    if(GetInputPressed(ReadCharacter(player_id).controller_id, "f12") && !trying_to_connect){
		Print("pressed f12\n");
		if(cc_ui_added){
			RemoveUI();
			server_retriever.server_index = 0;
			server_retriever.online_servers.resize(0);
		}else{
			AddUI();
			//TODO just for debugging
			/*currentUIState++;*/
		}
    }
	else if(GetInputPressed(ReadCharacter(player_id).controller_id, "f5")){
		
	}
}

void KeyChecks(){
	int controller_id = ReadCharacter(player_id).controller_id;

	if(GetInputPressed(controller_id, "return")) {
		//TODO closing and opening chat.
	}
	else if(GetInputDown(controller_id, "f10")) {
		if(!showing_playerlist) {
			//TODO show player list while f10 is being pressed
			showing_playerlist = true;
		}
	}
	else if(showing_playerlist && !GetInputDown(controller_id, "f10")) {
		//TODO don't show playerlist anymore.
		showing_playerlist = false;
	}
	else if(GetInputPressed(controller_id, "k")) {
		if((permanent_health > 0) && (temp_health > 0)) {
			SendSavePosition();
		}
	}
	else if(GetInputPressed(controller_id, "l")) {
		if((permanent_health > 0) && (temp_health > 0)) {
			SendLoadPosition();
		}
	}else if(GetInputPressed(controller_id, "f12")){
		Print("pressed f12\n");
		if(cc_ui_added){
			Print("removecleintconnect\n");
			RemoveUI();
			server_retriever.server_index = 0;
			server_retriever.online_servers.resize(0);
		}else{
			Print("addcleintconnect\n");
			AddUsernameUI();
			start_adding_cc_ui = true;
			server_retriever.checking_servers = true;
		}
    }
}

void ConnectToServer(){
    if(trying_to_connect){
        if( main_socket == SOCKET_ID_INVALID ) {
            if( level_name != "") {
                Log( info, "Trying to connect" );
				main_socket = CreateSocketTCP(current_server.address, current_server.port);
                if( main_socket != SOCKET_ID_INVALID ) {
                    Log( info, "Connected " + main_socket );
					trying_to_connect = false;
					SendSignOn();
                } else {
                    Log( warning, "Unable to connect" );
                }
            }
        }
		if( !IsValidSocketTCP(main_socket) ){
			Log(info, "Socket no longer valid");
			main_socket = SOCKET_ID_INVALID;
			connected_to_server = false;
			trying_to_connect = false;
		}
    }
}

void DisconnectFromServer(){
	Print("Destroying socket\n");
	DestroySocketTCP(main_socket);
	main_socket = SOCKET_ID_INVALID;
	connected_to_server = false;
}

void SendSavePosition(){
	array<uint8> message;
	message.insertLast(SavePosition);
	SendData(message);
}

void SendLoadPosition(){
	array<uint8> message;
	message.insertLast(LoadPosition);
	SendData(message);
}

void SendSignOn(){
	array<uint8> message;
	message.insertLast(SignOn);
	MovementObject@ player = ReadCharacter(player_id);
	vec3 position = player.position;
		
	addToByteArray(username, @message);
	addToByteArray("Turner", @message);
	addToByteArray(level_name, @message);
	addToByteArray("1.0.0", @message);
	addToByteArray(position.x, @message);
	addToByteArray(position.y, @message);
	addToByteArray(position.z, @message);
	
	
	/*Print("Sending: \n");
	for(uint i = 0; i < message.size(); i++){
		Print("" + message[i]);
	}
	Print("\n");
	Print("Send done.\n");*/
	//message.insertLast('\n'[0]);
	SendData(message);
	//Print(message.writeString(false) + "\n");
}

void SendChatMessage(string chat_message){
	Print("Sendign chat message\n");
	array<uint8> message;
	message.insertLast(Message);
	addToByteArray(username, @message);
	addToByteArray(chat_message, @message);
	SendData(message);
}

array<uint8> toByteArray(string message){
	array<uint8> data;
	for(uint i = 0; i < message.length(); i++){
		data.insertLast(message.substr(i, 1)[0]);
	}
	/*data.insertLast('\n'[0]);*/
	return data;
}

void addToByteArray(string message, array<uint8> @data){
	/*Print("Adding a string to message " + message + "\n");*/
	uint8 message_length = message.length();
	/*Print("Length " + message_length + "\n");*/
	data.insertLast(message_length);
	for(uint i = 0; i < message_length; i++){
		data.insertLast(message.substr(i, 1)[0]);
	}
}

void addToByteArray(float value, array<uint8> @data){
	/*Print("sending " + value + "\n");*/
	array<uint8> bytes = toByteArray(value);
	for(uint i = 0; i < 4; i++){
		data.insertLast(bytes[i]);
	}
}

void addToByteArray(bool value, array<uint8> @data){
	if(value){
		data.insertLast(1);
	}else{
		data.insertLast(0);
	}
}

float GetFloat(array<uint8>@ data, int &start_index){
	array<uint8> b = {data[start_index + 3], data[start_index + 2], data[start_index + 1], data[start_index]};
	/*array<uint8> b = {data[start_index], data[start_index + 1], data[start_index + 2], data[start_index + 3]};*/
	float f = toFloat(b);
	start_index += 4;
	return f;
}

string GetString(array<uint8>@ data, int &start_index){
	array<string> seperated;
	int string_size = data[start_index];
	/*Print("String size " + string_size + "\n");*/
	start_index++;
    for( int i = 0; i < string_size; i++, start_index++ ) {
		//Skip if the char is not an actual number/letter/etc
		if(data[start_index] < 32){
			continue;
		}
        string s('0');
        s[0] = data[start_index];
        seperated.insertLast(s);
    }
	/*Print("result " + join(seperated, "") + "\n");*/
    return join(seperated, "");
}

bool GetBool(array<uint8>@ data, int &start_index){
	
	uint8 b = data[start_index];
	/*Print("bool byte value " + int(b) + "\n");*/
	start_index++;
	if(b == 1){
		return true;
	}else{
		return false;
	}
}

int GetInt(array<uint8>@ data, int &start_index){
	uint8 b = data[start_index];
	start_index++;
	return int(b);
}

array<uint8> toByteArray(float f){
	uint p = fpToIEEE(f);
	array<uint8> bytes(4);
	bytes[0] = p >> 24;
	bytes[1] = p >> 16;
	bytes[2] = p >>  8;
	bytes[3] = p;
	return bytes;
}

float toFloat(array<uint8> bytes){
	uint s = bytes[3] & 0xFF;
        s |= (bytes[2] << 8) & 0xFFFF;
        s |= (bytes[1] << 16) & 0xFFFFFF;
        s |= (bytes[0] << 24);
	
	return fpFromIEEE(s);
}

/*char* request_handler::floatToByteArray(float f) {
	char *array;
	array = (char*)(&f);
	return array;
}*/

void SendPlayerUpdate(){
	
	array<uint8> message;
	message.insertLast(UpdateGame);
	MovementObject@ player = ReadCharacter(player_id);
	vec3 position = player.position;
	
	addToByteArray(player.position.x, @message);
	addToByteArray(player.position.y, @message);
	addToByteArray(player.position.z, @message);
	vec3 player_dir = GetPlayerTargetVelocity();
	/*Print("player_dir " + player_dir.x + " " + player_dir.z + "\n");*/
	addToByteArray(player_dir.x, @message);
	addToByteArray(player_dir.z, @message);
	
	addToByteArray(MPWantsToCrouch, @message);
	addToByteArray(MPWantsToJump, @message);
	addToByteArray(MPWantsToAttack, @message);
	addToByteArray(MPWantsToGrab, @message);
	addToByteArray(MPWantsToItem, @message);
	addToByteArray(MPWantsToDrop, @message);
	addToByteArray(MPWantsToRoll, @message);
	addToByteArray(MPWantsToJumpOffWall, @message);
	addToByteArray(MPActiveBlock, @message);
	
	addToByteArray(blood_damage, @message);
	addToByteArray(blood_health, @message);
	addToByteArray(block_health, @message);
	addToByteArray(temp_health, @message);
	addToByteArray(permanent_health, @message);
	addToByteArray(knocked_out, @message);
	addToByteArray(lives, @message);
	addToByteArray(blood_amount, @message);
	
	addToByteArray(recovery_time, @message);
	addToByteArray(roll_recovery_time, @message);
	addToByteArray(ragdoll_type, @message);
	addToByteArray(blood_delay, @message);
	addToByteArray(cut_throat, @message);
	addToByteArray(state, @message);

	MPWantsToRoll = false;
	MPWantsToJumpOffWall = false;
	MPActiveBlock = false;

	SendData(message);
	//Print(message.writeString(false) + "\n");
	//array<string> messages = {"This is the first message", "and another one", "bloop", "soooo", "hmm yeah"};
	//SendData(messages[rand()%messages.size()]);
}

vec3 GetPlayerTargetVelocity() {
    vec3 target_velocity(0.0f);    
    vec3 right;
    {
        right = camera.GetFlatFacing();
        float side = right.x;
        right.x = -right .z;
        right.z = side;
    }
	int controller_id = ReadCharacter(player_id).controller_id;

    target_velocity -= GetMoveYAxis(controller_id)*camera.GetFlatFacing();
    target_velocity += GetMoveXAxis(controller_id)*right;

    if(length_squared(target_velocity)>1){
        target_velocity = normalize(target_velocity);
    }
    /*if(trying_to_get_weapon > 0){
        target_velocity = get_weapon_dir;
    }*/
    return target_velocity;
}

void ReceiveServerUpdate(){
	
}

void UpdatePlayerVariables(){
	int controller_id = ReadCharacter(player_id).controller_id;
	MovementObject@ player = ReadCharacter(player_id);
    MPWantsToCrouch = GetInputDown(controller_id, "crouch");
    MPWantsToJump = GetInputDown(controller_id, "jump");
    MPWantsToAttack = GetInputDown(controller_id, "attack");
    MPWantsToGrab = GetInputDown(controller_id, "grab");
    MPWantsToItem = GetInputDown(controller_id, "item");
    MPWantsToDrop = GetInputDown(controller_id, "drop");

	blood_damage = player.GetFloatVar("blood_damage");
	blood_health = player.GetFloatVar("blood_health");
	block_health = player.GetFloatVar("block_health");
	temp_health = player.GetFloatVar("temp_health");
	permanent_health = player.GetFloatVar("permanent_health");
	blood_amount = player.GetFloatVar("blood_amount");
	recovery_time = player.GetFloatVar("recovery_time");
	roll_recovery_time = player.GetFloatVar("roll_recovery_time");
	knocked_out = player.GetIntVar("knocked_out");
	//lives = player.GetIntVar("lives");
	ragdoll_type = player.GetIntVar("ragdoll_type");
	blood_delay = player.GetIntVar("blood_delay");
	state = player.GetIntVar("state");
	cut_throat = player.GetBoolVar("cut_throat");

    if(GetInputPressed(controller_id, "crouch")) {
      MPWantsToRoll = true;
    }
    if(GetInputPressed(controller_id, "jump")) {
      MPWantsToJumpOffWall = true;
    }
    if(GetInputPressed(controller_id, "grab")) {
      MPActiveBlock = true;
    }
    //dir_x = ReadCharacter(player_id).GetFloatVar("GetTargetVelocity().x");
    //dir_z = ReadCharacter(player_id).GetFloatVar("GetTargetVelocity().y");
    //Log(info, dir_x + " dir_x");
    //Log(info, dir_z + " dir_z");
}

void UpdateInput(){
	chat.Update();
}

void SendData(array<uint8> message){
    if( IsValidSocketTCP(main_socket) )
    {
        /*Log(info, "Sending data" );
        Log(info, "Data size " + message.size() );*/
        SocketTCPSend(main_socket,message);
    }
    else
    {
		Log(info, "Socket no longer valid");
        main_socket = SOCKET_ID_INVALID;
		connected_to_server = false;
		trying_to_connect = false;
    }
}

int GetPlayerCharacterID() {
    int num = GetNumCharacters();
    for(int i=0; i<num; ++i){
        MovementObject@ char = ReadCharacter(i);
        if(char.controlled){
            return i;
        }
    }
    return -1;
}
bool HasFocus(){
	return false;
}

class Chat{
	IMDivider@ chat_divider;
	IMDivider@ chat_input_divider;
	IMDivider@ chat_query_divider;
	IMText@ chat_message_label;
	float chat_width = 1000.0f;
	float chat_height = 50.0f;
	int move_in_time = 250;
	int fade_out_time = 2500;
	string white_background = "Textures/ui/menus/main/white_square.png";
	array<ChatMessage@> chat_messages;
	uint num_chat_messages = 5;
	string new_chat_message = "";
	int current_index = 0;
	int cursor_offset = 0;
	bool chat_input_shown = false;
	vec4 own_message_color(0.0, 0.80, 0.50, 0.5);
	vec4 other_message_color(0.0, 0.50, 0.80, 0.5);
	vec4 server_message_color(1.0, 1.0, 1.0, 0.5);
	IMPulseAlpha pulse_cursor(1.0f, 0.0f, 2.0f);
	void Initialize(){
		IMDivider whole_chat("whole_chat", DOVertical);
		
		@chat_divider = IMDivider("chat_divider", DOVertical);
		@chat_input_divider = IMDivider("chat_input_divider", DOVertical);
		
		whole_chat.append(chat_divider);
		whole_chat.append(chat_input_divider);
		
		whole_chat.setAlignment(CACenter, CATop);
		/*chat_divider.setAlignment(CACenter, CATop);*/
		imGUI.getFooter().setAlignment(CACenter, CATop);
		
		//chat_divider.showBorder();
		imGUI.getFooter().setElement(whole_chat);
	}
	void AddMessage(string message_, string source_, bool notif_){
		chat_divider.clear();
		vec4 background_color;
		if(source_ == username){
			background_color = own_message_color;
		}else if(source_ == "server"){
			background_color = server_message_color;
		}else{
			background_color = other_message_color;
		}
		Print("add from " + source_ + "\n" );
		chat_messages.insertLast(ChatMessage(message_, source_, notif_, background_color));
		DrawChat();
	}
	void DrawChat(){
		for(uint i = 0; i < chat_messages.size(); i++){
			DrawMessage(chat_messages[i], i);
		}
		if(chat_messages.size() > num_chat_messages){
			chat_messages.removeAt(0);
		}
	}
	void DrawMessage(ChatMessage@ chat_message, uint index){
		float left_offset = 25.0f;
		float background_size_offset = 10.0f;
		float source_width = 200.0f;
		float move_distance = 0;
		
		if(index == (chat_messages.size() - 1) ){
			move_distance = num_chat_messages * chat_height;
		}else if((chat_messages.size() - 1) == num_chat_messages){
			move_distance = chat_height;
		}
		
		IMDivider whole_divider("whole_divider", DOHorizontal);
		whole_divider.addUpdateBehavior(IMMoveIn ( move_in_time, vec2(0, move_distance), inSineTween ), "");
		
		IMDivider message_divider("message_divider", DOHorizontal);
		IMContainer message_container(chat_width, chat_height);
		/*message_container.showBorder();*/
		message_container.setAlignment(CALeft, CACenter);
		IMImage background(white_background);
		
		FontSetup username_font = main_font;
		username_font.color = chat_message.background_color;
		username_font.color.a = 1.0f;
		
		message_divider.appendSpacer(left_offset);
		message_divider.setZOrdering(2);
		background.setZOrdering(0);
		background.showBorder();
		background.setBorderColor(vec4(0,0,0,0.25));
		background.setBorderSize(1.0f);
		background.setColor(chat_message.background_color);
		message_container.addFloatingElement(background, "background", vec2(0.0f));
		
		message_container.setElement(message_divider);
		if(chat_message.notif){
			IMText message_text(chat_message.message, main_font);
			message_divider.append(message_text);
			background.setSize(vec2(chat_width - background_size_offset, chat_height - background_size_offset));
		}else{
			IMDivider source_divider("source_divider", DOHorizontal);
			IMContainer source_container(source_width, chat_height);
			
			source_container.setAlignment(CALeft, CACenter);
			source_container.setElement(source_divider);
			background.setSize(vec2(chat_width - source_width - background_size_offset, chat_height - background_size_offset));
			message_container.setSizeX(chat_width - source_width);
			
			IMText label_source(chat_message.source, username_font);
			IMText label_text(chat_message.message, main_font);
			whole_divider.append(source_container);
			source_divider.append(label_source);
			message_divider.append(label_text);
		}
		whole_divider.append(message_container);
		chat_divider.append(whole_divider);
	}
	void AddChatInput(){
		MovementObject@ player = ReadCharacter(player_id);
		player.velocity = vec3(0);
		player.Execute("SetState(_ground_state);");
		player.Execute("this_mo.SetAnimation(\"Data/Animations/r_actionidle.anm\", 20.0f);");
		
		@chat_query_divider = IMDivider("new_chat_divider", DOHorizontal);
		IMContainer new_chat_container(chat_width, chat_height);
		IMImage background(white_background);
		
		chat_query_divider.setZOrdering(2);
		background.setZOrdering(0);
		
		background.setSize(vec2(chat_width, chat_height));
		background.setColor(vec4(0,0,0,0.55));
		new_chat_container.addFloatingElement(background, "background", vec2(0));
		new_chat_container.addUpdateBehavior(IMMoveIn ( move_in_time, vec2(0, chat_height), inSineTween ), "");
		new_chat_container.setElement(chat_query_divider);
		
		FontSetup input_font = main_font;
		input_font.color = vec4(1);
		input_font.shadowed = true;
		@chat_message_label = IMText(new_chat_message, input_font);
		IMText cursor("_", input_font);
		chat_message_label.setZOrdering(2);
		cursor.setZOrdering(2);
		
		cursor.addUpdateBehavior(pulse_cursor, "");
		chat_query_divider.append(chat_message_label);
		chat_query_divider.append(cursor);
		chat_input_divider.append(new_chat_container);
		initial_sequence_id = 0;
		chat_input_shown = true;
	}
	void SetCurrentChatMessage(){
		FontSetup input_font = main_font;
		input_font.color = vec4(1);
		input_font.shadowed = true;
		
		chat_query_divider.clear();
		@chat_message_label = IMText("", input_font);
		chat_query_divider.append(chat_message_label);
		IMText cursor("_", input_font);
		cursor.addUpdateBehavior(pulse_cursor, "");
		chat_message_label.setText(new_chat_message);
		chat_query_divider.append(cursor);
	}
	void RemoveChatInput(){
		if(chat_input_shown){
			MovementObject@ player = ReadCharacter(player_id);
			player.Execute("SetState(_movement_state);");
			chat_input_divider.clear();
			new_chat_message = "";
			chat_input_shown = false;
		}
	}
	void Update(){
		if(!cc_ui_added){
			if(chat_input_shown){
				array<KeyboardPress> inputs = GetRawKeyboardInputs();
				if(inputs.size() > 0){
					uint16 possible_new_input = inputs[inputs.size()-1].s_id;
					if(possible_new_input != uint16(initial_sequence_id)){
						uint32 keycode = inputs[inputs.size()-1].keycode;
						initial_sequence_id = inputs[inputs.size()-1].s_id;
						uint max_query_length = 60;
						bool get_upper_case = false;
						
						/*Print("keycode " + keycode + "\n");*/
						
						if(GetInputDown(ReadCharacter(player_id).controller_id, "shift")){
							get_upper_case =true;
						}
						
						array<int> ignore_keycodes = {27};
						if(ignore_keycodes.find(keycode) != -1 || keycode > 500){
							return;
						}
						
						//Backspace
						if(keycode == 8){
							//Check if there are enough chars to delete the last one.
							if(new_chat_message.length() - cursor_offset > 0){
								uint new_length = new_chat_message.length() - 1;
								if(new_length >= 0 && new_length <= max_query_length){
									new_chat_message.erase(new_chat_message.length() - cursor_offset - 1, 1);
									SetCurrentChatMessage();
									return;
								}
							}else{
								return;
							}
						}
						//Delete pressed
						else if(keycode == 127){
							if(cursor_offset > 0){
								new_chat_message.erase(new_chat_message.length() - cursor_offset, 1);
								cursor_offset--;
								SetCurrentChatMessage();
							}
							return;
						}
						if(new_chat_message.length() == max_query_length){
							return;
						}
						if(get_upper_case){
							keycode = ToUpperCase(keycode);
						}
						string new_character('0');
						new_character[0] = keycode;
						new_chat_message.insert(new_chat_message.length() - cursor_offset, new_character);
						SetCurrentChatMessage();
					}
				}
				if(GetInputPressed(0, "return")){
					if(new_chat_message.length() > 0){
						SendChatMessage(new_chat_message);
					}
					current_index = 0;
					cursor_offset = 0;
					RemoveChatInput();
				}
			}else{
				if(GetInputPressed(0, "return")){
					AddChatInput();
				}
			}
		}
	}
}
class ChatMessage{
	string source;
	string message;
	bool notif;
	vec4 background_color;
	ChatMessage(string message_, string source_, bool notif_, vec4 background_color_){
		message = message_;
		source = source_;
		notif = notif_;
		background_color = background_color_;
	}
}
