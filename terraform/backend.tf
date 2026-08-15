terraform {
  backend "s3" {
    bucket  = "dvi-modular-cicd-pipeline-tfstate"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
