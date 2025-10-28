s3fgw_check_dependencies() {
    local missing_deps=0
    local aws_version
    local jq_version
    local curl_version
    
    # Check for AWS CLI
    if ! aws --version >/dev/null 2>&1; then
        ocf_log error "AWS CLI is not installed or not in PATH"
        missing_deps=1
    else
        aws_version=$(aws --version 2>&1)
        ocf_log info "Found AWS CLI: $aws_version"
    fi
    
    # Check for jq
    if ! jq --version >/dev/null 2>&1; then
        ocf_log error "jq is not installed or not in PATH"
        missing_deps=1
    else
        jq_version=$(jq --version 2>&1)
        ocf_log info "Found jq: $jq_version"
    fi
    
    # Check for curl
    if ! curl --version >/dev/null 2>&1; then
        ocf_log error "curl is not installed or not in PATH"
        missing_deps=1
    else
        curl_version=$(curl --version 2>&1 | head -n 1)
        ocf_log info "Found curl: $curl_version"
    fi
    
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        ocf_log warn "AWS CLI is not properly configured or lacks permissions"
        ocf_log warn "Make sure AWS credentials are available and have required permissions"
    fi
    
    if [ $missing_deps -eq 1 ]; then
        ocf_log error "Missing required dependencies. Please install them before using this resource agent."
        return $OCF_ERR_INSTALLED
    fi
    
    return $OCF_SUCCESS
}