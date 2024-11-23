variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}
variable "ami_id" {
  description = "The amid used to launch servers"
  type        = string
  default     = "ami-0862be96e41dcbf74"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"

}