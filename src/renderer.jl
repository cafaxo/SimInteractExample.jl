struct BallInstance{N}
    center::SVector{N,GLfloat}
end

struct BallRenderer
    shader_program::GLuint
    camera_offset_uniform::GLint
    camera_scale_uniform::GLint
    vbo::SimInteract.StreamedBufferObject{BallInstance{2}}
    vao::GLuint
end

function BallRenderer()
    shader_program  = SimInteract.setup_shader_program(shader_path("ball2d.vert"), shader_path("ball2d.frag"))
    glUseProgram(shader_program)

    camera_offset_uniform = glGetUniformLocation(shader_program, "camera_offset")
    camera_scale_uniform = glGetUniformLocation(shader_program, "camera_scale")

    vbo = SimInteract.StreamedBufferObject{BallInstance{2}}(GL_ARRAY_BUFFER, 2^10)
    SimInteract.bind(vbo)

    vao = SimInteract.glGenVertexArray()
    glBindVertexArray(vao)

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 8, Ptr{Cvoid}(0))
    glVertexAttribDivisor(0, 1)
    glEnableVertexAttribArray(0)

    return BallRenderer(shader_program, camera_offset_uniform, camera_scale_uniform, vbo, vao)
end

function add!(renderer::BallRenderer, x::BallConfiguration, camera::SimInteract.Camera2D)
    (; λ, balls) = x

    instances = renderer.vbo.data
    resize!(instances, length(balls))

    offset = SVector(2 * camera.offset[1], -2 * camera.offset[2]) / camera.scale
    offset = Float32.(offset)

    for (i, ball) in enumerate(balls)
        translation = wraparound(ball + offset, λ)

        instances[i] = BallInstance{2}(translation)
    end

    return nothing
end

function draw_torus_rect(
        window_size::SimInteract.WindowSize,
        framebuffer_size::SimInteract.FramebufferSize,
        camera::SimInteract.Camera2D,
        rect::SimInteract.CursorRect,
        λ::Real,
    )
    torus_rect_center = SimInteract.center(rect)
    torus_rect_size = λ*camera.scale/4
    torus_rect = SimInteract.CursorRect(
        torus_rect_center[1] - torus_rect_size,
        torus_rect_center[2] - torus_rect_size,
        2*torus_rect_size,
        2*torus_rect_size,
    )
    torus_rect = intersect(torus_rect, rect)

    framebuffer_rect = SimInteract.FramebufferRect(torus_rect, window_size, framebuffer_size)
    glScissor(framebuffer_rect.x, framebuffer_rect.y, framebuffer_rect.width, framebuffer_rect.height)
    glClearColor(0.2, 0.2, 0.2, 1.0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    return nothing
end

function compute_offset_and_scale(camera::SimInteract.Camera2D, window_size::SimInteract.WindowSize, center::SVector{2,Float64})
    offset = SVector(-1 + 2*center[1] / window_size.width, 1 - 2*center[2] / window_size.height)

    scale = camera.scale * SVector(inv(window_size.width), inv(window_size.height))

    return offset, scale
end

function SimInteract.render(
        renderer::BallRenderer,
        window_size::SimInteract.WindowSize,
        framebuffer_size::SimInteract.FramebufferSize,
        rect::SimInteract.CursorRect,
        camera::SimInteract.Camera2D,
        runner_output,
        viewer_parameters,
    )
    x = runner_output.state.x
    add!(renderer, x, camera)
    SimInteract.bind_and_upload(renderer.vbo)

    glUseProgram(renderer.shader_program)
    glBindVertexArray(renderer.vao)

    glEnable(GL_SCISSOR_TEST)

    draw_torus_rect(window_size, framebuffer_size, camera, rect, x.λ)

    camera_offset, scale = compute_offset_and_scale(camera, window_size, SimInteract.center(rect))

    glUniform2f(renderer.camera_offset_uniform, camera_offset[1], camera_offset[2])
    glUniform2f(renderer.camera_scale_uniform, scale[1], scale[2])

    framebuffer_rect = SimInteract.FramebufferRect(rect, window_size, framebuffer_size)
    glScissor(framebuffer_rect.x, framebuffer_rect.y, framebuffer_rect.width, framebuffer_rect.height)

    glDrawArraysInstanced(GL_TRIANGLE_FAN, 0, 4, length(x.balls))

    glDisable(GL_SCISSOR_TEST)

    return nothing
end
