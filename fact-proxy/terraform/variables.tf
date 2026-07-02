variable "fly_app_name" {
  description = "Fly application name to manage."
  type        = string
  default     = "motoguide-fact-proxy"
}

variable "fly_org" {
  description = "Fly organization slug. Must match your Fly org (for example `personal`)."
  type        = string
  default     = "personal"
}
