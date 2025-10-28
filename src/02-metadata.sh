metadata() {
    cat <<EOF
<?xml version="1.0"?>
<!DOCTYPE resource-agent SYSTEM "ra-api-1.dtd">
<resource-agent name="S3FgwFailOver">
<version>1.0</version>
<longdesc lang="en">
Resource agent for managing S3 file gateways in an NLB target
</longdesc>
<shortdesc lang="en">SAP File Gateway HA failover manager</shortdesc>
<parameters>
    <parameter name="target_group_name" required="1">
    <longdesc lang="en">Name of the NLB target group</longdesc>
    <shortdesc lang="en">Target group name</shortdesc>
    <content type="string"/>
    </parameter>
    <parameter name="ssm_param_name" required="1">
    <longdesc lang="en">Name of the SSM parameter containing file gateways instance-az mapping</longdesc>
    <shortdesc lang="en">SSM parameter name</shortdesc>
    <content type="string"/>
    </parameter>
</parameters>
<actions>
    <action name="start"   timeout="300s"/>
    <action name="stop"    timeout="300s"/>
    <action name="monitor" timeout="120s" interval="10s"/>
    <action name="meta-data"  timeout="10s"/>
    <action name="validate-all"  timeout="10s"/>
</actions>
</resource-agent>
EOF
}