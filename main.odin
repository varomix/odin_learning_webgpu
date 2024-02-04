package tutorial1_window

import "core:fmt"
import "core:runtime"

import sdl "vendor:sdl2"

// wgpu
import wgpu_sdl "libs/wgpu/utils/sdl"
import wgpu "libs/wgpu/wrapper"

main :: proc() {
	fmt.println("Hello from the GPU side")

	sdl_flags := sdl.InitFlags{.VIDEO, .EVENTS}

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

	// create descriptor
	desc := wgpu.Instance_Descriptor{}

	instance, inst_err := wgpu.create_instance(&desc)
	defer wgpu.instance_release(&instance)

	if inst_err != .No_Error {
		fmt.eprintf("Could not initialize WebGPU!\n")
		return
	}
	fmt.println("WGPU instance", instance)

	surface_descriptor, _ := wgpu_sdl.get_surface_descriptor(sdl_window)
	surface, _ := wgpu.instance_create_surface(&instance, &surface_descriptor)
	defer wgpu.surface_release(&surface)

	// Adapter
	adapter_options := wgpu.Request_Adapter_Options {
		compatible_surface = &surface,
	}

	adapter, adapter_err := wgpu.instance_request_adapter(&instance, &adapter_options)
	defer wgpu.adapter_release(&adapter)
	// fmt.println("WGPU adapter", adapter)
	fmt.println("WGPU adapter features:", adapter.features)

	// Device
	device_desc := wgpu.Device_Descriptor {
		label = "My Device",
	}

	device, queue, _ := wgpu.adapter_request_device(&adapter, &device_desc)
	defer wgpu.device_release(&device)
	defer wgpu.queue_release(&queue)
	fmt.println("Got device: ", device)

	wgpu.device_set_uncaptured_error_callback(&device, onDeviceError, nil)

	// command encoder
	encoderDesc := wgpu.Command_Encoder_Descriptor {
		label = "My command encoder",
	}

	encoder, encoder_err := wgpu.device_create_command_encoder(&device, &encoderDesc)

	wgpu.command_encoder_insert_debug_marker(&encoder, "Do one thing")
	wgpu.command_encoder_insert_debug_marker(&encoder, "Do another thing")

	// Encoder commands into a command buffer
	cmdBufferDescriptor := wgpu.Command_Buffer_Descriptor {
		label = "Command buffer",
	}

	command, command_err := wgpu.command_encoder_finish(&encoder)
	wgpu.command_encoder_release(&encoder)

	// Finally submit the command queue
	fmt.println("Submitting command")
	wgpu.queue_submit(&queue, &command)
	wgpu.command_buffer_release(&command)

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
	}

	fmt.println("Exiting...")

}

onDeviceError :: proc "c" (type: wgpu.Error_Type, message: cstring, user_data: rawptr) {
	context = runtime.default_context()
	fmt.println("Uncaptured device error: type ", type)
	if len(message) != 0 {
		fmt.printf(" ({})\n", message)
	}
}
