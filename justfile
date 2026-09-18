project := "Clawde.xcodeproj"
scheme := "Clawde"
# Override deployment target for CI/older Xcode that doesn't know macOS 26.2
xcode_flags := "CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=15.0"
app_name := "Clawde"
team_id := env_var_or_default("DEVELOPMENT_TEAM", "TXQN7T6NNQ")
# The App Group every build shares, team-prefixed as macOS documents. Override
# only to point a build at somebody else's container.
app_group := env_var_or_default("APP_GROUP_ID", team_id + ".com.burakcokyildirim.clawde")

# Calculate version from git tags: tag + .devN for unreleased commits
version := `tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0"); commits=$(git rev-list --count "$tag"...HEAD 2>/dev/null || echo "0"); if [ "$commits" -gt 0 ]; then echo "$tag.dev$commits"; else echo "$tag"; fi`

# Build the Rust plugin binaries and copy to the plugin scripts directory
build-plugin:
    cd clawde-plugin && cargo build --release
    mkdir -p clawde-plugin/plugins/clawde/scripts
    cp clawde-plugin/target/release/session-status clawde-plugin/plugins/clawde/scripts/
    cp clawde-plugin/target/release/set-session-name clawde-plugin/plugins/clawde/scripts/
    codesign -fs - clawde-plugin/plugins/clawde/scripts/session-status
    codesign -fs - clawde-plugin/plugins/clawde/scripts/set-session-name

# Build debug configuration (unsigned, for CI and fast iteration)
build: build-plugin
    xcodebuild -project "{{project}}" -scheme "{{scheme}}" -configuration Debug build {{xcode_flags}} MARKETING_VERSION="{{version}}"

# Run all unit tests
test:
    xcodebuild -project "{{project}}" -scheme "{{scheme}}" -configuration Debug test \
        -only-testing:"ClawdeTests" {{xcode_flags}}

# Run a single test class (e.g., just test-class SessionStateTests)
test-class class:
    xcodebuild -project "{{project}}" -scheme "{{scheme}}" \
        -only-testing:"ClawdeTests/{{class}}" test {{xcode_flags}}

# Clean build artifacts
clean:
    xcodebuild -project "{{project}}" -scheme "{{scheme}}" clean {{xcode_flags}}

# Kill running app, copy signed debug build to /Applications, and relaunch.
# Uses Xcode automatic signing with Apple Development certificate.
swap: build-plugin
    #!/usr/bin/env bash
    set -euo pipefail
    build_dir="/tmp/clawde-swap"
    xcodebuild -project "{{project}}" -scheme "{{scheme}}" -configuration Debug build \
        -derivedDataPath "$build_dir" \
        -allowProvisioningUpdates \
        MACOSX_DEPLOYMENT_TARGET=15.0 \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="{{team_id}}" \
        APP_GROUP_ID="{{app_group}}" \
        MARKETING_VERSION="{{version}}"
    pkill -x "{{app_name}}" || true
    sleep 0.5
    rm -rf "/Applications/{{app_name}}.app"
    cp -R "$build_dir/Build/Products/Debug/{{app_name}}.app" "/Applications/{{app_name}}.app"
    open -a "{{app_name}}"

# Show the calculated version
show-version:
    @echo "{{version}}"

# Sync the full plugin to the installed plugin cache and update the registry
sync-plugin: build-plugin
    rm -rf ~/.claude/plugins/cache/clawde-marketplace/
    mkdir -p ~/.claude/plugins/cache/clawde-marketplace/clawde/{{version}}/
    rsync -a clawde-plugin/plugins/clawde/ \
        ~/.claude/plugins/cache/clawde-marketplace/clawde/{{version}}/
    codesign -fs - ~/.claude/plugins/cache/clawde-marketplace/clawde/{{version}}/scripts/session-status
    codesign -fs - ~/.claude/plugins/cache/clawde-marketplace/clawde/{{version}}/scripts/set-session-name
    python3 -c "\
    import json, pathlib; \
    p = pathlib.Path.home() / '.claude/plugins/installed_plugins.json'; \
    d = json.loads(p.read_text()); \
    key = 'clawde@clawde-marketplace'; \
    ver = '{{version}}'; \
    path = str(pathlib.Path.home() / '.claude/plugins/cache/clawde-marketplace/clawde' / ver); \
    entry = d.get('plugins', {}).get(key, [{}])[0]; \
    entry['installPath'] = path; \
    entry['version'] = ver; \
    d.setdefault('plugins', {})[key] = [entry]; \
    p.write_text(json.dumps(d, indent=2) + '\n')"
