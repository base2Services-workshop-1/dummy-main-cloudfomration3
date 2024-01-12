CfhighlanderTemplate do

    Description "Main VPC Stack - (#{component_name}@#{component_version})"
  
    Parameters do
      ComponentParam 'MaxNatGateways', 1
      ComponentParam 'NatGatewayEIPs', ""
      ComponentParam 'RootDomainName'
    end
  
    Component template: 'vpc-v2@0.10.0', name: 'vpc', render: Inline,
      config: { manage_ns_records: true } do
      parameter name: 'RootDomainName', value: Ref(:RootDomainName)
      parameter name: 'DomainName', value: Ref(:RootDomainName)
      parameter name: 'SubnetBits', value: 8
      parameter name: 'AvailabilityZones', value: max_availability_zones
      parameter name: 'NatType', value: 'managed'
      parameter name: 'NatGateways', value: Ref(:MaxNatGateways)
      parameter name: 'NatGatewayEIPs', value: FnSplit(',', Ref(:NatGatewayEIPs))
      parameter name: 'NatAmi', value: '/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-ebs'
      parameter name: 'NatInstanceType', value: 't3.nano'
      parameter name: 'NatInstancesSpot', value: false
      parameter name: 'EnableTransitVPC', value: false
      parameter name: 'dnszoneAddNSRecords', value: true
      parameter name: 'dnszoneParentIAMRole', value: ''
    end

    Component template: 'route53-zone@1.5.0', name: 'dns', render: Inline do
      parameter name: 'CreateZone', value: 'true'
      parameter name: 'RootDomainName', value: FnJoin('', [Ref(:RootDomainName), '.'])
      parameter name: 'DnsDomain', value: FnJoin('', [Ref(:EnvironmentName), '.', Ref(:RootDomainName)])
      parameter name: 'AddNSRecords', value: true
      parameter name: 'ParentIAMRole', value: ''
    end

    Component template: 'ecs-v2@0.2.2', name: 'ecs', render: Inline, config: {
      cluster_name: '${EnvironmentName}-services',
      execute_command_configuration: {
        'logging' => 'DEFAULT'
      },
      fargate_only_cluster: true
      } do
      parameter name: 'ContainerInsights', value: 'disabled'
      parameter name: 'AvailabilityZones', value: max_availability_zones
    end

end  