#!/bin/bash

# Lightning.AI specific environment setup
source ${LIGHTNING_PYTHON_VENV:-/opt/conda/bin/activate}
LIGHTNING_APP_STATE_DIR=${LIGHTNING_APP_STATE_DIR:-/root/.lightning/lit_app_state}
WORKSPACE_DIR=${LIGHTNING_WORK_DIR:-/lit_work}
A1111_DIR=${WORKSPACE_DIR}/stable-diffusion-webui

# Packages are installed after nodes so we can fix them...
APT_PACKAGES=(
    #"package-1"
    #"package-2"
)

PIP_PACKAGES=(

)

# Extensions to be installed
EXTENSIONS=(
    "https://github.com/BlafKing/sd-civitai-browser-plus"
    "https://github.com/AUTOMATIC1111/stable-diffusion-webui-promptgen"
    "https://github.com/continue-revolution/sd-webui-segment-anything"
    "https://github.com/modelscope/facechain"
    "https://github.com/glucauze/sd-webui-faceswaplab"
    "https://github.com/cheald/sd-webui-loractl"
    "https://github.com/light-and-ray/sd-webui-replacer"
    "https://github.com/Avaray/lora-keywords-finder"
    "https://github.com/kainatquaderee/sd-webui-reactor-Nsfw_freedom"
    "https://github.com/Haoming02/sd-webui-mosaic-outpaint"
    "https://github.com/zero01101/openOutpaint-webUI-extension"
)

# Initial models to load immediately with A1111 startup
CHECKPOINT_MODELS=(
    "https://huggingface.co/Red1618/tEST2/resolve/main/Schlip.safetensors"
)

# Models to load in background after A1111 has started
BACKGROUND_MODELS=(
    "https://civitai.com/api/download/models/300972?type=Model&format=SafeTensor&size=full"
    "https://civitai.com/api/download/models/302254?type=Model&format=SafeTensor&size=full"
)

UNET_MODELS=(
)

LORA_MODELS=(
)

VAE_MODELS=(
)

ESRGAN_MODELS=(
)

CONTROLNET_MODELS=(
)

# Token storage file locations
HF_TOKEN_FILE="${LIGHTNING_APP_STATE_DIR}/.hf_token"
CIVITAI_TOKEN_FILE="${LIGHTNING_APP_STATE_DIR}/.civitai_token"
LOG_DIR="${WORKSPACE_DIR}/logs"

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    # Create log and workspace directories
    mkdir -p "${LOG_DIR}"
    mkdir -p "${A1111_DIR}"
    
    provisioning_print_header
    provisioning_setup_tokens
    provisioning_get_apt_packages
    
    # Clone A1111 repository if it doesn't exist or is empty
    if [ ! -d "${A1111_DIR}/.git" ]; then
        echo "Cloning Stable Diffusion WebUI repository..."
        git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git "${A1111_DIR}"
    fi
    
    provisioning_get_extensions
    provisioning_get_pip_packages
    provisioning_get_files \
        "${A1111_DIR}/models/Stable-diffusion" \
        "${CHECKPOINT_MODELS[@]}"

    # Avoid git errors because we run as root but files are owned by different user
    export GIT_CONFIG_GLOBAL=/tmp/temporary-git-config
    git config --file $GIT_CONFIG_GLOBAL --add safe.directory '*'

    # Modify the A1111_ARGS to ensure compatibility with openOutpaint and allow unrestricted downloads
    if [[ -z "${A1111_ARGS}" ]]; then
        export A1111_ARGS="--xformers --api --listen --cors-allow-origins=* --skip-torch-cuda-test --no-half-vae --no-safe-unpickle"
    else
        # Add required flags if not present
        if [[ ! "${A1111_ARGS}" =~ --api ]]; then
            export A1111_ARGS="${A1111_ARGS} --api"
        fi
        
        if [[ ! "${A1111_ARGS}" =~ --listen ]]; then
            export A1111_ARGS="${A1111_ARGS} --listen"
        fi
        
        if [[ ! "${A1111_ARGS}" =~ --cors-allow-origins ]]; then
            export A1111_ARGS="${A1111_ARGS} --cors-allow-origins=*"
        fi
        
        if [[ ! "${A1111_ARGS}" =~ --skip-torch-cuda-test ]]; then
            export A1111_ARGS="${A1111_ARGS} --skip-torch-cuda-test"
        fi
        
        if [[ ! "${A1111_ARGS}" =~ --no-half-vae ]]; then
            export A1111_ARGS="${A1111_ARGS} --no-half-vae"
        fi
        
        if [[ ! "${A1111_ARGS}" =~ --no-safe-unpickle ]]; then
            export A1111_ARGS="${A1111_ARGS} --no-safe-unpickle"
        fi
        
        # Remove restrictive flags if present
        export A1111_ARGS=$(echo "${A1111_ARGS}" | sed 's/--gradio-debug//g')
        export A1111_ARGS=$(echo "${A1111_ARGS}" | sed 's/--disable-safe-unpickle//g')
    fi

    # Create or update UI config for unrestricted extension/model installation
    mkdir -p "${A1111_DIR}/config"
    cat > "${A1111_DIR}/config/ui-config.json" <<EOL
{
  "sd_checkpoint_hash": "",
  "sd_lora": "",
  "outdir_samples": "",
  "outdir_txt2img_samples": "${A1111_DIR}/outputs/txt2img-images",
  "outdir_img2img_samples": "${A1111_DIR}/outputs/img2img-images",
  "outdir_extras_samples": "${A1111_DIR}/outputs/extras-images",
  "outdir_grids": "",
  "outdir_txt2img_grids": "${A1111_DIR}/outputs/txt2img-grids",
  "outdir_img2img_grids": "${A1111_DIR}/outputs/img2img-grids",
  "outdir_save": "${A1111_DIR}/log/images",
  "show_progressbar": true,
  "show_progress_every_n_steps": 10,
  "show_progress_grid": true,
  "return_grid": true,
  "do_not_show_images": false,
  "add_model_hash_to_info": true,
  "add_model_name_to_info": true,
  "disable_weights_auto_swap": true,
  "send_seed": true,
  "send_size": true,
  "font": "",
  "js_modal_lightbox": true,
  "js_modal_lightbox_initially_zoomed": true,
  "show_progress_in_title": true,
  "samplers_in_dropdown": true,
  "dimensions_and_batch_together": true,
  "keyedit_precision_attention": 0.1,
  "keyedit_precision_extra": 0.05,
  "quicksettings": "sd_model_checkpoint, sd_vae, CLIP_stop_at_last_layers",
  "hidden_tabs": [],
  "ui_reorder": "inpaint, sampler, checkboxes, hires_fix, dimensions, cfg, seed, batch, override_settings, scripts",
  "ui_extra_networks_tab_reorder": "",
  "localization": "None",
  "gradio_theme": "Default",
  "disable_extension_access": false
}
EOL

    # Create persistent location for Civitai token configuration
    mkdir -p "${A1111_DIR}/extensions/sd-civitai-browser-plus/params"
    
    # Create a config file for the Civitai Browser Plus extension if a token exists
    if [[ -f "${CIVITAI_TOKEN_FILE}" ]]; then
        cat > "${A1111_DIR}/extensions/sd-civitai-browser-plus/params/civitai_config.json" <<EOL
{
  "api_key": "$(cat ${CIVITAI_TOKEN_FILE})",
  "use_search_term": true,
  "enable_console_logging": false
}
EOL
        chmod 644 "${A1111_DIR}/extensions/sd-civitai-browser-plus/params/civitai_config.json"
        echo "Civitai token configured for persistent storage"
    fi

    # Create or update webui-user.sh to include our customizations
    cat > "${A1111_DIR}/webui-user.sh" <<EOL
#!/bin/bash
export COMMANDLINE_ARGS="--xformers --api --listen --cors-allow-origins=* --skip-torch-cuda-test --no-half-vae --no-safe-unpickle"
EOL
    chmod +x "${A1111_DIR}/webui-user.sh"

    # Start and exit because webui will probably require a restart
    cd "${A1111_DIR}"
    python launch.py \
        --skip-python-version-check \
        --no-download-sd-model \
        --do-not-download-clip \
        --api \
        --listen \
        --cors-allow-origins=* \
        --no-safe-unpickle \
        --exit

    # Download background models after A1111 has been set up
    provisioning_background_downloads &

    provisioning_print_end
}

function provisioning_setup_tokens() {
    # Set up HuggingFace token if provided
    if [[ -n "${HF_TOKEN}" ]]; then
        echo "${HF_TOKEN}" > "${HF_TOKEN_FILE}"
        chmod 600 "${HF_TOKEN_FILE}"
        # Create config dir if it doesn't exist
        mkdir -p "${HOME}/.huggingface"
        # Create or update huggingface token file
        echo "${HF_TOKEN}" > "${HOME}/.huggingface/token"
        chmod 600 "${HOME}/.huggingface/token"
        echo "HuggingFace token saved and configured"
    elif [[ -f "${HF_TOKEN_FILE}" ]]; then
        # Load token from file if it exists
        export HF_TOKEN=$(cat "${HF_TOKEN_FILE}")
        mkdir -p "${HOME}/.huggingface"
        echo "${HF_TOKEN}" > "${HOME}/.huggingface/token"
        chmod 600 "${HOME}/.huggingface/token"
        echo "HuggingFace token loaded from storage"
    fi

    # Set up CivitAI token if provided
    if [[ -n "${CIVITAI_TOKEN}" ]]; then
        echo "${CIVITAI_TOKEN}" > "${CIVITAI_TOKEN_FILE}"
        chmod 600 "${CIVITAI_TOKEN_FILE}"
        echo "CivitAI token saved"
    elif [[ -f "${CIVITAI_TOKEN_FILE}" ]]; then
        # Load token from file if it exists
        export CIVITAI_TOKEN=$(cat "${CIVITAI_TOKEN_FILE}")
        echo "CivitAI token loaded from storage"
    fi
}

function provisioning_background_downloads() {
    # Give A1111 time to start up properly
    sleep 60
    
    # Download the background models
    provisioning_get_files \
        "${A1111_DIR}/models/Stable-diffusion" \
        "${BACKGROUND_MODELS[@]}"
        
    echo "Background model downloads complete" >> "${LOG_DIR}/background_downloads.log"
}

function provisioning_get_apt_packages() {
    if [[ ${#APT_PACKAGES[@]} -gt 0 ]]; then
        apt-get update
        apt-get install -y ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ ${#PIP_PACKAGES[@]} -gt 0 ]]; then
        pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_extensions() {
    for repo in "${EXTENSIONS[@]}"; do
        dir="${repo##*/}"
        path="${A1111_DIR}/extensions/${dir}"
        if [[ ! -d $path ]]; then
            printf "Downloading extension: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
        fi
    done
}

function provisioning_get_files() {
    if [[ -z $2 ]]; then return 1; fi
    
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Application will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

# Download from $1 URL to $2 file path
function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif 
        [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]];then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

# Allow user to disable provisioning if they started with a script they didn't want
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi