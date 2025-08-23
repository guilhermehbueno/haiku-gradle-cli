#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# --- Globals and Configuration ---
# Resolve the real script path, following symlinks.
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink
done
INSTALL_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
VERSION=$(cat "${INSTALL_DIR}/VERSION")
TEMPLATE_DIR="${INSTALL_DIR}/templates"

# --- Colors and Logging ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

log() {
  echo -e "${C_BLUE}==>${C_RESET} ${1}"
}

warn() {
  echo -e "${C_YELLOW}WARN:${C_RESET} ${1}" >&2
}

die() {
  echo -e "${C_RED}ERROR:${C_RESET} ${1}" >&2
  exit 1
}

# --- Utility Functions ---
require_cmd() {
  if ! command -v "$1" &> /dev/null; then
    warn "Required command '$1' is not available in PATH."
    return 1
  fi
  return 0
}

# --- Command Handlers ---
cmd_info() {
  log "Haiku-Gradle CLI Info:"
  echo -e "  ${C_CYAN}Version:${C_RESET}       ${VERSION}"
  echo -e "  ${C_CYAN}Install Dir:${C_RESET}   ${INSTALL_DIR}"
  echo -e "  ${C_CYAN}Templates Dir:${C_RESET} ${TEMPLATE_DIR}"
  echo
  log "Tool Checks:"
  require_cmd "java"
  require_cmd "gradle"
  require_cmd "envsubst"
  log "All checks complete."
}

# --- Command: init ---

# Renders a single template file to a destination, substituting variables.
render() {
  local template_path="$1"
  local dest_path="$2"

  # Export variables so envsubst can see them.
  export PROJECT_NAME
  export PROJECT_PACKAGE
  export JAVA_VERSION
  # These are fixed for now, but could be configurable later.
  export KOTLIN_VERSION="1.9.25"
  export GRADLE_VERSION="8.8"

  # Create the directory for the destination file if it doesn't exist.
  mkdir -p "$(dirname "$dest_path")"

  # Use envsubst to replace tokens.
  < "$template_path" envsubst > "$dest_path"
}

# A version of safe_copy_template that renders the file.
safe_render_template() {
  local template_name="$1"
  local dest_dir="$2"
  local force="$3"
  local overwrite_if_exists="${4:-false}" # New fourth argument

  local dest_filename=""
  dest_filename=$(basename "$template_name")

  local src_path="${TEMPLATE_DIR}/${template_name}"
  local dest_path="${dest_dir}/${dest_filename}"

  # Logic for overwriting files.
  if [[ -f "$dest_path" && "$force" != "true" ]]; then
    if [[ "$overwrite_if_exists" != "true" ]]; then
      # Default behavior: check for @generated
      if ! head -n 1 "$dest_path" | grep -q "@generated"; then
        warn "Skipping non-generated file: $(realpath --relative-to="$PWD" "$dest_path")"
        return
      fi
    fi
  fi

  log "Generating $(realpath --relative-to="$PWD" "$dest_path")"
  render "$src_path" "$dest_path"
}

# Appends a patch to a file if the managed markers are not present.
apply_patch() {
  local patch_name="$1"
  local target_file="$2"

  local patch_file="${TEMPLATE_DIR}/kts/${patch_name}"
  local marker="Section managed by haiku-gradle"

  if grep -q "$marker" "$target_file"; then
    warn "Markers already exist in $(realpath --relative-to="$PWD" "$target_file"), skipping patch."
    return
  fi

  log "Patching $(realpath --relative-to="$PWD" "$target_file")"
  # Render the patch to a temporary file
  local temp_patch
  temp_patch=$(mktemp)
  render "$patch_file" "$temp_patch"

  # Prepend the rendered patch to the target file
  local original_content
  original_content=$(cat "$target_file")

  # Write the patch first, then the original content.
  cat "$temp_patch" > "$target_file"
  echo "" >> "$target_file" # Add a newline
  echo "$original_content" >> "$target_file"

  rm "$temp_patch"
}


cmd_init() {
  # --- Default values ---
  local path="."
  local project_name=""
  local project_package=""
  local type="app" # app | lib
  local force="false"
  local dry_run="false"
  local java_version="17"

  # --- Argument Parsing ---
  # This is a bit complex to handle both positional path and flags.
  # We'll first extract flags, then the positional argument.
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) project_name="$2"; shift 2 ;;
      --package) project_package="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --java-version) java_version="$2"; shift 2 ;;
      --force) force="true"; shift 1 ;;
      --dry-run) dry_run="true"; shift 1 ;;
      -*) die "Unknown option: $1" ;;
      *) args+=("$1"); shift 1 ;;
    esac
  done

  # Restore positional arguments
  set -- "${args[@]}"
  if [[ $# -gt 0 ]]; then
    path="$1"
  fi

  # --- Resolve Project Properties ---
  local target_dir
  target_dir=$(realpath "$path")

  if [[ -z "$project_name" ]]; then
    project_name=$(basename "$target_dir")
  fi

  if [[ -z "$project_package" ]]; then
    # Sanitize project name for package name
    local sanitized_name
    sanitized_name=$(echo "$project_name" | tr -d '[:space:]' | tr '-' '_' | tr '[:upper:]' '[:lower:]')
    project_package="com.example.${sanitized_name}"
  fi

  # --- Set global exports for templates ---
  export PROJECT_NAME="$project_name"
  export PROJECT_PACKAGE="$project_package"
  export JAVA_VERSION="$java_version"

  log "Project Configuration:"
  echo -e "  ${C_CYAN}Project Name:${C_RESET}  ${project_name}"
  echo -e "  ${C_CYAN}Base Package:${C_RESET}  ${project_package}"
  echo -e "  ${C_CYAN}Project Type:${C_RESET}  ${type}"
  echo -e "  ${C_CYAN}Java Version:${C_RESET}  ${java_version}"
  echo -e "  ${C_CYAN}Target Dir:${C_RESET}    ${target_dir}"
  echo -e "  ${C_CYAN}Force Create:${C_RESET}  ${force}"
  echo -e "  ${C_CYAN}Dry Run:${C_RESET}       ${dry_run}"

  if [[ "$dry_run" == "true" ]]; then
    log "Dry run enabled. No files will be changed."
  fi

  # --- Pre-flight checks ---
  if [[ -d "$target_dir" && "$force" != "true" ]]; then
    if [ "$(ls -A "$target_dir")" ]; then
       die "Target directory '${target_dir}' is not empty. Use --force to overwrite."
    fi
  fi
  mkdir -p "$target_dir"

  # --- Run gradle init ---
  local gradle_type="kotlin-application"
  if [[ "$type" == "lib" ]]; then
    gradle_type="kotlin-library"
  fi

  log "Running 'gradle init'..."
  if [[ "$dry_run" != "true" ]]; then
    gradle init \
      --type "$gradle_type" \
      --dsl "kotlin" \
      --project-name "$project_name" \
      --package "$project_package" \
      --no-incubating \
      --project-dir "$target_dir"
  fi

  # --- Modify Gradle Init Output ---
  if [[ "$dry_run" != "true" ]]; then
    if [[ "$type" == "app" ]]; then
      local app_build_gradle="${target_dir}/app/build.gradle.kts"
      if [[ -f "$app_build_gradle" ]]; then
        log "Removing default Guava dependency from app build script..."
        sed -i '/libs.guava/d' "$app_build_gradle"
      fi
    fi
  fi

  # --- Copy and Render Templates ---
  log "Applying haiku-gradle templates..."
  if [[ "$dry_run" != "true" ]]; then
    # Copy common files
    safe_render_template "common/.editorconfig" "$target_dir" "$force" "false"
    safe_render_template "common/.gitattributes" "$target_dir" "$force" "true"
    safe_render_template "common/.gitignore" "$target_dir" "$force" "true"
    safe_render_template "common/README.md" "$target_dir" "$force" "true"

    # Copy version catalog
    safe_render_template "kts/gradle/libs.versions.toml" "${target_dir}/gradle" "$force" "true"

    # Copy CI workflow
    mkdir -p "${target_dir}/.github/workflows"
    safe_render_template "ci/github/.github/workflows/ci.yml" "${target_dir}/.github/workflows" "$force" "true"

    # Apply patches
    local build_gradle_path="${target_dir}/build.gradle.kts"
    if [[ "$type" == "app" ]]; then
      # For apps, gradle init creates a subproject.
      build_gradle_path="${target_dir}/app/build.gradle.kts"
    fi
    apply_patch "settings.gradle.kts.patch" "${target_dir}/settings.gradle.kts"
    apply_patch "build.gradle.kts.patch" "$build_gradle_path"

    # Sample App.kt is generated by gradle init, so we don't need to do anything.
  fi

  log "${C_GREEN}Project '${project_name}' created successfully!${C_RESET}"
  echo
  log "Next steps:"
  echo "  cd ${path}"
  echo "  ./gradlew build"
}

cmd_upgrade() {
  die "The 'upgrade' command is not yet implemented."
}

cmd_help() {
  echo "Haiku-Gradle CLI - A Gradle project scaffolder."
  echo
  echo "Usage: haiku-gradle <command> [options]"
  echo
  echo "Commands:"
  echo "  info      Display installation information and tool checks."
  echo "  init      Initialize a new Gradle project."
  echo "  upgrade   Upgrade the CLI to the latest version."
  echo "  help      Show this help message."
  echo
}

# --- Main Dispatcher ---
main() {
  local cmd="${1:-help}"
  shift || true # handle case where no command is given

  case "${cmd}" in
    info)
      cmd_info "$@"
      ;;
    init)
      cmd_init "$@"
      ;;
    upgrade)
      cmd_upgrade "$@"
      ;;
    help|--help|-h)
      cmd_help
      ;;
    *)
      die "Unknown command: ${cmd}"
      ;;
  esac
}

# --- Run ---
main "$@"
