s3fgw_validate() {
    # Check for required binaries
    for cmd in aws curl jq; do
        check_binary "$cmd"
    done

    # Check for required parameters
    if [ -z "$OCF_RESKEY_target_group_name" ]; then
        ocf_exit_reason "target_group_name parameter not set"
        return $OCF_ERR_CONFIGURED
    fi
    if [ -z "$OCF_RESKEY_ssm_param_name" ]; then
        ocf_exit_reason "ssm_param_name parameter not set"
        return $OCF_ERR_CONFIGURED
    fi
    
    # Perform detailed dependency check
    s3fgw_check_dependencies
    if [ $? -ne $OCF_SUCCESS ]; then
        ocf_exit_reason "Dependency check failed"
        return $OCF_ERR_INSTALLED
    fi
    
    return $OCF_SUCCESS
}