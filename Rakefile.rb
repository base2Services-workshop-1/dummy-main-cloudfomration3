require 'bundler/setup'
require 'yaml'


namespace :deployments do

  desc 'Sets up deployment configuration files'
  task :setup do |t|
    environments&.each do |name, config|
      config['regions']&.each do |region|
        deployment_file_path = "#{stacks_dir}/deployments/#{name}/#{region}/#{deployments_file_name}"

        next if File.exist?(deployment_file_path)

        puts "Creating Cfn Sync Deployment for Environment:#{name} in Account:#{config['accountId']} and Region:#{region}"

        FileUtils.mkdir_p "#{stacks_dir}/deployments/#{name}/#{region}"
        FileUtils.copy("#{stacks_dir}/templates/cfn-stack-deployer.template", deployment_file_path)

        FileUtils.mkdir_p "#{stacks_dir}/environments/#{name}/#{region}"
        File.write("#{stacks_dir}/environments/#{name}/#{region}/#{deployer_file_name}", deployment_template(name, region))
      end
    end unless environments.nil?
    puts "No Environments Found" if environments.nil?
  end

  desc 'Scan environments dir for stacks and add CfnGitSync::Stack resources to deployment files'
  task :new do |t|
    deployment_files = Dir.glob(File.join("#{stacks_dir}/environments", '**', '*.yaml'))

    deployment_files.each do |file|
      next if file.end_with?(deployer_file_name)

      environment_name, environment_region, stack_name = file.split('/')[2..4]
      stack_name = stack_name.gsub('.stack.yaml','')
      resource_name = "#{environment_name.capitalize}#{stack_name.capitalize}Stack"

      deployment_file_name = "#{stacks_dir}/deployments/#{environment_name}/#{environment_region}/#{deployments_file_name}"

      deployment = YAML.load_file(deployment_file_name)
      new_stack = build_new_stack(file, environment_name, stack_name)

      if update_deployment(deployment, resource_name, new_stack, deployment_file_name)
        puts "Added new Deployment in #{environment_name} and #{environment_region} for #{stack_name} stack" unless new_stack.nil?
      end
    end
  end

  private

  def stacks_dir
    'stacks'
  end

  def environments
    YAML.load(File.read(File.join(stacks_dir, 'environments.yaml')))
  end

  def deployer_file_name
    'cfn-sync.stack.yaml'
  end

  def deployments_file_name
    'cfn-sync-deployments.yaml'
  end

  def extract_github_info(url)
    return { organization: ENV['GITHUB_ORG_NAME'], repository: ENV['GITHUB_REPO_NAME'] } if ENV['GITHUB_ORG_NAME'] && ENV['GITHUB_REPO_NAME']
  
    github_url_regex = %r{https?://github\.com/(.+)/(.+)\.git?}
    match = url.match(github_url_regex)
  
    return { organization: match[1], repository: match[2] } if match
  
    nil
  end

  def github_repository_info
    git_url = `git remote get-url origin`
    extract_github_info(git_url)
  end

  def deployment_template(environment, region)
    github_info = github_repository_info()
    "
    template-file-path: #{stacks_dir}/deployments/#{environment}/#{region}/#{deployments_file_name}

    parameters:
      RepositoryOwner: #{github_info[:organization]}
      RepositoryName: #{github_info[:repository]}
    "
  end

  def build_new_stack(file, environment_name, stack_name)
    {
      'Type' => 'CfnGitSync::Stack',
      'Properties' => {
        'RepositoryOwner' => '!Ref RepositoryOwner',
        'RepositoryName' => '!Ref RepositoryName',
        'BranchName' => 'main',
        'StackName' => "#{environment_name}-#{stack_name}",
        'StackDeploymentFile' => file
      }
    }
  end

  def update_deployment(deployment, resource_name, new_stack, deployment_file_name)
    return false if deployment['Resources'].key?(resource_name)

    deployment['Resources'][resource_name] = new_stack
    File.write(deployment_file_name, YAML.dump(deployment))
    return true
  end
end
