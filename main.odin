package tutorial1_window

import "core:fmt"
import "core:runtime"

import sdl "vendor:sdl2"

// wgpu
import wgpu_sdl "libs/wgpu/utils/sdl"
import wgpu "libs/wgpu/wrapper"

State :: struct {
	minimized: bool,
	surface:   wgpu.Surface,
	device:    wgpu.Device,
	queue:     wgpu.Queue,
	config:    wgpu.Surface_Configuration,
}

Physical_Size :: struct {
	width:  u32,
	height: u32,
}


main :: proc() {
	fmt.println("Hello from the GPU side")

	sdl_flags := sdl.InitFlags{.VIDEO, .JOYSTICK, .GAMECONTROLLER, .EVENTS}

	if res := sdl.Init(sdl_flags); res != 0 {
		fmt.eprintf("ERROR: Failed to initialize SDL: [%s]\n", sdl.GetError())
		return
	}
	defer sdl.Quit()

	window_flags: sdl.WindowFlags = {.SHOWN, .ALLOW_HIGHDPI, .RESIZABLE}

	sdl_window := sdl.CreateWindow(
		"Tutorial WebGPU - MIX - ]>|<[",
		sdl.WINDOWPOS_CENTERED,
		sdl.WINDOWPOS_CENTERED,
		800,
		600,
		window_flags,
	)
	defer sdl.DestroyWindow(sdl_window)

	if sdl_window == nil {
		fmt.eprintf("ERROR: Failed ti create the SDL Window: [%s]", sdl.GetError())
		return
	}

	state, state_err := init_state(sdl_window)

	if state_err != .No_Error {
		message := wgpu.get_error_message()
		if message != "" {
			fmt.eprintln("ERROR: Failed to initialize program:", message)
		} else {
			fmt.eprintln("ERROR: Failed to initialize program")
		}
		return
	}
	defer {
		wgpu.queue_release(&state.queue)
		wgpu.device_reference(&state.device)
		wgpu.surface_release(&state.surface)
	}

	err := wgpu.Error_Type{}

	main_loop: for {
		e: sdl.Event

		for sdl.PollEvent(&e) {
			#partial switch (e.type) {
			case .QUIT:
				break main_loop

			case .KEYDOWN:
				if e.key.keysym.sym == .ESCAPE {
					break main_loop
				}

			case .WINDOWEVENT:
				#partial switch (e.window.event) {
				case .SIZE_CHANGED:
				case .RESIZED:
				}
			}
		}

		// We will render here...
		if !state.minimized {
			err = render(&state)
			if err != .No_Error do break main_loop
		}
	}

	if err != .No_Error {
		fmt.eprintln("Error occurred while rendering: %v\n", wgpu.get_error_message())
	}

	fmt.println("Exiting...")

}

@(init)
init :: proc() {
	wgpu.set_log_callback(_log_callback, nil)
	wgpu.set_log_level(.Warn)
}

init_state := proc(window: ^sdl.Window) -> (state: State, err: wgpu.Error_Type) {
	// create descriptor
	instance_desc := wgpu.Instance_Descriptor {
		backends = wgpu.Instance_Backend_Primary,
	}

	instance := wgpu.create_instance(&instance_desc) or_return
	defer wgpu.instance_release(&instance)

	surface_descriptor := wgpu_sdl.get_surface_descriptor(window) or_return
	state.surface = wgpu.instance_create_surface(&instance, &surface_descriptor) or_return
	defer if err != .No_Error do wgpu.surface_release(&state.surface)

	// Adapter
	adapter_options := wgpu.Request_Adapter_Options {
		compatible_surface = &state.surface,
	}

	adapter := wgpu.instance_request_adapter(&instance, &adapter_options) or_return
	defer wgpu.adapter_release(&adapter)

	// Device
	device_desc := wgpu.Device_Descriptor {
		label  = adapter.info.name,
		limits = wgpu.Default_Limits,
	}

	state.device, state.queue = wgpu.adapter_request_device(&adapter, &device_desc) or_return
	defer if err != .No_Error {
		wgpu.device_release(&state.device)
		wgpu.queue_release(&state.queue)
	}

	defer if err == .No_Error {
		wgpu.device_set_uncaptured_error_callback(&state.device, onDeviceError, nil)
	}

	caps := wgpu.surface_get_capabilities(&state.surface, &adapter) or_return
	defer {
		delete(caps.formats)
		delete(caps.present_modes)
		delete(caps.alpha_modes)
	}

	width, height: i32
	sdl.GetWindowSize(window, &width, &height)

	state.config = {
		usage = {.Render_Attachment},
		format = wgpu.surface_get_preferred_format(&state.surface, &adapter),
		width = cast(u32)width,
		height = cast(u32)height,
		present_mode = .Fifo,
		alpha_mode = caps.alpha_modes[0],
	}
	wgpu.surface_configure(&state.surface, &state.device, &state.config) or_return

	return state, .No_Error
}

onDeviceError :: proc "c" (type: wgpu.Error_Type, message: cstring, user_data: rawptr) {
	context = runtime.default_context()
	fmt.println("Uncaptured device error: type ", type)
	if len(message) != 0 {
		fmt.printf(" ({})\n", message)
	}
}

_log_callback :: proc "c" (level: wgpu.Log_Level, message: cstring, user_data: rawptr) {
	context = runtime.default_context()
	fmt.eprintf("[wgpu] [%v] %s\n\n", level, message)
}

render :: proc(using state: ^State) -> wgpu.Error_Type {
	frame := wgpu.surface_get_current_texture(&state.surface) or_return
	defer wgpu.texture_release(&frame.texture)

	view := wgpu.texture_create_view(&frame.texture) or_return
	defer wgpu.texture_view_release(&view)

	encoder_desc := wgpu.Command_Encoder_Descriptor {
		label = "Command Encoder",
	}

	encoder := wgpu.device_create_command_encoder(&state.device, &encoder_desc) or_return
	defer wgpu.command_encoder_release(&encoder)

	render_pass := wgpu.command_encoder_begin_render_pass(
		&encoder,
		& {
			label = "Render pass",
			color_attachments = []wgpu.Render_Pass_Color_Attachment {
				 {
					view = &view,
					resolve_target = nil,
					load_op = .Clear,
					store_op = .Store,
					clear_value = {0.9, 0.1, 0.2, 1.0},
				},
			},
			depth_stencil_attachment = nil,
		},
	)
	defer wgpu.render_pass_release(&render_pass)
	wgpu.render_pass_end(&render_pass)

	command_buffer := wgpu.command_encoder_finish(&encoder) or_return
	defer wgpu.command_buffer_release(&command_buffer)

	wgpu.queue_submit(&queue, &command_buffer)
	wgpu.surface_present(&surface)

	return .No_Error
}
