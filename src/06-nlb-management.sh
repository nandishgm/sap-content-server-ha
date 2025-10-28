s3fgw_get_target_group_arn() {
    local target_group_name="$1"
    local target_group_arn

    if [ -z "$target_group_name" ]; then
        ocf_log error "Target group name not provided"
        return $OCF_ERR_ARGS
    fi

    target_group_arn=$(aws elbv2 describe-target-groups \
        --names "$target_group_name" \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text)

    if [ $? -ne 0 ]; then
        ocf_log error "Failed to describe target group"
        return $OCF_ERR_GENERIC
    fi

    if [ -z "$target_group_arn" ] || [ "$target_group_arn" = "None" ]; then
        ocf_log error "Failed to get target group ARN for: $target_group_name"
        return $OCF_ERR_CONFIGURED
    fi

    echo "$target_group_arn"
    return $OCF_SUCCESS
}

s3fgw_deregister_targets() {
    local target_group_arn=$1
    local targets
    local max_attempts=15
    local attempt=1
    local remaining_targets

    targets=$(aws elbv2 describe-target-health --target-group-arn "$target_group_arn" --query 'TargetHealthDescriptions[*].Target.Id' --output text)

    if [ $? -ne 0 ]; then
        ocf_log error "Failed to describe target health"
        return $OCF_ERR_GENERIC
    fi

    if [ -n "$targets" ]; then
        ocf_log info "Deregistering targets: $targets"
        aws elbv2 deregister-targets --target-group-arn "$target_group_arn" --targets $(echo $targets | sed 's/ / Id=/g; s/^/Id=/')

        if [ $? -ne 0 ]; then
            ocf_log error "Failed to deregister targets"
            return $OCF_ERR_GENERIC
        fi

        while [ $attempt -le $max_attempts ]; do
            remaining_targets=$(aws elbv2 describe-target-health \
                --target-group-arn "$target_group_arn" \
                --query 'length(TargetHealthDescriptions[?TargetHealth.State!=`unused`])' \
                --output text)

            if [ $? -ne 0 ]; then
                ocf_log error "Failed to check remaining targets"
                return $OCF_ERR_GENERIC
            fi

            if [ "$remaining_targets" -eq 0 ]; then
                ocf_log info "All targets successfully deregistered"
                return $OCF_SUCCESS
            fi

            ocf_log info "Waiting for targets to complete draining (attempt $attempt/$max_attempts)"
            sleep 10
            ((attempt++))
        done

        ocf_log warn "Targets did not complete draining within timeout"
        return $OCF_PENDING
    else
        ocf_log info "No targets to deregister"
        return $OCF_SUCCESS
    fi
}

s3fgw_register_target() {
    local instance_id=$1
    local target_group_arn=$2

    if [ -z "$instance_id" ] || [ -z "$target_group_arn" ]; then
        ocf_log error "Missing instance ID or target group ARN"
        return $OCF_ERR_ARGS
    fi

    ocf_log info "Registering target: $instance_id"
    aws elbv2 register-targets --target-group-arn "$target_group_arn" --targets Id=$instance_id

    if [ $? -ne 0 ]; then
        ocf_log error "Failed to register target $instance_id"
        return $OCF_ERR_GENERIC
    fi

    return $OCF_SUCCESS
}

s3fgw_wait_for_target_health() {
    local instance_id=$1
    local target_group_arn=$2
    local max_attempts=30
    local attempt=1
    local health

    if [ -z "$instance_id" ] || [ -z "$target_group_arn" ]; then
        ocf_log error "Missing instance ID or target group ARN"
        return $OCF_ERR_ARGS
    fi

    while [ $attempt -le $max_attempts ]; do
        health=$(aws elbv2 describe-target-health --target-group-arn "$target_group_arn" --targets Id=$instance_id --query 'TargetHealthDescriptions[0].TargetHealth.State' --output text)

        if [ $? -ne 0 ]; then
            ocf_log error "Failed to check target health"
            return $OCF_ERR_GENERIC
        fi

        if [ "$health" = "healthy" ]; then
            ocf_log info "Target $instance_id is healthy"
            return $OCF_SUCCESS
        elif [ "$health" = "unhealthy" ]; then
            ocf_log warn "Target $instance_id is unhealthy (attempt $attempt/$max_attempts)"
        elif [ "$health" = "initial" ]; then
            ocf_log info "Target $instance_id is in initial state (attempt $attempt/$max_attempts)"
        elif [ "$health" = "draining" ]; then
            ocf_log warn "Target $instance_id is draining (attempt $attempt/$max_attempts)"
        else
            ocf_log warn "Target $instance_id has unknown health state: $health (attempt $attempt/$max_attempts)"
        fi

        sleep 10
        ((attempt++))
    done

    ocf_log error "Target $instance_id failed to become healthy after $max_attempts attempts"
    return $OCF_FAILED
}

s3fgw_check_target_health() {
    local target_group_arn=$1
    local targets_health
    local healthy_count
    local initial_count
    local draining_count
    local unhealthy_count

    if [ -z "$target_group_arn" ]; then
        ocf_log error "Missing target group ARN"
        return $OCF_ERR_ARGS
    fi

    targets_health=$(aws elbv2 describe-target-health \
        --target-group-arn "$target_group_arn" \
        --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
        --output json)

    if [ $? -ne 0 ]; then
        ocf_log error "Failed to describe target health"
        return $OCF_ERR_GENERIC
    fi

    if [ -z "$targets_health" ] || [ "$targets_health" = "[]" ]; then
        ocf_log info "No targets found - Resource is STOPPED"
        return $OCF_NOT_RUNNING
    fi

    healthy_count=$(echo "$targets_health" | jq '[.[] | select(.[1] == "healthy")] | length')
    initial_count=$(echo "$targets_health" | jq '[.[] | select(.[1] == "initial")] | length')
    draining_count=$(echo "$targets_health" | jq '[.[] | select(.[1] == "draining")] | length')
    unhealthy_count=$(echo "$targets_health" | jq '[.[] | select(.[1] == "unhealthy")] | length')

    if [ "$healthy_count" -eq 1 ]; then
        ocf_log info "One healthy target found - Resource is RUNNING"
        return $OCF_SUCCESS
    elif [ "$initial_count" -gt 0 ]; then
        ocf_log info "Target(s) in initial state - Resource is STARTING"
        return $OCF_PENDING
    elif [ "$draining_count" -gt 0 ]; then
        ocf_log info "Target(s) in draining state - Resource is STOPPING"
        return $OCF_PENDING
    elif [ "$unhealthy_count" -gt 0 ]; then
        ocf_log error "Target(s) in unhealthy state - Resource has FAILED"
        return $OCF_FAILED
    else
        ocf_log error "No healthy targets - Resource has FAILED"
        return $OCF_FAILED
    fi
}