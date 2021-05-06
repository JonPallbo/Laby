module Laby

##########################################################################

module ExternalInput
export extract_image_from_file, extract_text_from_file
using FileIO, ColorTypes

function missing_file(fileName::String)
	println("""The file \""""*fileName*"""\" is missing.""")
	exit()
end

function extract_image_from_file(fileName::String)
	if !isfile(fileName)
		missing_file(fileName)
	else
		image = RGBA.(load(fileName))
		(r, g, b, a) = (red.(image), green.(image), blue.(image), alpha.(image))
		image = permutedims(cat(r, g, b, a; dims = 3), [3, 1, 2])
		image = round.(UInt8, 255*image)
		return image::Array{UInt8, 3}
	end
end

function extract_text_from_file(fileName::String)
	if !isfile(fileName)
		missing_file(fileName)
	else
		return read(fileName, String)::String
	end
end

end # ExternalInput

##########################################################################
##########################################################################

module LabyCore
export act!
using ..ExternalInput

struct Graphics
	static::Dict{String, Array{UInt8, 3}}
	animationFrames::Dict{String, Array{UInt8, 3}}
	animation::Dict{String, Array{String, 1}}
end

struct Cosmos
	cellSize::Int
	width::Int
	height::Int
end

mutable struct Knuffis
	x::Int
	y::Int
	orientation::String
	finished::Bool
end

mutable struct Cell
	x::Int
	y::Int
	nature::String
	id::String
	passable::Bool
	top::Array{String, 1}
	middle::Array{String, 1}
	bottom::Array{String, 1}
	topAniStack::Array{String, 1}
	middleAniStack::Array{String, 1}
	bottomAniStack::Array{String, 1}
	changed::Bool
end

mutable struct World
	knuffis::Knuffis
	cells::Array{Cell, 2}
	addresses::Dict{String, NamedTuple}
	completed::Bool
end

function load_graphics()
	
	statics = [
	
	"knuffis_north";
	"knuffis_east";
	"knuffis_south";
	"knuffis_west";
	
	"wall";
	
	"corridor_0000";
	"corridor_0001";
	"corridor_0010";
	"corridor_0011";
	"corridor_0100";
	"corridor_0101";
	"corridor_0110";
	"corridor_0111";
	"corridor_1000";
	"corridor_1001";
	"corridor_1010";
	"corridor_1011";
	"corridor_1100";
	"corridor_1101";
	"corridor_1110";
	
	"port_NS_closed";
	"port_NS_open";
	"port_EW_closed";
	"port_EW_open";
	
	"closer_unpressed";
	"closer_pressed";
	"opener_unpressed";
	"opener_pressed";
	
	"blue";
	"cyan";
	"green";
	"yellow";
	"red";
	"purple";
	
	"goal"
	
	]
	
	imgStatics = extract_image_from_file.("graphics/static/".*statics.*".png")
	
	animationFrames = [
	
	"knuffis_north_a1f1"; # 1
	"knuffis_north_a1f2"; # 2
	"knuffis_north_a1f3"; # 3
	
	"knuffis_east_a1f1"; # 4
	"knuffis_east_a1f2"; # 5
	"knuffis_east_a1f3"; # 6
	
	"knuffis_south_a1f1"; # 7
	"knuffis_south_a1f2"; # 8
	"knuffis_south_a1f3"; # 9
	
	"knuffis_west_a1f1"; # 10
	"knuffis_west_a1f2"; # 11
	"knuffis_west_a1f3"; # 12
	
	"port_NS_a1f1"; # 13
	"port_NS_a1f2"; # 14
	"port_NS_a1f3"; # 15
	"port_NS_a1f4"; # 16
	"port_NS_a1f5"; # 17
	"port_NS_a1f6"; # 18
	"port_NS_a1f7"; # 19
	"port_NS_a1f8"; # 20
	"port_NS_a1f9"; # 21
	
	"port_EW_a1f1"; # 22
	"port_EW_a1f2"; # 23
	"port_EW_a1f3"; # 24
	"port_EW_a1f4"; # 25
	"port_EW_a1f5"; # 26
	"port_EW_a1f6"; # 27
	"port_EW_a1f7"; # 28
	"port_EW_a1f8"; # 29
	"port_EW_a1f9" # 30
	
	]
	
	imgAnimationFrames = extract_image_from_file.("graphics/animation/".*animationFrames.*".png")
	
	animation = Dict(
	"knuffis_north_finished" => animationFrames[[1; 2; 3; 2; 1; 2; 3; 2; 1]],
	"knuffis_east_finished" => animationFrames[[4; 5; 6; 5; 4; 5; 6; 5; 4]],
	"knuffis_south_finished" => animationFrames[[7; 8; 9; 8; 7; 8; 9; 8; 7]],
	"knuffis_west_finished" => animationFrames[[10; 11; 12; 11; 10; 11; 12; 11; 10]],
	"port_NS_opening" => animationFrames[13:21],
	"port_EW_opening" => animationFrames[22:30],
	"port_NS_closing" => reverse(animationFrames[13:21]),
	"port_EW_closing" => reverse(animationFrames[22:30]))
	
	graphics = Graphics(Dict(statics .=> imgStatics), Dict(animationFrames .=> imgAnimationFrames), animation)
	
	return graphics::Graphics
	
end

function big_bang(fileName::String)
	
	function create_cosmos(scripture::Array{String, 1})
		cellSize = 50
		width = parse(Int, split(scripture[1], ",")[2])
		height = parse(Int, split(scripture[1], ",")[1])
		return Cosmos(cellSize, width, height)::Cosmos
	end
	
	function create_world(scripture::Array{String, 1})
		
		scripture = scripture[2:end]
		
		knuffis = Knuffis(0, 0, "", false)
		cells = Array{Cell}(undef, cosmos.height, cosmos.width)
		addresses = Dict{String, NamedTuple}()
		completed = false
		world = World(knuffis, cells, addresses, completed)
		
		for s in scripture
			
			y = parse(Int, split(split(s, ":")[1], ",")[1])
			x = parse(Int, split(split(s, ":")[1], ",")[2])
			
			seen = split(split(split(s, ":")[2], "#")[1], ",")
			unseen = split(split(s, "#")[2], "_")
			
			if split(seen[2], "_")[1] == "knuffis"
				world.knuffis.x = x
				world.knuffis.y = y
				world.knuffis.orientation = split(seen[2], "_")[2]
			end
			
			nature = unseen[1]
			id = unseen[2]
			if nature in ["corridor" "opener" "closer" "goal"]
				passable = true
			else
				passable = false
			end
			top = split(seen[1], "+")
			middle = split(seen[2], "+")
			bottom = split(seen[3], "+")
			if nature == "port" && split(bottom[1], "_")[3] == "open"
				passable = true
			end
			topAniStack = String[]
			middleAniStack = String[]
			bottomAniStack = String[]
			changed = true
			world.cells[y, x] = Cell(x, y, nature, id, passable, top, middle, bottom, topAniStack, middleAniStack, bottomAniStack, changed)
			
			if !isempty(world.cells[y, x].id)
				world.addresses[world.cells[y, x].nature*"."*world.cells[y, x].id] = (x = x, y = y)
			end
			
		end
		
		return world::World
		
	end
	
	scripture = extract_text_from_file(fileName)
	
	scripture = replace(scripture, "\r\n" => "\n")
	scripture = replace(scripture, "\r" => "\n")
	scripture = replace(scripture, "\t" => "")
	scripture = replace(scripture, " " => "")
	scripture = String.(split(scripture, "\n"; keepempty = false))
	
	cosmos = create_cosmos(scripture)
	world = create_world(scripture)
	
	return cosmos::Cosmos, world::World
	
end

function physics(world::World, action::String, nextFrame::Bool)
	
	function next_frame(aniStack::Array{String, 1})
		
		if isempty(aniStack) || length(aniStack) == 1
			return String[]::Array{String, 1}
		end
		
		if length(aniStack) > 1
			return aniStack[2:end]::Array{String, 1}
		end
		
	end
	
	world = deepcopy(world)
	
	action = split(action, "_");
	
	if action[1] == "moveKnuffis"
		
		world.completed = world.knuffis.finished
		
		cell = world.cells[world.knuffis.y, world.knuffis.x]
		cell.middle = [""]
		cell.changed = true
		
		cell.bottom = replace.(cell.bottom, "pressed" => "unpressed")
		
		world.knuffis.orientation = action[2]
		
		if action[2] == "north" && world.knuffis.y > 1 && world.cells[world.knuffis.y-1, world.knuffis.x].passable
			world.knuffis.y += -1
		elseif action[2] == "east" && world.knuffis.x < cosmos.width && world.cells[world.knuffis.y, world.knuffis.x+1].passable
			world.knuffis.x += 1
		elseif action[2] == "south" && world.knuffis.y < cosmos.height && world.cells[world.knuffis.y+1, world.knuffis.x].passable
			world.knuffis.y += 1
		elseif action[2] == "west" && world.knuffis.x > 1 && world.cells[world.knuffis.y, world.knuffis.x-1].passable
			world.knuffis.x += -1
		end
		
		cell = world.cells[world.knuffis.y, world.knuffis.x]
		cell.middle = ["knuffis_"*world.knuffis.orientation]
		cell.changed = true
		
		cell.bottom = replace.(cell.bottom, "unpressed" => "pressed")
		
		if cell.nature in ["opener" "closer"]
			
			x = world.addresses["port."*cell.id].x
			y = world.addresses["port."*cell.id].y
			
			response = Dict(
			"opener" => (true, "closed" => "opening", "closed" => "open"),
			"closer" => (false, "open" => "closing", "open" => "closed"))
			
			if response[cell.nature][1] != world.cells[y, x].passable
				world.cells[y, x].passable = response[cell.nature][1]
				world.cells[y, x].bottomAniStack = GRAPHICS.animation[replace(world.cells[y, x].bottom[1], response[cell.nature][2])]
				world.cells[y, x].bottom = replace.(world.cells[y, x].bottom, response[cell.nature][3])
				world.cells[y, x].changed = true
			end
			
		elseif cell.nature == "goal"
			cell.middleAniStack = GRAPHICS.animation["knuffis_"*world.knuffis.orientation*"_finished"]
			world.knuffis.finished = true
		end
	
	end
	
	if nextFrame
		for cell in world.cells
			cell.bottomAniStack = next_frame(cell.bottomAniStack)
			cell.middleAniStack = next_frame(cell.middleAniStack)
			cell.topAniStack = next_frame(cell.topAniStack)
		end
	end
	
	return world::World
	
end

function render(world::World, image::Array{UInt8, 3})
	
	function overlay(images::Array{Array{UInt8, 3}, 1})
		subBuffer = images[1][1:3, :, :]
		for i in 2:length(images)
			subBuffer[1, :, :] = round.(UInt8, subBuffer[1, :, :] + (Int16.(images[i][1, :, :]) - subBuffer[1, :, :]) .* (images[i][4, :, :] / 255))
			subBuffer[2, :, :] = round.(UInt8, subBuffer[2, :, :] + (Int16.(images[i][2, :, :]) - subBuffer[2, :, :]) .* (images[i][4, :, :] / 255))
			subBuffer[3, :, :] = round.(UInt8, subBuffer[3, :, :] + (Int16.(images[i][3, :, :]) - subBuffer[3, :, :]) .* (images[i][4, :, :] / 255))
		end
		return subBuffer::Array{UInt8, 3}
	end
	
	world = deepcopy(world)
	image = deepcopy(image)
	
	animationStackSize = 0
	
	for cell in world.cells
		
		animationStackSize = maximum([animationStackSize; length.([cell.bottomAniStack, cell.middleAniStack, cell.topAniStack])])
		
		if cell.changed
			
			cell.changed = false
			
			xStart = (cell.x-1)*cosmos.cellSize+1
			xEnd = cell.x*cosmos.cellSize
			yStart = (cell.y-1)*cosmos.cellSize+1
			yEnd = cell.y*cosmos.cellSize
			
			cellImageStack = Array{Array{UInt8, 3}, 1}(undef, 0)
			strsA = [cell.bottomAniStack, cell.middleAniStack, cell.topAniStack]
			strsS = [cell.bottom, cell.middle, cell.top]
			for i in 1:3
				if !isempty(strsA[i])
					cellImageStack = [cellImageStack; [GRAPHICS.animationFrames[strsA[i][1]]]]
				elseif strsS[i] != [""]
					for str in strsS[i]
						cellImageStack = [cellImageStack; [GRAPHICS.static[str]]]
					end
				end
			end
			
			cellImage = overlay(cellImageStack)
			
			image[:, yStart:yEnd, xStart:xEnd] = cellImage
			
		end
		
	end
	
	return image::Array{UInt8, 3}, animationStackSize::Int
	
end

function act!(action::String, nextFrame::Bool)
	
	if split(action, "_")[1] == "bigBang"
		global cosmos, world = big_bang(String(split(action, "_")[2]))
		global image = UInt8.(zeros(3, cosmos.height*cosmos.cellSize, cosmos.width*cosmos.cellSize))
		action = ""
	end
	
	global world = physics(world, action, nextFrame)
	animationStackSize = 0
	let (i, a) = render(world, image)
		global image = i
		animationStackSize = a
	end
	
	return image::Array{UInt8, 3}, animationStackSize::Int, world.completed::Bool
	
end

global const GRAPHICS = load_graphics()

global cosmos
global world
global image

end # LabyCore

##########################################################################
##########################################################################

module UserInterface
using ..LabyCore, Gtk

mutable struct Level
	n::Int
	complete::Bool
	animationStackSize::Int
	animating::Bool
end

function make_gtk_image(imgRGB::Array{UInt8, 3})
	data = Array{Gtk.RGB}(undef, size(imgRGB)[3], size(imgRGB)[2])
	for y in 1:size(imgRGB)[2], x in 1:size(imgRGB)[3]
		data[x, y] = Gtk.RGB((imgRGB[1, y, x]), (imgRGB[2, y, x]), (imgRGB[3, y, x]))
	end
	pixbuf = GdkPixbuf(data = data, has_alpha = false)
	return GtkImage(pixbuf)::GtkImageLeaf
end

function initialize_level!(resetting::Bool)
	
	if level.n == 0
		global level.n = 1
	elseif resetting
		println("Resetting level "*string(level.n)*"!")
		delete!(window, window[1])
	else
		println("Level "*string(level.n)*" completed!")
		delete!(window, window[1])
		global level.n += 1
	end
	
	filePath = "levels/"*string(level.n, pad = 3)*".world"
	if isfile(filePath)
		global image, level.animationStackSize, level.complete = act!("bigBang_"*filePath, false)
	else
		print("Done!\n")
		exit()
	end
	
	global image = make_gtk_image(image)
	push!(window, image)
	showall(window)
	
	return nothing
	
end

function key_pressed!(window::GtkWindowLeaf, event::Gtk.GdkEventKey)
	
	if !blocked
		
		global blocked = true
		
		if haskey(ACTIONS, event.keyval)
			action = ACTIONS[event.keyval]
		elseif event.keyval == 114 # r
			initialize_level!(true)
		elseif event.keyval == 65307 # escape
			exit()
		end
		
		global image, level.animationStackSize, level.complete = act!(action, false)
		if level.complete
			initialize_level!(false)
		end
		global image = make_gtk_image(image)
		redraw!()
		
		run_animation! = @task begin
			global level.animating = true
			while level.animationStackSize > 0
				animation_action! = @task begin
					global image, level.animationStackSize, level.complete = act!("", true)
					global image = make_gtk_image(image)
					redraw!()
				end
				schedule(animation_action!)
				sleep(0.1)
				wait(animation_action!)
			end
			global level.animating = false
		end
		
		if !level.animating
			schedule(run_animation!)
		end
		
	end
	
	return nothing
	
end

function key_released!(window::GtkWindowLeaf, event::Gtk.GdkEventKey)
	global blocked = false
	return nothing
end

function escaped(window::GtkWindowLeaf)
	exit()
end

function redraw!()
	newPixbuf = get_gtk_property(image, "pixbuf", GdkPixbuf)
	set_gtk_property!(window[1], "pixbuf", newPixbuf)
	reveal(window[1], true)
	return nothing
end

global window = GtkWindow("Laby")
set_gtk_property!(window, "resizable", false)
global image

global level = Level(0, false, 0, false)

initialize_level!(false)

global blocked = false
signal_connect(key_pressed!, window, "key-press-event")
signal_connect(key_released!, window, "key-release-event")
global const ACTIONS = Dict(
65362 => "moveKnuffis_north", # up-arrow
65363 => "moveKnuffis_east", # right-arrow
65364 => "moveKnuffis_south", # down-arrow
65361 => "moveKnuffis_west") # left-arrow

signal_connect(escaped, window, "destroy")

println("\nUse arrow keys to move around.\nPress r to restart level.\nPress escape to quit.\n")

Gtk.gtk_main()

end # UserInterface

##########################################################################

end # Laby
