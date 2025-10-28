s3fgw_get_current_az() {
    local token
    local current_az

    token=$(curl -s -f -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") || {
        ocf_log error "Failed to retrieve IMDSv2 token"
        return $OCF_ERR_GENERIC
    }

    current_az=$(curl -s -f -H "X-aws-ec2-metadata-token: $token" \
        "http://169.254.169.254/latest/meta-data/placement/availability-zone") || {
        ocf_log error "Failed to retrieve availability zone"
        return $OCF_ERR_GENERIC
    }

    echo "$current_az"
    return $OCF_SUCCESS
}

s3fgw_get_ec2_instance_id() {
    local az=$1
    local ssm_param_value
    local instance_id
    local instance_state

    if [ -z "$az" ]; then
        ocf_log error "No availability zone provided"
        return $OCF_ERR_ARGS
    fi

    if [ -z "$OCF_RESKEY_ssm_param_name" ]; then
        ocf_log error "ssm_param_name is not set"
        return $OCF_ERR_CONFIGURED
    fi

    ssm_param_value=$(aws ssm get-parameter \
        --name "$OCF_RESKEY_ssm_param_name" \
        --query 'Parameter.Value' \
        --output text 2>&1) || {
        ocf_log error "Failed to retrieve SSM parameter '$OCF_RESKEY_ssm_param_name': $ssm_param_value"
        return $OCF_ERR_GENERIC
    }

    if ! echo "$ssm_param_value" | jq -e '.[] | select(has("'$az'"))' >/dev/null 2>&1; then
        ocf_log error "No mapping found for AZ '$az' in parameter '$OCF_RESKEY_ssm_param_name'"
        ocf_log error "Available mappings: $(echo "$ssm_param_value" | jq -r 'keys[]')"
        return $OCF_ERR_CONFIGURED
    fi

    instance_id=$(echo "$ssm_param_value" | jq -r '.[] | select(has("'$az'")) | .["'$az'"]' | tr -d ' ')

    instance_state=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[].Instances[].State.Name' \
        --output text 2>&1) || {
        ocf_log error "Failed to verify instance state: $instance_state"
        return $OCF_ERR_GENERIC
    }

    if [ "$instance_state" != "running" ]; then
        ocf_log error "Instance $instance_id is not running (current state: $instance_state)"
        return $OCF_FAILED
    fi

    s3fgw_refresh_file_share_cache "${instance_id}" > /dev/null 2>&1 &

    echo $instance_id
    return $OCF_SUCCESS
}