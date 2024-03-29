terraform {
  backend "s3" {
    bucket         = "opg.terraform.state"
    key            = "opg-digi-deps-infrastructure/terraform.tfstate"
    encrypt        = true
    region         = "eu-west-1"
    role_arn       = "arn:aws:iam::311462405659:role/digideps-ci"
    dynamodb_table = "remote_lock"
  }
}

provider "aws" {
  region = "eu-west-1"

  assume_role {
    role_arn     = "arn:aws:iam::${var.account_ids[terraform.workspace]}:role/${var.default_role}"
    session_name = "terraform-session"
  }
}

provider "aws" {
  region = "eu-west-1"
  alias  = "management"

  assume_role {
    role_arn     = "arn:aws:iam::${var.account_ids["management"]}:role/${var.management_role}"
    session_name = "terraform-session"
  }
}

