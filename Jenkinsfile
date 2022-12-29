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
                                        sh script: 'aws s3 cp ../terraform.tfstate s3://ikrish-tf-s3-tfstate/base/terraform.tfstate'
                                }
                        } 
                        if (params.operation == 'destroy') {
                            dir('backend') {
                                        sh script: '../terraform init \
                                                    -backend-config="bucket=ikrish-tf-s3-tfstate" \
                                                    -backend-config="key=red30/ecommerceapp/app.state" \
                                                    -backend-config="region=us-east-1" \
                                                    -backend-config="dynamodb_table=red30-tfstatelock" \
                                                    -backend-config="access_key=$aws_access_key" \
                                                    -backend-config="secret_key=$aws_secret_key"'
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
                                                    -backend-config="key=red30/ecommerceapp/app.state" \
                                                    -backend-config="region=us-east-1" \
                                                    -backend-config="dynamodb_table=red30-tfstatelock" \
                                                    -backend-config="access_key=$aws_access_key" \
                                                    -backend-config="secret_key=$aws_secret_key"'
                                        sh script: '../terraform plan \
                                                    -out vpc.tfplan \
                                                    -var="aws_access_key=$aws_access_key" \
                                                    -var="aws_secret_key=$aws_secret_key"'
                                        sh script: '../terraform apply vpc.tfplan'
                                }
                        } 
                        if (params.operation == 'destroy') {
                            dir('VPC') {
                                        sh script: '../terraform init \
                                                    -backend-config="bucket=ikrish-tf-s3-tfstate" \
                                                    -backend-config="key=red30/ecommerceapp/app.state" \
                                                    -backend-config="region=us-east-1" \
                                                    -backend-config="dynamodb_table=red30-tfstatelock" \
                                                    -backend-config="access_key=$aws_access_key" \
                                                    -backend-config="secret_key=$aws_secret_key"'
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