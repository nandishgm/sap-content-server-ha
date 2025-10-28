s3fgw_refresh_file_share_cache() {
    local instance_id=$1
    local gateway_arn
    local file_shares

    gateway_arn=$(aws storagegateway list-gateways --query "Gateways[?Ec2InstanceId=='${instance_id}'].GatewayARN" --output text)

    if [ -z "$gateway_arn" ]; then
        ocf_log error "No Storage Gateway found for EC2 instance ${instance_id}"
        return $OCF_ERR_GENERIC
    fi

    file_shares=$(aws storagegateway list-file-shares --gateway-arn "${gateway_arn}" --query "FileShareInfoList[].FileShareARN" --output text)

    if [ -z "$file_shares" ]; then
        ocf_log warn "No file shares found for gateway ${gateway_arn}"
        return $OCF_SUCCESS
    fi

    for share_arn in $file_shares; do
        (
            ocf_log info "Starting cache refresh for file share ${share_arn}"
            aws storagegateway refresh-cache --file-share-arn "${share_arn}"

            if [ $? -eq 0 ]; then
                ocf_log info "Successfully initiated cache refresh for file share ${share_arn}"
            else
                ocf_log warn "Failed to refresh cache for file share ${share_arn}"
            fi
        ) &
    done

    return $OCF_SUCCESS
}