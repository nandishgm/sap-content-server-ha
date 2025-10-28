#!/usr/bin/sh
#
# OCF resource agent for S3 File Gateway failover management
# Copyright (c) 2024
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

#######################################################################
# Initialization:

: ${OCF_FUNCTIONS_DIR=${OCF_ROOT}/lib/heartbeat}
. ${OCF_FUNCTIONS_DIR}/ocf-shellfuncs

# Defaults
OCF_RESKEY_target_group_name_default=""
OCF_RESKEY_ssm_param_name_default=""

: ${OCF_RESKEY_target_group_name=${OCF_RESKEY_target_group_name_default}}
: ${OCF_RESKEY_ssm_param_name=${OCF_RESKEY_ssm_param_name_default}}

#######################################################################

USAGE="usage: $0 {start|stop|monitor|validate-all|meta-data}";