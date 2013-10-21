=begin
	awscli.rb

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

require 'json'

=begin rdoc
	A simple collection of utility methods to ease the running of the Amazon Web
	Services command-line utility.
=end
module AWSCLI
	NAME = 'aws' #:nodoc:
	REQUIRED = '1.1.0' #:nodoc:
	CONFIG = 'AWS_CONFIG_FILE' #:nodoc:

=begin rdoc
	Generic exception class.
=end
	class AWSCLIError < RuntimeError
	end

=begin rdoc
	Determines whether the AWS command-line utility is available. Returns +true+
	or +false+.
=end
	def AWSCLI.available?
		return false unless `whereis #{NAME}` != '' or `which #{NAME}` != ''
		return false unless ENV.key?(CONFIG)
		return true
	end

=begin rdoc
	Returns the current version of the AWS command-line utility. Returns +nil+ if
	the utility is not available.
=end
	def AWSCLI.version
		return nil unless AWSCLI.available?
		
		text = `#{NAME} --version 2>&1`
		return text.gsub(/^aws-cli\/(\d+\.\d+\.\d+).*$/, '\1')
	end

=begin rdoc
	Determines if the prerequisites have been met to run the AWS command-line
	utility. Returns +true+ or +false+.
=end
	def AWSCLI.prereqs?
		return false unless AWSCLI.available?
		
		ver = AWSCLI.version
		return false if ver == nil
		has = ver.split('.')
		needs = REQUIRED.split('.')
		has.each_index do |i|
			return true if i >= needs.length
			return true if has[i].to_i > needs[i].to_i
			return false if has[i].to_i < need[i].to_i
		end
		return has.length >= needs.length
	end

=begin rdoc
	Runs an AWS command. The method will parse the resulting JSON, and return it
	as a corresponding +Hash+ or +Array+. An +AWSCLIError+ exception will be
	raised if the command fails, or if the prerequisites for the utility have not
	been met.
	
	==== Attributes
	
	* +cmd+ - The command to run. This should *not* include the leading +aws+ literal.
=end
	def AWSCLI.run(cmd)
		raise AWSCLIError, 'AWS command line utility prerequisites have not been met' unless AWSCLI.prereqs?
		
		text = `#{NAME} #{cmd} 2&1`.strip
		json = Hash.new
		return json if text == ''
		
		begin
			json = JSON.parse(text)
		rescue JSON::ParserError
			raise AWSCLIError, "AWS command failed. Command was:\n#{cmd}\n\nError was:\n#{text}"
		end
		return json
	end
end