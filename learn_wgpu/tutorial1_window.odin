package tutorial1_window

import "core:fmt"

import sdl "vendor:sdl2"

// wgpu
import wgpu_sdl "../libs/wgpu/utils/sdl"
import wgpu "../libs/wgpu/wrapper"

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
		"Tutorial 1 Window",
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

	


	main_loop: for {
		e: sdl.Event

		for sdl.PollEvent(&e) {
			#partial switch (e.type) {
			case .QUIT:
				break main_loop

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
