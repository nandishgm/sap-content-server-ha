s3fgw_start() {
    local target_group_arn
    local current_az
    local instance_id
    local rc

    ocf_log info "Starting resource"

    target_group_arn=$(s3fgw_get_target_group_arn "$OCF_RESKEY_target_group_name")
    rc=$?
    if [ $rc -ne $OCF_SUCCESS ]; then
        ocf_log error "Failed to get target group ARN"
        return $rc
    fi

    current_az=$(s3fgw_get_current_az)
    rc=$?
    if [ $rc -ne $OCF_SUCCESS ]; then
        ocf_log error "Failed to get current AZ"
        return $rc
    fi

    instance_id=$(s3fgw_get_ec2_instance_id $current_az)
    rc=$?
    if [ $rc -ne $OCF_SUCCESS ]; then
        ocf_log error "Failed to get EC2 instance ID for AZ $current_az"
        return $rc
    fi

    s3fgw_deregister_targets $target_group_arn
    rc=$?
    if [ $rc -ne $OCF_SUCCESS ] && [ $rc -ne $OCF_PENDING ]; then
        ocf_log error "Failed to deregister existing targets"
        return $rc
    fi

    s3fgw_register_target $instance_id $target_group_arn
    rc=$?
    if [ $rc -ne $OCF_SUCCESS ]; then
        ocf_log error "Failed to register target $instance_id"
        return $rc
    fi

    s3fgw_wait_for_target_health $instance_id $target_group_arn
    rc=$?
    if [ $rc -ne $OCF_SUCCESS ]; then
        ocf_log error "Target $instance_id failed to become healthy"
        return $rc
    fi

    ocf_log info "Resource started successfully"
    return $OCF_SUCCESS
}

s3fgw_monitor() {
    local target_group_arn
    local rc

    ocf_log info "Monitoring resource"

    target_group_arn=$(s3fgw_get_target_group_arn "$OCF_RESKEY_target_group_name")
    rc=$?
    if [ $rc -ne $OCF_SUCCESS ]; then
        ocf_log error "Failed to get target group ARN"
        return $rc
    fi

    s3fgw_check_target_health $target_group_arn
    rc=$?

    case $rc in
        $OCF_SUCCESS)
            ocf_log info "Resource is running normally"
            ;;
        $OCF_NOT_RUNNING)
            ocf_log info "Resource is not running"
            ;;
        $OCF_PENDING)
            ocf_log info "Resource state is pending"
            ;;
        $OCF_FAILED)
            ocf_log error "Resource has failed"
            ;;
        *)
            ocf_log error "Unexpected return code from check_target_health: $rc"
            ;;
    esac

    return $rc
}

s3fgw_stop() {
    local target_group_arn
    local rc

    ocf_log info "Stopping resource"

    target_group_arn=$(s3fgw_get_target_group_arn "$OCF_RESKEY_target_group_name")
    rc=$?
    if [ $rc -ne $OCF_SUCCESS ]; then
        ocf_log error "Failed to get target group ARN"
        return $rc
    fi

    s3fgw_deregister_targets $target_group_arn
    rc=$?
    if [ $rc -ne $OCF_SUCCESS ] && [ $rc -ne $OCF_PENDING ]; then
        ocf_log error "Failed to deregister targets"
        return $rc
    fi

    ocf_log info "Resource stopped successfully"
    return $OCF_SUCCESS
}