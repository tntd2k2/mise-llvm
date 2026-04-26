function PLUGIN:BackendExecEnv(ctx)
    local file = require("file")
    local bin_path = file.join_path(ctx.install_path, "bin")
    local lib_path = file.join_path(ctx.install_path, "lib")
    local include_path = file.join_path(ctx.install_path, "include")

    local env_vars = {
        { key = "PATH", value = bin_path },
    }

    local os = RUNTIME.osType:lower()
    if os == "linux" then
        table.insert(env_vars, { key = "LD_LIBRARY_PATH", value = lib_path })
    elseif os == "darwin" or os == "macos" then
        table.insert(env_vars, { key = "DYLD_LIBRARY_PATH", value = lib_path })
    end

    table.insert(env_vars, { key = "C_INCLUDE_PATH", value = include_path })
    table.insert(env_vars, { key = "CPLUS_INCLUDE_PATH", value = include_path })

    return { env_vars = env_vars }
end
