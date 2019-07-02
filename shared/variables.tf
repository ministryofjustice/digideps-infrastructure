variable "default_role" {
  default = "digideps-ci"
}

variable "environments" {
  type = map(
    object({
      account_id        = string
      cloudtrail_bucket = string
    })
  )
}

locals {
  environment = var.environments[terraform.workspace]

  default_tags = {
    business-unit          = "OPG"
    application            = "Digideps"
    environment-name       = terraform.workspace
    owner                  = "OPG Supervision"
    infrastructure-support = "OPG WebOps: opgteam@digital.justice.gov.uk"
  }
}
