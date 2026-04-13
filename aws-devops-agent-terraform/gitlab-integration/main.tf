terraform {
  required_version = ">= 1.0"
  
  required_providers {
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
  }
}

provider "awscc" {
  region  = "us-east-1"
  profile = "zayo-hub"
}

# Reference the main DevOps Agent state to get Agent Space ID
data "terraform_remote_state" "devops_agent" {
  backend = "local"
  
  config = {
    path = "../terraform.tfstate"
  }
}

# GitLab Association
resource "awscc_devopsagent_association" "gitlab" {
  agent_space_id = data.terraform_remote_state.devops_agent.outputs.agent_space_id
  service_id     = "gitlab"

  configuration = {
    gitlab = {
      url   = var.gitlab_url
      token = var.gitlab_token
    }
  }
}
