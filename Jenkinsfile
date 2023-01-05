pipeline {
    agent any
    parameters {
        choice(name: 'operation', choices: ['apply', 'destroy'], description: 'Pick something')
        booleanParam(name: 'All', defaultValue: false, description: 'Toggle this value')
        booleanParam(name: 'Backend', defaultValue: false, description: 'Toggle this value')        
        booleanParam(name: 'VPC', defaultValue: false, description: 'Toggle this value')
        booleanParam(name: 'EC2', defaultValue: false, description: 'Toggle this value')
        booleanParam(name: 'S3', defaultValue: false, description: 'Toggle this value')
    }
    stages {
        stage('Print Params') {
            steps {
                echo "Operation is ${params.operation}"
                echo "All button is ${params.All}"
                echo "Backend button is ${params.Backend}"
                echo "VPC button is ${params.VPC}"
                echo "EC2 button is ${params.EC2}"
            }
        }
        stage('SCM-Checkout') { // for display purposes
            steps {
                checkout([$class: 'GitSCM',
                    branches: [[name: 'main']],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [[$class: 'CleanBeforeCheckout']],
                    userRemoteConfigs: [[credentialsId: 'GitHubID', url: 'https://github.com/krishph/terraform.git']]
                ])
            }
        }
        stage('Download') {
            // Download Terraform
            steps {
                 sh label: '', script: 'curl https://releases.hashicorp.com/terraform/1.3.6/terraform_1.3.6_linux_amd64.zip \
                     --output terraform_1.3.6_linux_amd64.zip \
                     && unzip terraform_1.3.6_linux_amd64.zip'
            }
        }
        stage('Backend') {
            when {
                expression {
                    return params.All || params.Backend
                }
            }
            steps {
                script {
                    withCredentials([string(credentialsId: 'AWS_ACCESS_KEY', variable: 'aws_access_key'), 
                            string(credentialsId: 'AWS_SECRET_KEY', variable: 'aws_secret_key')]) {
                    
                        if (params.operation == 'apply') {
                            dir('backend') {
                                        sh script: '../terraform init -input=false'
                                        sh script: '../terraform plan \
                                                -out backend.tfplan \
                                                -var="aws_access_key=$aws_access_key" \
                                                -var="aws_secret_key=$aws_secret_key"'
                                        sh script: '../terraform apply backend.tfplan'
                                        sh script: 'pwd'
                                        sh script: 'ls'
                                        sh script: 'aws s3 cp ./terraform.tfstate s3://ikrish-tf-s3-tfstate/base/terraform.tfstate'
                                }
                        } 
                    }  
                } 
            }            
        }
        stage('VPC') {
            when {
                expression {
                    return params.All || params.VPC
                }
            }
            steps {
                script {
                    withCredentials([string(credentialsId: 'AWS_ACCESS_KEY', variable: 'aws_access_key'), 
                            string(credentialsId: 'AWS_SECRET_KEY', variable: 'aws_secret_key')]) {
                    
                        if (params.operation == 'apply') {
                            dir('VPC') {
                                        sh script: '../terraform init \
                                                    -backend-config="bucket=ikrish-tf-s3-tfstate" \
                                                    -backend-config="key=vpc/vpc.state" \
                                                    -backend-config="region=us-east-1" \
                                                    -backend-config="dynamodb_table=ikrish-tf-tfstatelock" \
                                                    -backend-config="access_key=$aws_access_key" \
                                                    -backend-config="secret_key=$aws_secret_key"'
                                        sh script: '../terraform plan \
                                                    -out vpc.tfplan \
                                                    -var="aws_access_key=$aws_access_key" \
                                                    -var="aws_secret_key=$aws_secret_key"'
                                        sh script: '../terraform apply vpc.tfplan'
                                }
                        } 
                    }  
                } 
            }            
        }
        stage('EC2') {
            when {
                expression {
                    return params.All || params.EC2
                }
            }
            steps {
                script {
                    withCredentials([string(credentialsId: 'AWS_ACCESS_KEY', variable: 'aws_access_key'), 
                            string(credentialsId: 'AWS_SECRET_KEY', variable: 'aws_secret_key')]) {
                    
                        if (params.operation == 'apply') {
                            dir('EC2') {
                                        sh script: '../terraform init \
                                                    -backend-config="bucket=ikrish-tf-s3-tfstate" \
                                                    -backend-config="key=ec2/ec2.state" \
                                                    -backend-config="region=us-east-1" \
                                                    -backend-config="dynamodb_table=ikrish-tf-tfstatelock" \
                                                    -backend-config="access_key=$aws_access_key" \
                                                    -backend-config="secret_key=$aws_secret_key"'
                                        sh script: '../terraform plan \
                                                    -out ec2.tfplan \
                                                    -var="aws_access_key=$aws_access_key" \
                                                    -var="aws_secret_key=$aws_secret_key"'
                                        sh script: '../terraform apply ec2.tfplan'
                                }
                        } 
                    }  
                } 
            }            
        }
        stage('Destroy') {
            when {
                expression {
                    return params.operation == 'destroy'
                }
            }
            steps {
                script {
                    withCredentials([string(credentialsId: 'AWS_ACCESS_KEY', variable: 'aws_access_key'), 
                            string(credentialsId: 'AWS_SECRET_KEY', variable: 'aws_secret_key')]) {
                    
                        if (params.EC2 || params.All) {
                            dir('EC2') {
                                        sh script: '../terraform init \
                                                    -backend-config="bucket=ikrish-tf-s3-tfstate" \
                                                    -backend-config="key=ec2/ec2.state" \
                                                    -backend-config="region=us-east-1" \
                                                    -backend-config="dynamodb_table=ikrish-tf-tfstatelock" \
                                                    -backend-config="access_key=$aws_access_key" \
                                                    -backend-config="secret_key=$aws_secret_key"'
                                        sh script: '../terraform destroy \
                                                    -auto-approve \
                                                    -var="aws_access_key=$aws_access_key" \
                                                    -var="aws_secret_key=$aws_secret_key"'
                                    }
                        }   
                        if (params.VPC || params.All) {
                            dir('VPC') {
                                        sh script: '../terraform init \
                                                    -backend-config="bucket=ikrish-tf-s3-tfstate" \
                                                    -backend-config="key=vpc/vpc.state" \
                                                    -backend-config="region=us-east-1" \
                                                    -backend-config="dynamodb_table=ikrish-tf-tfstatelock" \
                                                    -backend-config="access_key=$aws_access_key" \
                                                    -backend-config="secret_key=$aws_secret_key"'
                                        sh script: '../terraform destroy \
                                                    -auto-approve \
                                                    -var="aws_access_key=$aws_access_key" \
                                                    -var="aws_secret_key=$aws_secret_key"'
                                    }
                        }   
                        if (params.All) {
                            dir('backend') {
                                        sh script: '../terraform init -input=false'
                                        sh script: 'aws s3 cp s3://ikrish-tf-s3-tfstate/base/terraform.tfstate ./terraform.tfstate'
                                        sh script: '../terraform destroy \
                                                -auto-approve \
                                                -var="aws_access_key=$aws_access_key" \
                                                -var="aws_secret_key=$aws_secret_key"'
                                    }
                        }    
                    }  
                } 
            }            
        }
    }
}