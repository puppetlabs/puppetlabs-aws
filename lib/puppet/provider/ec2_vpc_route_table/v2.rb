require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_vpc_route_table).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      response = ec2_client(region: region).describe_route_tables()
      tables = []
      response.data.route_tables.each do |table|
        hash = route_table_to_hash(region, table)
        tables << new(hash) if hash[:name]
      end
      tables
    end.flatten
  end

  read_only(:region)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.route_table_to_hash(region, table)
    name_tag = table.tags.detect { |tag| tag.key == 'Name' }
    {
      name: name_tag ? name_tag.value : nil,
      id: table.route_table_id,
      ensure: :present,
      region: region,
    }
  end

  def exists?
    Puppet.info("Checking if route table #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating route table #{name}")
    ec2 = ec2_client(region: resource[:region])
    vpc_response = ec2.describe_vpcs(filters: [
      {name: "tag:Name", values: [resource[:vpc]]},
    ])
    response = ec2.create_route_table(
      vpc_id: vpc_response.data.vpcs.first.vpc_id,
    )
    ec2.create_tags(
      resources: [response.data.route_table.route_table_id],
      tags: [{key: 'Name', value: name}]
    )
  end

  def destroy
    Puppet.info("Deleting route table #{name}")
    ec2 = ec2_client(region: resource[:region])
    response = ec2.describe_route_tables(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    fail("Multiple route tables with name #{name}. Not deleting.") if response.data.route_tables.count > 1
    ec2.delete_route_table(route_table_id: response.data.route_tables.first.route_table_id)
  end
end

