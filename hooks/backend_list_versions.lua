function PLUGIN:BackendListVersions(ctx)
    local json = require("json")
    local semver = require("semver")
    local http = require("http")

    local os = RUNTIME.osType:lower()
    if os == "macos" then os = "darwin" end
    
    local arch = RUNTIME.archType:lower()
    if arch == "x86_64" or arch == "amd64" then
        arch = "x64"
    elseif arch == "aarch64" then
        arch = "arm64"
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

    local current_patterns = patterns[os] and patterns[os][arch]
    if not current_patterns then
        error("Unsupported OS/Arch: " .. os .. "/" .. arch)
    end

    local api_url = "https://api.github.com/repos/llvm/llvm-project/releases?per_page=100"
    local resp, err = http.get({ url = api_url })

    if err then
        error("Failed to fetch releases: " .. err)
    end
    if resp.status_code ~= 200 then
        error("GitHub API returned " .. resp.status_code)
    end

    local releases = json.decode(resp.body)
    local versions = {}

    for _, release in ipairs(releases) do
        local version = release.tag_name:match("^llvmorg%-(%d+%.%d+%.%d+)$")
        if version then
            local has_matching_asset = false
            for _, asset in ipairs(release.assets) do
                if not asset.name:match("rc%d+") then
                    for _, pattern in ipairs(current_patterns) do
                        if asset.name:match(pattern) then
                            has_matching_asset = true
                            break
                        end
                    end
                end
                if has_matching_asset then break end
            end

            if has_matching_asset then
                table.insert(versions, version)
            end
        end
    end

    if #versions == 0 then
        error("No versions found for " .. ctx.tool .. " on " .. os .. "/" .. arch)
    end

    return { versions = semver.sort(versions) }
end
