require 'bundler/setup'
require 'yaml'

def extract_github_info(url)
    if ENV['GITHUB_ORG_NAME'] && ENV['GITHUB_REPO_NAME']
      return { organization: ENV['GITHUB_ORG_NAME'], repository: ENV['GITHUB_REPO_NAME'] }
    end
    
    # Regular expression to match GitHub HTTP URL with optional .git at the end
    github_url_regex = %r{https?://github\.com/(.+)/(.+)\.git?}
  
    # Match the regular expression against the URL
    match = url.match(github_url_regex)
  
    # Check if the match was successful
    if match
      organization = match[1]
      repository = match[2]
      return { organization: organization, repository: repository }
    else
      return nil  # Return nil if no match is found
    end
end

stacks_dir = 'stacks'
environments = YAML.load(File.read(File.join(stacks_dir, 'environments.yaml')))
deployer_file_name = "cfn-sync.stack.yaml"
deployments_file_name = "cfn-sync-deployments.yaml"

git_url = `git remote get-url origin`
github = extract_github_info(git_url)

deployment_templpate = "
template-file-path: ./stacks/deployments/ENVIRONMENT/REGION/#{deployments_file_name}

parameters:
  RepositoryOwner: #{github[:organization]}
  RepositoryName: #{github[:repository]}
"

task :setup_deployments do |t|
    environments.each do |name, config|
        config['regions'].each do |region|
            if !File.exist?("#{stacks_dir}/deployments/#{name}/#{region}/#{deployments_file_name}")
                puts "Creating Cfn Sync Deployment for Environment:#{name} in Account:#{config['accountId']} and Region:#{region}"

                #setup the deployer templates
                FileUtils.mkdir_p "#{stacks_dir}/deployments/#{name}/#{region}"
                FileUtils.copy("#{stacks_dir}/templates/cfn-stack-deployer.template", "#{stacks_dir}/deployments/#{name}/#{region}/#{deployments_file_name}")

                #create the cfn-sync deployment file
                FileUtils.mkdir_p "#{stacks_dir}/environments/#{name}/#{region}"
                File.open("#{stacks_dir}/environments/#{name}/#{region}/#{deployer_file_name}", 'w') do |file|
                    file.puts(deployment_templpate.gsub('ENVIRONMENT', name).gsub('REGION', region))
                end
            end
        end
    end unless environments.nil?
    puts "No Environments Found" if environments.nil?
end

task :new_deployments do |t|
    # TODO - add logic scan environments dir for stacks and for each environment/region add a
    # CfnGitSync::Stack resouce to the matching cfn-sync.stack.yaml file use the file name as
    # the stack name with environment name prefix

    deployment_files = Dir.glob(File.join("#{stacks_dir}/environments", '**', '*.yaml'))
    deployment_files.each do |file|
      next if file.end_with?(deployer_file_name)
      environment_name = file.split('/')[2]
      environment_region = file.split('/')[3]
      stack_name = file.split('/')[4].gsub('.stack.yaml','')
      resource_name = "#{environment_name.capitalize}#{stack_name.capitalize}Stack"
      new_stack = nil
      deployment_file_name = "#{stacks_dir}/deployments/#{environment_name}/#{environment_region}/#{deployments_file_name}"
      
      deployment = YAML.load(File.read(deployment_file_name))
      deployment['Resources'].each do |name, resource|
        next if deployment['Resources'].has_key?(resource_name)
        puts "Adding new Deployments in #{environment_name} and #{environment_region} for #{stack_name} stack"
        new_stack = {
          "Type" => 'CfnGitSync::Stack',
          "Properties" => {
            "RepositoryOwner" => '!Ref RepositoryOwner',
            "RepositoryName" => '!Ref RepositoryName',
            "BranchName" => 'main',
            "StackName" => "#{environment_name}-#{stack_name}",
            "StackDeploymentFile" => file
          }
        }
      end
      if new_stack.nil?
        puts "Stack #{stack_name} in environment:#{environment_name}, region:#{environment_region} already exists in #{deployment_file_name}"
      else
        deployment['Resources'][resource_name] = new_stack
        File.write(deployment_file_name, YAML.dump(deployment))
      end
    end
end


