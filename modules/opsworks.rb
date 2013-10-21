=begin
	opsworks.rb

	Copyright 2013 Erin Wilkins

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

	 http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
=end

require 'awscli'
require 'json'

=begin rdoc
	A collection of utility methods and constants for working with \OpsWorks.
=end
module OpsWorks

=begin rdoc
	Generic exception class.
=end
	class OpsWorksError < StandardError
	end

=begin rdoc
	Default AWS region that will be used when not otherwise specified.
=end
	REGION = 'us-east-1'

=begin rdoc
	Default availability zone that will be used when not otherwise specified.
=end
	ZONE = 'us-east-1a'

=begin rdoc
	Available \OS choices when creating a stack.
=end
	OS = {
		:amazon => 'Amazon Linux',
		:ubuntu => 'Ubuntu 12.04 LTS'
	}

=begin rdoc
	Available hostname themes when creating a stack.
=end
	HOSTNAME = {
		:layer => 'Layer_Dependent',
		:baked_goods => 'Baked_Goods',
		:clouds => 'Clouds',
		:european_cities => 'European_Cities',
		:fruits => 'Fruits',
		:greek_deities => 'Greek_Deities',
		:japanese_creatures => 'Legendary_Creatures_from_Japan',
		:planets => 'Planets_and_Moons',
		:roman_deities => 'Roman_Deities',
		:scottish_islands => 'Scottish_Islands',
		:us_cities => 'US_Cities',
		:cats => 'Wild_Cats'
	}

=begin rdoc
	Gets the ID for the for the given stack name. Returns the stack ID, or +nil+
	if the stack does not exist. An OpsWorksError will be raised if the command
	fails.
	
	==== Attributes
	
	* +name+ - The name of the stack to get the ID for. Raises an OpsWorksError if empty or nil.
=end
	def OpsWorks.stack_id(name)
		# Check for required parameters
		raise OpsWorksError, 'Stack name cannot be empty or nil' if name == nil or name.strip == ''
		
		# Construct the command
		command = 'opsworks describe-stacks'
		
		# Call the awscli
		stacks = nil
		begin
			stacks = AWSCLI.run(command)
		rescue AWSCLIError => e
			raise OpsWorksError, "Failed to retrieve list of existing stacks. Resulted from:\n#{e.message}"
		end
		
		# Find the id for the given stack name
		stacks['Stacks'].each do |stack|
			return stack['StackId'] if stack['Name'] == name
		end
		return nil
	end
	
=begin rdoc
	Creates a new \OpsWorks stack. Returns the ID of the new stack. If a stack with
	the given +name+ already exists, a new stack is *not* created, and the ID of the
	existing stack is returned. An OpsWorksError will be raised if the command fails.
	
	==== Attributes
	
	* +name+ - The name of the stack to create. Raises an OpsWorksError if empty or nil.
	* +role+ - The service role ARN for the stack. Raises an OpsWorksError if empty or nil.
	* +profile+ - The default instance profile ARN for the stack. Raises an OpsWorksError if empty or nil.
	* +region+ - The AWS region to create the stack in. Defaults to REGION if not specified.
	* +zone+ - The default availability zone for the stack. Defaults to ZONE if not specified.
	* +os+ - The default \OS for the stack. Defaults to Amazon Linux if not specified.
	* +hostname+ - The default hostname theme for the stack. Defaults to layer dependent if not specified.
	* +cookbooks+ - Specifies an optional source of custom chef cookbooks to use in the stack. The source can be specified as either a JSON string or a +Hash+.
	* +json+ - Optional custom JSON to be passed to the stack. Can be specified as either a string or a +Hash+
	
	==== Custom Cookbooks
	
	While the method should allow for every possible custom cookbook source as
	documented at http://docs.aws.amazon.com/opsworks/latest/APIReference/API_Source.html,
	currently only git sources with an SSH key and an optional revision have been
	tested and are supported. The JSON keys for this attribute are:
	
	* +Type+ - One of +git+, +svn+, +archive+, or +s3+.
	* +Url+ - The path to the location of the cookbooks.
	* +Revision+ - For Git or SVN, the branch or revision to use. Optional.
	* +SshKey+ - For Git or SVN, the SSH key used to access the repository. Optional.
	* +Username+ - For S3, the AWS access key. For all other types, the username as needed. Optional.
	* +Password+ - For S3, the AWS secret key. For all other types, the password as needed. Optional.
	
	==== Examples
	
	    cookbooks = {
	    	'Type' => 'git',
	    	'Url' => 'git@github.com:ewilkins/aws-ops',
	    	'SshKey' => '-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----\n'
	    }
	    json = '{"key":"A string", "AnotherKey":[42,13]}'
	    new_id = OpsWorks.create_stack('MyStack',
	    	'arn:aws:iam::1234567890:role/aws-opsworks-service-role',
	    	'arn:aws:iam::1234567890:instance-profile/aws-opsworks-ec2-role',
	    	nil, nil, nil, OpsWorks::HOSTNAME[:fruits], cookbooks, json)
=end
	def OpsWorks.create_stack(name, role, profile, region = nil, zone = nil, os = nil, hostname = nil, cookbooks = nil, json = nil)
		# Check for required parameters
		raise OpsWorksError, 'Stack name cannot be empty or nil' if name == nil or name.strip == ''
		raise OpsWorksError, 'Service role ARN cannot be empty or nil' if role == nil or role.strip == ''
		raise OpsWorksError, 'Default instance profile ARN cannot be empty or nil' if profile == nil or profile.strip == ''
		
		# Check if a stack already exists with the given name. Just return if it does
		# QUESTION: Should this be an error? While it's easier for the caller to try creating a stack when
		#   they need one, it can be argued that they shouldn't be trying to create one when they already
		#   have one. Let's revisit this when the modules and usages are more fleshed out.
		id = OpsWorks.stack_id(name)
		return id if id
		
		# Set defaults as needed
		region = REGION unless region
		zone = ZONE unless zone
		os = OS[:amazon] unless os
		hostname = HOSTNAME[:layer] unless hostname
		
		# Construct the command
		command = 'opsworks create-stack'
		command << " --name '#{name}'"
		command << " --service-role-arn '#{role}'"
		command << " --default-instance-profile-arn '#{profile}'"
		command << " --stack-region '#{region}'"
		command << " --default-availability-zone '#{zone}'"
		command << " --default-os '#{os}'"
		command << " --hostname-theme '#{hostname}'"
		
		config_manager = {'Name' => 'Chef', 'Version' => '11.4'}
		command << " --configuration-manager '#{JSON.generate(config_manager)}'"
		
		if cookbooks
			command << " --use-custom-cookbooks"
			if cookbooks.is_a? String
				command << " --custom-cookbooks-source '#{cookbooks}'"
			else
				command << " --custom-cookbooks-source '#{JSON.generate(cookbooks)}'"
			end
		end
		
		if json
			if json.is_a? String
				command << " --custom-json '#{json}'"
			else
				command << " --custom-json '#{JSON.generate(json)}'"
			end
		end
		
		# Call the awscli
		stack = nil
		begin
			stack = AWSCLI.run(command)
		rescue AWSCLIError => e
			raise OpsWorksError, "Failed to create new OpsWorks stack. Resulted from:\n#{e.message}"
		end
		
		# Return the new stack id
		return stack['StackId']
	end
end
