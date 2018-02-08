# cassandra-automation

Automation libraries to create a cassandra cluster in AWS


## Run the automation
### prework
- Download and Install packer - https://www.packer.io/docs/install/index.html
- Download and Install terraform - https://www.terraform.io/intro/getting-started/install.html

### build the cassandra image
- cd into packer library
- run 'packer validate cassandra.json' 
- run 'packer build cassandra.json'

### start the cassandra cluster in AWS
- cd into terraform library
- run 'terraform init' to setup your terraform state
- run 'terraform plan' - optional
- run 'terraform apply' 

