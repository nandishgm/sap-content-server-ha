###############################################################################
#
# MAIN
#
###############################################################################

case $__OCF_ACTION in
    meta-data)
        metadata
        exit $OCF_SUCCESS
        ;;
    usage|help)
        echo $USAGE
        exit $OCF_SUCCESS
        ;;
esac

if ! ocf_is_root; then
    ocf_log err "You must be root for $__OCF_ACTION operation."
    exit $OCF_ERR_PERM
fi

s3fgw_validate

case $__OCF_ACTION in
    start)
        s3fgw_start;;
    stop)
        s3fgw_stop;;
    monitor)
        s3fgw_monitor;;
    validate-all)
        exit $?;;
    *)
        echo $USAGE
        exit $OCF_ERR_UNIMPLEMENTED
        ;;
esac