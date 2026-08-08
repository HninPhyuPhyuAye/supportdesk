variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform."
  type        = string
  default     = "supportdesk"
}

variable "aws_region" {
  description = "AWS region where SupportDesk resources are created."
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = var.aws_region == "ap-southeast-1"
    error_message = "SupportDesk is intentionally restricted to the Singapore region."
  }
}

variable "allow_force_delete" {
  description = "Allows Terraform to delete a non-empty repository during intentional cleanup."
  type        = bool
  default     = false
}
