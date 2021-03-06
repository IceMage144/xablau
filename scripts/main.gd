
extends YSort

const NPC = preload("res://resources/scenes/NPC.tscn")
const Item = preload("res://resources/scenes/item.tscn")

const actList = ["ATO 1: UMA NOVA MISSÃO", "ATO 2: INVESTIGAÇÃO", "CONTINUA..."]

# Json objects
var NPCS
var SCENES
var ITEMS
var SPECIALS

# Shortcuts for nodes
var Box
var Log
var MGH
var LightDim
var DarkLight
var CircLight
var TutText
var BagList
var NPCs = []
var Items = []
var Specials = []

# Other global variables
var blockClick = false
var bagOpen = false
var roomName = null
var room
var act = 0
var faceViews = [false, false]
var next_tutorial = null
var next_change = null
var waiting_click = false

signal finished_act

func _ready():
	SCENES = parse_json("dictionaries/scenes")
	NPCS = parse_json("dictionaries/NPCs")
	ITEMS = parse_json("dictionaries/items")
	SPECIALS = parse_json("dictionaries/specials")
	Box = get_node("DialogueBox")
	Log = get_node("HUD/Log")
	MGH = get_node("MinigameHandler")
	BagList = get_node("HUD/Bag/ItemList")
	LightDim = get_node("Light Dim")
	CircLight = get_node("Circular light")
	TutText = get_node("HUD/Tutorial text")
	DarkLight = get_node("HUD/DarkLight")
	change_act(1)
	load_scene("Car")
	#show_tutorial(Items[2], "pressed", "Clique na máquina de café para pegar um café")

# Recieves the name of a json file and returns it's corresponding
# dictionary
func parse_json(name):
	var dict = {}
	var file = File.new()
	file.open("res://resources/assets/" + name + ".json", file.READ)
	var text = file.get_as_text()
	dict.parse_json(text)
	file.close()
	return dict

# Recieves the name of a scene and loads the room with it's
# NPCs, items and background
func load_scene(name):
	room = SCENES[name]
	roomName = name
	get_node("Background").set_texture(load(room["Background"]))
	Log.clear_text()
	clear_room()
	for i in range(room["Characters"].size()):
		NPCs.append(NPC.instance())
		NPCs[i].set_info(get_NPC(i))
		NPCs[i].set_pos(get_pos("Characters", i))
		add_child(NPCs[i])
	for i in range(room["Items"].size()):
		Items.append(Item.instance())
		Items[i].set_info(get_item(i))
		Items[i].set_pos(get_pos("Items", i))
		add_child(Items[i])
	for i in range(room["Specials"].size()):
		var ins = get_special(i)
		Specials.append(ins.instance())
		Specials[i].set_pos(get_pos("Specials", i))
		add_child(Specials[i])

# Recieves a position "num" of the NPC at the scene's "Characters"
# list and returns it's "key" field. If key == "All", returns a dictionary
# with all keys
func get_NPC(num, key="All"):
	var name = room["Characters"][num]["Name"]
	var ret = {}
	ret["Name"] = name
	ret["Image"] = NPCS[name]["Image"]
	ret["Dialogue"] = NPCS[name]["Dialogue"]
	if key == "All":
		return ret
	return ret[key]
	
# Recieves a position "num" of the item at the scene's "Items"
# list and returns it's "key" field. If key == "All", returns a dictionary
# with all keys
func get_item(num, key="All"):
	var ret = {}
	var name = room["Items"][num]["Name"]
	ret["Name"] = name
	ret["Args"] = room["Items"][num]["Args"]
	ret["Image"] = ITEMS[name]["Image"]
	ret["Function"] = ITEMS[name]["Function"]
	ret["Nickname"] = ITEMS[name]["Nickname"]
	if key == "All":
		return ret
	return ret[key]

# Recieves a position "num" at the scene's "Specials"
# list and returns it's correspondent scene
func get_special(num):
	var name = room["Specials"][num]["Name"]
	return load(SPECIALS[name])

# Recieves a scene "group" (can be "Items" or "Characters") and
# returns the "pos" value of the element number "num" in the group list
func get_pos(group, num):
	var vec = room[group][num]["Pos"]
	return Vector2(vec[0], vec[1])

# Returns the number of the object named "name" at the room's list
func get_num(name):
	for i in range(NPCs.size()):
		#print(room["Characters"][i]["Name"] + " == " + name)
		if NPCs[i].get_name() == name:
			return i
	for i in range(Items.size()):
		#print(room["Items"][i]["Name"] + " == " + name)
		if Items[i].get_name() == name:
			return i
	for i in range(Specials.size()):
		if Specials[i].get_name() == name:
			return i
	return -1

# Clear all the sprites of the room
func clear_room():
	for i in range(NPCs.size()):
		NPCs[i].queue_free()
	for i in range(Items.size()):
		Items[i].queue_free()
	for i in range(Specials.size()):
		Specials[i].queue_free()
	NPCs = []
	Items = []
	Specials = []

# Interprets the dialogue json with name "name" and executes it's
# functions
func run_dialogue(name):
	if blockClick or name == "":
		return
	var dial = parse_json("dialogues/" + name)
	var ctr = "1"
	var mem = "0"
	var foo = null
	var cmd = null
	if bagOpen:
		_bag_open()
	blockClick = true
	Log.clear_text()
	while true:
		cmd = dial[ctr]
		foo = cmd["func"]
		if mem != ctr:
			mem = ctr
		else:
			print("Você caiu no loop infinito do while hur-dur!!")
			break
		if foo == "faceShow":
			# Executes face show animation for character "char" at
			# screen position "pos"
			var char = cmd["char"]
			var pos = cmd["pos"]
			var num = get_num(char)
			var view = "FaceView"+str(pos)
			get_node(view).set_texture(NPCs[num].get_texture())
			get_node(view+"/appear").play("face_appear")
			NPCs[num].set_opacity(0)
			faceViews[pos] = true
			if not (faceViews[0] and faceViews[1]) and (faceViews[0] or faceViews[1]):
				LightDim.get_node("dim").play("make_it_dim")
			yield(get_node(view+"/appear"), "finished")
			ctr = str(int(ctr) + 1)
		elif foo == "faceHide":
			# Executes face hide animation for character "char" at
			# screen position "pos"
			var char = cmd["char"]
			var pos = cmd["pos"]
			var num = get_num(char)
			var view = "FaceView"+str(pos)
			get_node(view+"/appear").play_backwards("face_appear")
			NPCs[num].set_opacity(1)
			faceViews[pos] = false
			if not faceViews[0] and not faceViews[1]:
				LightDim.get_node("dim").play_backwards("make_it_dim")
			yield(get_node(view+"/appear"), "finished")
			get_node(view).set_texture(null)
			ctr = str(int(ctr) + 1)
		elif foo == "dialogueShow":
			# Shows dialogue box with text "text" and pointing to screen
			# position "pos"
			var text = cmd["text"]
			var pos = cmd["pos"]
			Box.change_side(pos)
			Box.get_node("anim").play("pop_up")
			yield(Box.get_node("anim"), "finished")
			Box.print_text(text)
			yield(Box, "ended")
			Box.get_node("anim").play_backwards("pop_up")
			yield(Box.get_node("anim"), "finished")
			ctr = str(int(ctr) + 1)
		elif foo == "say":
			# Shows text "text" at Log
			var text = cmd["text"]
			Log.print_text(text)
			yield(Log, "ended")
			ctr = str(int(ctr) + 1)
		elif foo == "choose":
			# Shows a question "text" and it's possible answers "opts" at Log
			var text = cmd["text"]
			var opts = cmd["opts"]
			var goto = cmd["goto"]
			Log.print_choose(text, opts)
			yield(Log, "ended")
			ctr = goto[Log.option]
		elif foo == "special":
			# Executes the special method of the special object "targ"
			var obj = cmd["targ"]
			var num = get_num(obj)
			Specials[num].specFunc()
			ctr = str(int(ctr) + 1)
		elif foo == "jump":
			# Jumps to line "to"
			ctr = cmd["to"]
		elif foo == "changeDialogue":
			# Change the base dialogue of "char" to "dial"
			var char = cmd["char"]
			var dialogue = cmd["dial"]
			change_dialogue(char, dialogue)
			ctr = str(int(ctr) + 1)
		elif foo == "removeFromScene":
			# Remove the node "name" of type "type" from scene "scn"
			var type = cmd["type"]
			var name = cmd["name"]
			var scene = cmd["scn"]
			var num = get_num(name)
			SCENES[scene][type+"s"].remove(num)
			if roomName == scene:
				if type == "Character":
					NPCs[num].queue_free()
					NPCs.remove(num)
				elif type == "Item":
					Items[num].queue_free()
					Items.remove(num)
				elif type == "Special":
					Specials[num].queue_free()
					Specials.remove(num)
			ctr = str(int(ctr) + 1)
		elif foo == "queueTutorial":
			next_tutorial = cmd["name"]
			ctr = str(int(ctr) + 1)
		elif foo == "queueChangeScene":
			next_change = cmd["scn"]
			ctr = str(int(ctr) + 1)
		elif foo == "End":
			# End the loop
			break
		else:
			print("The function " + foo + " doesn't exists!!!")
	if name == "Rafael_meeting_1":
		var dim = DarkLight.get_node("dim")
		DarkLight.get_node("Act").set_text(actList[1])
		dim.play("change_act")
		yield(dim, "finished")
		dim.play_backwards("show_text")
		yield(dim, "finished")
		DarkLight.get_node("Act").set_text(actList[2])
		dim.play("show_text")
		yield(dim, "finished")
		get_tree().change_scene("res://resources/scenes/Menu.tscn")
		blockClick = false
	if "Rafael_after_report" in name:
		var num
		var num2
		for i in range(SCENES["Workroom"]["Items"].size()):
			if SCENES["Workroom"]["Items"][i]["Name"] == "Door2":
				num = i
			if SCENES["Workroom"]["Items"][i]["Name"] == "Computer":
				num2 = i
		SCENES["Workroom"]["Items"][num]["Args"] = ["MeetingRoom2"]
		SCENES["Workroom"]["Items"][num2]["Args"] = [""]
	blockClick = false
	if next_tutorial:
		run_tutorial(next_tutorial)
		next_tutorial = null
	if next_change:
		change_scene(next_change)
		next_change = null

# Executed when an item is clicked. Runs the function associated
# with that item with the aguments specified in the field "args"
# from SCENES json
func run_item_func(name, foo, args, img):
	if blockClick:
		return
	blockClick = true
	if foo == "":
		blockClick = false
		return
	elif foo == "changeScene":
		if args[0] == "":
			var Time = get_node("Timer")
			Log.show_timed_text("*O seu personagem se recusa a mudar de sala!*")
			Time.start()
			yield(Time, "timeout")
		else:
			var dim = DarkLight.get_node("dim")
			dim.play("change_scene")
			yield(dim, "finished")
			load_scene(args[0])
			dim.play_backwards("change_scene")
	elif foo == "addToBag":
		add_to_bag(name, args[0], args[1])
	elif foo == "runMinigame":
		#get_tree().change_scene("res://resources/scenes/minigames/flowfree/flowfreeCanvas.xscn")
		_on_TestButton_pressed()
	elif foo == "custom":
		if args[0] != "":
			funcref(self, args[0]).call_func()
	blockClick = false
	
func change_dialogue(char, dialogue):
	var num = get_num(char)
	if num != -1:
		NPCs[num].dialogue = dialogue
	NPCS[char]["Dialogue"] = dialogue

# Dims screen and change scene to "scene"
func change_scene(scene):
	blockClick = true
	var dim = DarkLight.get_node("dim")
	dim.play("change_scene")
	yield(dim, "finished")
	load_scene(scene)
	dim.play_backwards("change_scene")
	blockClick = false

# If "what" == "self", add item "name" to the bag and remove item from
# the room, else add "what" to the bag and remove nothing from the room
func add_to_bag(name, what, deleteSelf):
	var item = load(ITEMS[what]["Image"])
	BagList.add_icon_item(item)
	if deleteSelf == "yes":
		var num = get_num(name)
		Items[num].queue_free()
		Items.remove(num)
		SCENES[roomName]["Items"].remove(num)
	var nick = ITEMS[what]["Nickname"]
	Log.show_timed_text("*Você pega " + nick + "*")

# Open/close bag
func _bag_open():
	if blockClick:
		print("Hey")
		return
	if bagOpen:
		BagList.set_pos(Vector2(0, -850))
		bagOpen = false
	else:
		BagList.set_pos(Vector2(0, -425))
		bagOpen = true

func coffee_machine_func():
	var money = -1
	var cup = -1
	for i in range(BagList.get_item_count()):
		if BagList.get_item_icon(i) == load(ITEMS["EmptyCup"]["Image"]):
			cup = i
		elif BagList.get_item_icon(i) == load(ITEMS["MoneyBag"]["Image"]):
			money = i
	if cup == -1:
		BagList.add_icon_item(load(ITEMS["EmptyCup"]["Image"]))
		Log.show_timed_text("*Você pega um copo de café*")
	elif cup != -1 and money == -1:
		Log.show_timed_text("*Você precisa de dinheiro para comprar café!*")
	elif money != -1 and cup != -1:
		if BagList.is_selected(money):
			BagList.remove_item(max(cup, money))
			BagList.remove_item(min(cup, money))
			BagList.add_icon_item(load(ITEMS["CoffeeCup"]["Image"]))
			var num = get_num("CoffeeMachine")
			Items[num].args = [""]
			SCENES[roomName]["Items"][num]["Args"] = [""]
			Log.show_timed_text("*Você coloca dinheiro na máquina e enche o copo de café*")
		else:
			Log.show_timed_text("*Você precisa inserir o dinheiro na máquina primeiro*")
	else:
		print(cup, " ", money)
		print("NOPE")

func is_block():
	return blockClick
	
func get_waiting():
	return waiting_click

func change_act(a):
	blockClick = true
	var dim = DarkLight.get_node("dim")
	DarkLight.get_node("Act").set_text(actList[a-1])
	dim.play("change_act")
	yield(dim, "finished")
	if a == 1:
		var anim = dim.get_animation("change_act")
		anim.add_track(0, 2)
		anim.track_set_path(2, ".:color")
		anim.track_insert_key(2, 0, Color(0, 0, 0, 0))
		anim.track_insert_key(2, 0.5, Color(0, 0, 0, 1))
		dim.add_animation("change_act", anim)
	dim.play_backwards("change_act")
	yield(dim, "finished")
	blockClick = false
	emit_signal("finished_act")

func run_tutorial(name):
	var dial = parse_json("tutorials/" + name)
	var ctr = "1"
	var mem = "0"
	var foo = null
	var cmd = null
	var screen_center = Vector2(512, 212.5)
	var light_size = CircLight.get_texture().get_size()
	var label_size = TutText.get_size()
	var label_rad = label_size.length()/2
	if bagOpen:
		_bag_open()
	Log.clear_text()
	while true:
		cmd = dial[ctr]
		if mem != ctr:
			mem = ctr
		else:
			print("Você caiu no loop infinito do while hur-dur!!")
			break
		var obj
		var obj_size
		if cmd["type"] == "Item":
			var num = get_num(cmd["name"])
			if num == -1:
				ctr = str(int(ctr) + 1)
				continue
			obj = Items[num]
			obj_size = obj.get_texture().get_size()
		elif cmd["type"] == "GUI":
			obj = get_node("HUD/" + cmd["name"])
			obj_size = obj.get_normal_texture().get_size()
		elif cmd["type"] == "End":
			break
		var obj_pos = obj.get_pos()
		var rad = obj_size.length()/2
		var new_pos = obj_pos + obj_size/2
		CircLight.set_scale(2*Vector2(rad, rad)/light_size)
		CircLight.set_pos(new_pos)
		var alpha = (rad+label_rad)/new_pos.distance_to(screen_center)
		TutText.set_pos(alpha*screen_center + (1-alpha)*new_pos - label_size/2)
		CircLight.set_energy(0.4)
		LightDim.set_energy(1)
		TutText.set_text(cmd["text"])
		waiting_click = obj.get_name()
		yield(obj.get_node(cmd["node"]), cmd["evnt"])
		waiting_click = false
		CircLight.set_energy(0)
		LightDim.set_energy(0)
		TutText.set_text("")
		ctr = str(int(ctr) + 1)

func show_tutorial(obj, event, text):
	var obj_size = obj.get_texture().get_size()
	var obj_pos = obj.get_pos()
	var rad = obj_size.length()/2
	var light_size = CircLight.get_texture().get_size()
	var new_pos = obj_pos + obj_size/2
	var label_size = TutText.get_size()
	var label_rad = label_size.length()/2
	var screen_center = Vector2(512, 212.5)
	CircLight.set_scale(2*Vector2(rad, rad)/light_size)
	CircLight.set_pos(new_pos)
	var alpha = (rad+label_rad)/new_pos.distance_to(screen_center)
	TutText.set_pos(alpha*screen_center + (1-alpha)*new_pos - label_size/2)
	CircLight.set_energy(0.4)
	LightDim.set_energy(1)
	TutText.set_text(text)
	waiting_click = obj.get_name()
	yield(obj.get_node("Button"), event)
	waiting_click = false
	CircLight.set_energy(0)
	LightDim.set_energy(0)
	TutText.set_text("")
	
func _on_ItemList_item_activated( index ):
	if BagList.get_item_icon(index) == load(ITEMS["CoffeeCup"]["Image"]):
		BagList.remove_item(index)
		Log.show_timed_text("*Você bebe o copo de café*")

# Test
func _on_TestButton_pressed():
	#if blockClick:
	#	return
	blockClick = true
	var Time = get_node("Timer")
	MGH.run_minigame("flowfree", null)
	yield(MGH, "ended")
	Time.start()
	yield(Time, "timeout")
	MGH.game_close()
	MGH.run_minigame("passBreaker", null)
	yield(MGH, "ended")
	Time.start()
	yield(Time, "timeout")
	MGH.game_close()
	blockClick = false
