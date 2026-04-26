function PLUGIN:BackendInstall(ctx)
    local http = require("http")
    local json = require("json")
    local cmd = require("cmd")
    local log = require("log")

    local os_type = RUNTIME.osType:lower()
    if os_type == "macos" then os_type = "darwin" end
    local arch_type = RUNTIME.archType:lower()
    if arch_type == "x86_64" or arch_type == "amd64" then
        arch_type = "x64"
    elseif arch_type == "aarch64" then
        arch_type = "arm64"
    end

    local patterns = {
        darwin = {
            arm64 = { "^clang%+llvm.-%-arm64%-apple%-.-%.tar%.xz$", "^LLVM%-.-%-macOS%-ARM64%.tar%.xz$" },
            x64 = { "^clang%+llvm.-%-x86_64%-apple%-.-%.tar%.xz$", "^LLVM%-.-%-macOS%-X64%.tar%.xz$" },
        },
        linux = {
            arm64 = { "^clang%+llvm.-%-aarch64%-linux%-gnu.-%.tar%.xz$", "^LLVM%-.-%-Linux%-ARM64%.tar%.xz$" },
            x64 = { "^clang%+llvm.-%-x86_64%-linux%-gnu.-ubuntu.-%.tar%.xz$", "^LLVM%-.-%-Linux%-X64%.tar%.xz$" },
        },
        windows = {
            arm64 = { "^LLVM%-.-%-woa64%.exe$" },
            x64 = { "^LLVM%-.-%-win64%.exe$" },
        }
    }

    local current_patterns = patterns[os_type] and patterns[os_type][arch_type]
    if not current_patterns then
        error("Unsupported OS/Arch: " .. os_type .. "/" .. arch_type)
    end

    local api_url = "https://api.github.com/repos/llvm/llvm-project/releases/tags/llvmorg-" .. ctx.version
    local resp, err = http.get({ url = api_url })

    if err then
        error("Failed to fetch release info for " .. ctx.version .. ": " .. err)
    end
    if resp.status_code ~= 200 then
        error("GitHub API returned " .. resp.status_code .. " for version " .. ctx.version)
    end

    local release = json.decode(resp.body)
    local download_url = nil
    local asset_name = nil

    for _, asset in ipairs(release.assets) do
        if not asset.name:match("rc%d+") then
            for _, pattern in ipairs(current_patterns) do
                if asset.name:match(pattern) then
                    download_url = asset.browser_download_url
                    asset_name = asset.name
                    break
                end
            end
        end
        if download_url then break end
    end

    if not download_url then
        error("No suitable asset found for " .. ctx.tool .. "@" .. ctx.version .. " on " .. os_type .. "/" .. arch_type)
    end

    local jsonl_url = nil
    local sig_url = nil
    for _, asset in ipairs(release.assets) do
        if asset.name == asset_name .. ".jsonl" then
            jsonl_url = asset.browser_download_url
        elseif asset.name == asset_name .. ".sig" then
            sig_url = asset.browser_download_url
        end
    end

    cmd.exec("mkdir -p " .. ctx.install_path)

    local temp_file = ctx.install_path .. "/" .. asset_name
    log.info("Downloading " .. download_url .. "...")
    http.download_file({ url = download_url }, temp_file)

    local verified = false
    if jsonl_url then
        local jsonl_file = temp_file .. ".jsonl"
        log.info("Downloading attestation " .. jsonl_url .. "...")
        http.download_file({ url = jsonl_url }, jsonl_file)
        
        local gh_path = cmd.exec("command -v gh || mise which gh || true"):gsub("%s+$", "")
        if gh_path ~= "" then
            log.info("Verifying with gh attestation...")
            local verify_cmd = gh_path .. " attestation verify --repo llvm/llvm-project " .. temp_file .. " --bundle " .. jsonl_file
            local v_res = cmd.exec(verify_cmd .. " 2>&1 || echo 'VERIFY_FAILED'")
            if not v_res:match("VERIFY_FAILED") then
                log.info("GitHub Attestation verified")
                verified = true
            else
                log.warn("GitHub Attestation verification failed: " .. v_res)
            end
        else
            log.warn("gh command not found, skipping attestation verification")
        end
        cmd.exec("rm " .. jsonl_file)
    end

    if not verified and sig_url then
        local sig_file = temp_file .. ".sig"
        log.info("Downloading GPG signature " .. sig_url .. "...")
        http.download_file({ url = sig_url }, sig_file)

        local gpg_check = cmd.exec("command -v gpg || true")
        if gpg_check ~= "" then
            log.info("Verifying with GPG...")
            local keys_url = nil
            for _, asset in ipairs(release.assets) do
                if asset.name == "release-keys.asc" then
                    keys_url = asset.browser_download_url
                    break
                end
            end
            
            if keys_url then
                local keys_file = ctx.install_path .. "/release-keys.asc"
                http.download_file({ url = keys_url }, keys_file)
                cmd.exec("gpg --import " .. keys_file)
                cmd.exec("rm " .. keys_file)
                
                local verify_cmd = "gpg --verify " .. sig_file .. " " .. temp_file
                local v_res = cmd.exec(verify_cmd .. " 2>&1 || echo 'VERIFY_FAILED'")
                if not v_res:match("VERIFY_FAILED") then
                    log.info("GPG signature verified")
                    verified = true
                else
                    log.warn("GPG verification failed: " .. v_res)
                end
            else
                log.warn("release-keys.asc not found in release assets, skipping GPG verification")
            end
        else
            log.warn("gpg command not found, skipping GPG verification")
        end
        cmd.exec("rm " .. sig_file)
    end

    if not verified and (jsonl_url or sig_url) then
        log.warn("Could not verify package integrity for " .. asset_name)
    end

    log.info("Extracting " .. asset_name .. "...")
    if download_url:match("%.tar%.xz$") then
        cmd.exec("tar -xf " .. temp_file .. " -C " .. ctx.install_path .. " --strip-components=1")
    else
        error("Unsupported archive format for " .. download_url)
    end
    
    cmd.exec("rm " .. temp_file)
    return {}
end
