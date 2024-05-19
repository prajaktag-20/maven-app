variable "cidr_block" {
  type = list
  default = ["10.0.1.0/24","10.0.3.0/24"]
}

variable "availability_zone" {
  type = list
  default = ["ap-south-1b","ap-south-1a"]

}